package services

// 对话记忆系统（Phase 1+2+3 混合方案）
//
// 每次 Chat 请求的上下文组装层次：
//   [1] 实时画像：从 DB 查 profile / 今日饮食 / 最近 7 天体重趋势
//   [2] 长期记忆：user_facts 表里 LLM 抽取出的结构化偏好/约束
//   [3] 滚动摘要：AIChatThread.Summary
//   [4] 相关检索：对当前问题做 embedding，拿 top-K 历史相关消息
//   [5] 最近滑窗：直接取最近 N 条原文
//
// 异步后台：
//   - 消息入库后，异步 embed 并更新 embedding 列
//   - thread 消息数满阈值，异步 LLM 抽新事实、压缩老消息成摘要

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/your-org/loss-weight/backend/internal/models"
	"go.uber.org/zap"
)

// ---- 触发阈值（可调） --------------------------------------------------------

const (
	// 滑窗大小：每次请求带多少条最近原文
	recentWindowSize = 10
	// 向量检索 top-K
	retrievalTopK = 3
	// 摘要触发：thread 消息数 >= 此阈值且未摘要 → 压缩最老的 (N - windowSize) 条
	summarizeThreshold = 20
	// 事实抽取节流：每累积此数量新消息触发一次
	factExtractEvery = 6
	// Embedding 维度（text-embedding-004 是 768）
	embedDim = 768
	// 默认 embedding 端点
	defaultEmbedURL = "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent"
)

// ---- Embedding --------------------------------------------------------------

type embedRequest struct {
	Model   string         `json:"model"`
	Content embedContent   `json:"content"`
	TaskType string        `json:"taskType,omitempty"`
}
type embedContent struct {
	Parts []embedPart `json:"parts"`
}
type embedPart struct {
	Text string `json:"text"`
}
type embedResponse struct {
	Embedding struct {
		Values []float32 `json:"values"`
	} `json:"embedding"`
}

// generateEmbedding 调 Gemini text-embedding-004 生成 768 维向量。
// taskType 可选 "RETRIEVAL_QUERY" / "RETRIEVAL_DOCUMENT"，不传就是 null（通用）。
func (s *AIService) generateEmbedding(ctx context.Context, text, taskType string) ([]float32, error) {
	if s.llmAPIKey == "" {
		return nil, errLLMNotConfigured
	}
	if text == "" {
		return nil, errors.New("empty text")
	}

	payload := embedRequest{
		Model:    "models/text-embedding-004",
		Content:  embedContent{Parts: []embedPart{{Text: text}}},
		TaskType: taskType,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	url := fmt.Sprintf("%s?key=%s", defaultEmbedURL, s.llmAPIKey)
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("embedding HTTP: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("embedding API %d: %s", resp.StatusCode, string(b))
	}
	var out embedResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	if len(out.Embedding.Values) != embedDim {
		return nil, fmt.Errorf("unexpected embedding dim %d", len(out.Embedding.Values))
	}
	return out.Embedding.Values, nil
}

// encodeEmbedding / decodeEmbedding：float32 slice ↔ 小端 byte slice
func encodeEmbedding(v []float32) []byte {
	out := make([]byte, 4*len(v))
	for i, x := range v {
		binary.LittleEndian.PutUint32(out[i*4:], math.Float32bits(x))
	}
	return out
}
func decodeEmbedding(buf []byte) []float32 {
	if len(buf) == 0 || len(buf)%4 != 0 {
		return nil
	}
	n := len(buf) / 4
	out := make([]float32, n)
	for i := 0; i < n; i++ {
		out[i] = math.Float32frombits(binary.LittleEndian.Uint32(buf[i*4:]))
	}
	return out
}

func cosineSimilarity(a, b []float32) float32 {
	if len(a) == 0 || len(a) != len(b) {
		return 0
	}
	var dot, na, nb float32
	for i := range a {
		dot += a[i] * b[i]
		na += a[i] * a[i]
		nb += b[i] * b[i]
	}
	denom := float32(math.Sqrt(float64(na))) * float32(math.Sqrt(float64(nb)))
	if denom == 0 {
		return 0
	}
	return dot / denom
}

// embedMessageAsync 后台给 message.Embedding 填充向量。失败只打日志不阻断。
func (s *AIService) embedMessageAsync(msgID uint, text string) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				s.logger.Error("embedMessageAsync panic", zap.Any("recover", r))
			}
		}()
		ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
		defer cancel()
		vec, err := s.generateEmbedding(ctx, text, "RETRIEVAL_DOCUMENT")
		if err != nil {
			s.logger.Warn("embed message failed", zap.Uint("msg_id", msgID), zap.Error(err))
			return
		}
		if err := s.db.Model(&models.AIChatMessage{}).Where("id = ?", msgID).
			Update("embedding", encodeEmbedding(vec)).Error; err != nil {
			s.logger.Error("save embedding failed", zap.Uint("msg_id", msgID), zap.Error(err))
		}
	}()
}

// ---- 相关检索（RAG） --------------------------------------------------------

type relevantMessage struct {
	Msg        models.AIChatMessage
	Similarity float32
}

// searchRelevantMessages: 对 queryText 做 embedding，在该用户的所有历史消息里按 cosine
// 相似度取 top-K。excludeMsgIDs 用来剔除已经出现在滑窗里的消息，避免重复注入。
func (s *AIService) searchRelevantMessages(
	ctx context.Context, userID uint, queryText string,
	excludeMsgIDs []uint, topK int,
) ([]relevantMessage, error) {
	if s.llmAPIKey == "" {
		return nil, nil // RAG 未启用时静默跳过
	}
	queryVec, err := s.generateEmbedding(ctx, queryText, "RETRIEVAL_QUERY")
	if err != nil {
		return nil, err
	}

	var msgs []models.AIChatMessage
	q := s.db.Where("user_id = ? AND embedding IS NOT NULL AND length(embedding) > 0", userID)
	if len(excludeMsgIDs) > 0 {
		q = q.Where("id NOT IN ?", excludeMsgIDs)
	}
	// 限量，避免用户历史消息特别多时内存爆炸
	if err := q.Order("id DESC").Limit(500).Find(&msgs).Error; err != nil {
		return nil, err
	}

	hits := make([]relevantMessage, 0, len(msgs))
	for _, m := range msgs {
		v := decodeEmbedding(m.Embedding)
		if len(v) != embedDim {
			continue
		}
		sim := cosineSimilarity(queryVec, v)
		// 过滤掉相似度极低的
		if sim < 0.5 {
			continue
		}
		hits = append(hits, relevantMessage{Msg: m, Similarity: sim})
	}
	sort.Slice(hits, func(i, j int) bool { return hits[i].Similarity > hits[j].Similarity })
	if len(hits) > topK {
		hits = hits[:topK]
	}
	return hits, nil
}

// ---- System Prompt 组装 -----------------------------------------------------

// buildSystemPrompt 组装「用户画像 + 长期记忆 + 线程摘要」
func (s *AIService) buildSystemPrompt(userID uint, threadID string) string {
	var sb strings.Builder
	sb.WriteString("你是一位温暖、专业的减肥 AI 助理。基于以下关于用户的信息，给出贴合实际、可执行的建议。\n\n")

	// [1] 用户画像
	if profile := s.loadUserProfile(userID); profile != nil {
		sb.WriteString("## 用户画像\n")
		if profile.Nickname != "" {
			sb.WriteString(fmt.Sprintf("- 昵称：%s\n", profile.Nickname))
		}
		if profile.Height > 0 {
			sb.WriteString(fmt.Sprintf("- 身高：%.1f cm\n", profile.Height))
		}
		if profile.CurrentWeight > 0 {
			sb.WriteString(fmt.Sprintf("- 当前体重：%.1f kg", profile.CurrentWeight))
			if profile.TargetWeight > 0 {
				sb.WriteString(fmt.Sprintf("，目标 %.1f kg（差 %.1f kg）",
					profile.TargetWeight, profile.CurrentWeight-profile.TargetWeight))
			}
			sb.WriteString("\n")
		}
		if profile.TargetCalorie > 0 {
			sb.WriteString(fmt.Sprintf("- 每日目标热量：%.0f kcal\n", profile.TargetCalorie))
		}

		// 今日饮食
		if foods := s.loadTodayFood(userID); len(foods) > 0 {
			sb.WriteString("- 今日饮食：")
			parts := make([]string, 0, len(foods))
			var totalCal float32
			for _, f := range foods {
				parts = append(parts, fmt.Sprintf("%s(%.0fkcal)", f.name, f.calories))
				totalCal += f.calories
			}
			sb.WriteString(strings.Join(parts, "、"))
			sb.WriteString(fmt.Sprintf("，合计 %.0f kcal", totalCal))
			sb.WriteString("\n")
		}

		// 体重趋势
		if trend := s.loadWeightTrend(userID, 7); trend != "" {
			sb.WriteString("- 最近 7 天体重：" + trend + "\n")
		}
		sb.WriteString("\n")
	}

	// [2] 长期记忆
	facts := s.loadUserFacts(userID, 20)
	if len(facts) > 0 {
		sb.WriteString("## 用户事实（历史对话中积累的偏好与约束）\n")
		for _, f := range facts {
			sb.WriteString(fmt.Sprintf("- [%s] %s\n", f.Category, f.Fact))
		}
		sb.WriteString("\n")
	}

	// [3] 线程摘要
	if summary := s.loadThreadSummary(threadID); summary != "" {
		sb.WriteString("## 过往对话摘要\n")
		sb.WriteString(summary)
		sb.WriteString("\n\n")
	}

	sb.WriteString("请用中文回答。回答要精炼、具体，避免泛泛而谈。")
	return sb.String()
}

// ---- DB 查询小工具 ----------------------------------------------------------

func (s *AIService) loadUserProfile(userID uint) *models.UserProfile {
	// userID 实际上是 UserAccount.ID，UserProfile 通过 UserAccount.UserProfileID 关联
	var acc models.UserAccount
	if err := s.db.Where("id = ?", userID).First(&acc).Error; err != nil {
		return nil
	}
	if acc.UserProfileID == nil {
		return nil
	}
	var p models.UserProfile
	if err := s.db.Where("id = ?", *acc.UserProfileID).First(&p).Error; err != nil {
		return nil
	}
	return &p
}

type foodLite struct {
	name     string
	calories float32
}

func (s *AIService) loadTodayFood(userID uint) []foodLite {
	now := time.Now()
	start := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	end := start.Add(24 * time.Hour)
	var records []models.FoodRecord
	if err := s.db.Where("user_id = ? AND eaten_at >= ? AND eaten_at < ?",
		userID, start, end).Order("eaten_at").Find(&records).Error; err != nil {
		return nil
	}
	out := make([]foodLite, 0, len(records))
	for _, r := range records {
		out = append(out, foodLite{name: r.FoodName, calories: r.Calories})
	}
	return out
}

func (s *AIService) loadWeightTrend(userID uint, days int) string {
	since := time.Now().AddDate(0, 0, -days)
	var records []models.WeightRecord
	if err := s.db.Where("user_id = ? AND measured_at >= ?", userID, since).
		Order("measured_at").Find(&records).Error; err != nil {
		return ""
	}
	if len(records) < 2 {
		return ""
	}
	first := records[0].Weight
	last := records[len(records)-1].Weight
	diff := last - first
	direction := "持平"
	if diff < -0.1 {
		direction = fmt.Sprintf("下降 %.1fkg", -diff)
	} else if diff > 0.1 {
		direction = fmt.Sprintf("上升 %.1fkg", diff)
	}
	return fmt.Sprintf("%s（共 %d 次记录，从 %.1fkg 到 %.1fkg）",
		direction, len(records), first, last)
}

func (s *AIService) loadUserFacts(userID uint, limit int) []models.UserFact {
	var facts []models.UserFact
	s.db.Where("user_id = ?", userID).
		Order("confidence DESC, updated_at DESC").
		Limit(limit).Find(&facts)
	return facts
}

func (s *AIService) loadThreadSummary(threadID string) string {
	if threadID == "" {
		return ""
	}
	var t models.AIChatThread
	if err := s.db.Where("id = ? OR title = ?", threadID, threadID).First(&t).Error; err != nil {
		return ""
	}
	return t.Summary
}

func (s *AIService) loadRecentMessages(userID uint, threadID string, limit int) []models.AIChatMessage {
	var msgs []models.AIChatMessage
	q := s.db.Where("user_id = ?", userID)
	if threadID != "" {
		q = q.Where("thread_id = ?", threadID)
	}
	q.Order("id DESC").Limit(limit).Find(&msgs)
	// DB 里是倒序，返回前翻正
	sort.Slice(msgs, func(i, j int) bool { return msgs[i].ID < msgs[j].ID })
	return msgs
}

// ---- 异步后台任务 -----------------------------------------------------------

// maybeTriggerBackgroundTasks 根据 thread 消息数触发摘要 / 事实抽取。
// 不阻塞主流程，错误只打日志。
func (s *AIService) maybeTriggerBackgroundTasks(userID uint, threadID string) {
	if threadID == "" {
		return
	}
	var t models.AIChatThread
	if err := s.db.Where("id = ? OR title = ?", threadID, threadID).First(&t).Error; err != nil {
		return
	}
	var total int64
	s.db.Model(&models.AIChatMessage{}).
		Where("thread_id = ?", threadID).Count(&total)
	// 更新 MessageCount 统计
	s.db.Model(&t).Update("message_count", total)

	// 事实抽取：每 factExtractEvery 条触发一次
	if int(total) > 0 && int(total)%factExtractEvery == 0 {
		go s.extractFactsAsync(userID, threadID)
	}
	// 摘要滚动：达到阈值且当前摘要未覆盖到最新的老消息时
	if int(total) >= summarizeThreshold {
		go s.summarizeThreadAsync(t.ID, threadID)
	}
}

// extractFactsAsync 拿最近 N 条消息丢给 LLM，抽取结构化事实写入 user_facts。
func (s *AIService) extractFactsAsync(userID uint, threadID string) {
	defer func() {
		if r := recover(); r != nil {
			s.logger.Error("extractFactsAsync panic", zap.Any("recover", r))
		}
	}()
	msgs := s.loadRecentMessages(userID, threadID, 12)
	if len(msgs) < 2 {
		return
	}
	// 已有事实，给 LLM 参考好去重
	existing := s.loadUserFacts(userID, 50)
	existingLines := make([]string, 0, len(existing))
	for _, f := range existing {
		existingLines = append(existingLines, fmt.Sprintf("- [%s] %s", f.Category, f.Fact))
	}

	convo := make([]string, 0, len(msgs))
	for _, m := range msgs {
		convo = append(convo, fmt.Sprintf("%s: %s", m.Role, m.Content))
	}

	prompt := fmt.Sprintf(`你是信息抽取器。从下面这段用户与 AI 助理的对话中，抽取关于**用户**的结构化事实（偏好、约束、目标、习惯、重要经历）。

## 已有事实（请避免重复，不要抽类似的）
%s

## 对话
%s

## 输出要求
严格只返回 JSON 数组，不要任何额外文字、不要 markdown 代码块。每个对象：
{
  "category": "preference | constraint | goal | routine | history",
  "fact": "一句话，客观、具体",
  "confidence": 0.0-1.0
}

规则：
- 只抽和减肥/健康/饮食/运动/生活习惯相关的
- 只抽确定事实，不臆测
- 如果没有新的可抽，返回 []
- 每条 fact 不超过 30 字`,
		strings.Join(existingLines, "\n"),
		strings.Join(convo, "\n"),
	)

	resp, err := s.callLLM([]ChatMessage{{Role: "user", Content: prompt}})
	if err != nil {
		s.logger.Warn("fact extract LLM failed", zap.Error(err))
		return
	}
	jsonText := stripMarkdownCodeFence(resp.Content)

	var extracted []struct {
		Category   string  `json:"category"`
		Fact       string  `json:"fact"`
		Confidence float32 `json:"confidence"`
	}
	if err := json.Unmarshal([]byte(jsonText), &extracted); err != nil {
		s.logger.Warn("fact extract parse failed", zap.Error(err), zap.String("text", jsonText))
		return
	}

	for _, e := range extracted {
		if e.Fact == "" {
			continue
		}
		// 简单去重：同用户同 fact 文本直接跳过
		var dup int64
		s.db.Model(&models.UserFact{}).
			Where("user_id = ? AND fact = ?", userID, e.Fact).Count(&dup)
		if dup > 0 {
			continue
		}
		fact := models.UserFact{
			UserID:     userID,
			Category:   e.Category,
			Fact:       e.Fact,
			Confidence: e.Confidence,
		}
		if fact.Confidence == 0 {
			fact.Confidence = 0.8
		}
		if err := s.db.Create(&fact).Error; err != nil {
			s.logger.Warn("save user fact failed", zap.Error(err))
		}
	}
	if len(extracted) > 0 {
		s.logger.Info("extracted user facts", zap.Int("count", len(extracted)), zap.Uint("user_id", userID))
	}
}

// summarizeThreadAsync 压缩最老的那批消息到 AIChatThread.Summary
// （保留最近 recentWindowSize 条不压缩）。
func (s *AIService) summarizeThreadAsync(threadDBID uint, threadID string) {
	defer func() {
		if r := recover(); r != nil {
			s.logger.Error("summarizeThreadAsync panic", zap.Any("recover", r))
		}
	}()
	// 取所有消息，前 (total - recentWindowSize) 条要被压缩
	var all []models.AIChatMessage
	if err := s.db.Where("thread_id = ?", threadID).Order("id").Find(&all).Error; err != nil {
		return
	}
	if len(all) <= recentWindowSize {
		return
	}
	toSummarize := all[:len(all)-recentWindowSize]

	var prev string
	{
		var t models.AIChatThread
		if err := s.db.Where("id = ?", threadDBID).First(&t).Error; err == nil {
			prev = t.Summary
		}
	}

	convo := make([]string, 0, len(toSummarize))
	for _, m := range toSummarize {
		convo = append(convo, fmt.Sprintf("%s: %s", m.Role, m.Content))
	}

	prompt := fmt.Sprintf(`以下是一段用户与减肥 AI 助理的对话片段，请压缩成摘要。

## 已有摘要（如果有，请把新片段的要点合并进去）
%s

## 本轮对话
%s

## 要求
- 中文，200-400 字
- 聚焦：用户提过的问题、获得的建议、表达的情绪/状态变化、重要事实
- 去掉寒暄
- 不要加开头"这段对话"这种 meta 词，直接写内容`,
		prev,
		strings.Join(convo, "\n"),
	)
	resp, err := s.callLLM([]ChatMessage{{Role: "user", Content: prompt}})
	if err != nil {
		s.logger.Warn("summarize LLM failed", zap.Error(err))
		return
	}
	if err := s.db.Model(&models.AIChatThread{}).
		Where("id = ?", threadDBID).
		Update("summary", resp.Content).Error; err != nil {
		s.logger.Warn("save summary failed", zap.Error(err))
	}
	s.logger.Info("thread summary updated", zap.String("thread", threadID), zap.Int("len", len(resp.Content)))
}

// stripMarkdownCodeFence: LLM 偶尔不听话把 JSON 包进 ```json ... ```
func stripMarkdownCodeFence(s string) string {
	s = strings.TrimSpace(s)
	if strings.HasPrefix(s, "```") {
		// 剥开头 ```xxx\n
		if nl := strings.Index(s, "\n"); nl > 0 {
			s = s[nl+1:]
		}
		if strings.HasSuffix(s, "```") {
			s = s[:len(s)-3]
		}
	}
	return strings.TrimSpace(s)
}
