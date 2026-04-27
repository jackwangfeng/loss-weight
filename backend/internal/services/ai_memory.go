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
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/pgvector/pgvector-go"
	"github.com/your-org/loss-weight/backend/internal/models"
	"go.uber.org/zap"
	"gorm.io/gorm"
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
	// Embedding 维度（gemini-embedding-001 默认 3072）
	embedDim = 3072
	// 默认 embedding 端点
	defaultEmbedURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent"
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

// generateEmbedding 调 Gemini gemini-embedding-001 生成 3072 维向量。
// taskType 可选 "RETRIEVAL_QUERY" / "RETRIEVAL_DOCUMENT"，不传就是 null（通用）。
func (s *AIService) generateEmbedding(ctx context.Context, text, taskType string) ([]float32, error) {
	if s.llmAPIKey == "" {
		return nil, errLLMNotConfigured
	}
	if text == "" {
		return nil, errors.New("empty text")
	}

	payload := embedRequest{
		Model:    "models/gemini-embedding-001",
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
		hv := pgvector.NewHalfVector(vec)
		if err := s.db.Model(&models.AIChatMessage{}).Where("id = ?", msgID).
			Update("embedding", hv).Error; err != nil {
			s.logger.Error("save embedding failed", zap.Uint("msg_id", msgID), zap.Error(err))
		}
	}()
}

// ---- 相关检索（RAG） --------------------------------------------------------

type relevantMessage struct {
	Msg        models.AIChatMessage
	Similarity float32
}

// searchRelevantMessages: 对 queryText 做 embedding，在该用户所有历史消息里按 cosine
// 相似度取 top-K。在 Postgres 侧用 pgvector 的 `<=>` 算子，HNSW 索引做 ANN。
// excludeMsgIDs 用来剔除已经出现在滑窗里的消息，避免重复注入。
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
	qv := pgvector.NewHalfVector(queryVec)

	// cosine distance ∈ [0,2]，similarity = 1 - distance；阈值 0.5 相似度 ⇒ distance ≤ 0.5
	const maxDistance = 0.5

	type row struct {
		models.AIChatMessage
		Distance float32
	}
	var rows []row

	q := s.db.WithContext(ctx).
		Model(&models.AIChatMessage{}).
		Select("ai_chat_messages.*, (embedding <=> ?) AS distance", qv).
		Where("user_id = ? AND embedding IS NOT NULL", userID).
		Where("(embedding <=> ?) <= ?", qv, maxDistance)
	if len(excludeMsgIDs) > 0 {
		q = q.Where("id NOT IN ?", excludeMsgIDs)
	}
	if err := q.Order(gorm.Expr("embedding <=> ?", qv)).Limit(topK).Scan(&rows).Error; err != nil {
		return nil, err
	}

	hits := make([]relevantMessage, 0, len(rows))
	for _, r := range rows {
		hits = append(hits, relevantMessage{Msg: r.AIChatMessage, Similarity: 1 - r.Distance})
	}
	return hits, nil
}

// ---- System Prompt 组装 -----------------------------------------------------

// buildSystemPrompt assembles {user profile + long-term memory + thread summary}.
// `lang` is the target language name (e.g. "English", "Simplified Chinese");
// passed via `languageName(req.Locale)` from the chat handler.
//
// Trust hierarchy (highest → lowest). The prompt structure reflects this so
// the model can't defer to stale chat history when current profile answers it:
//   1. ## AUTHORITATIVE USER DATA (live DB read — never stale)
//   2. ## User facts (LLM-extracted structured prefs)
//   3. ## Prior conversation summary (explicitly marked as possibly stale)
//   4. Retrieved messages + recent window (appended outside this fn)
func (s *AIService) buildSystemPrompt(userID uint, threadID, lang string) string {
	var sb strings.Builder
	sb.WriteString("You are RecompDaily, a direct, data-driven AI recomp coach for men who lift. ")
	sb.WriteString("Give concrete, actionable guidance grounded in the user's actual numbers below. ")
	sb.WriteString("Skip fluff, skip pep-talk, skip emoji. Use metric units (kg / kcal / g).\n\n")

	sb.WriteString("## Trust hierarchy (read carefully)\n")
	sb.WriteString("1. **AUTHORITATIVE USER DATA** below is a LIVE read from the database — it is the single source of truth. Trust it absolutely.\n")
	sb.WriteString("2. If earlier messages or summaries say 'I don't know your age/weight/height' but those fields ARE filled in below, those earlier statements are OUTDATED. Ignore them and use the live data.\n")
	sb.WriteString("3. Never ask the user for a value already listed below. Compute directly.\n\n")

	// [1] Profile + today's intake vs targets + derived numbers
	if profile := s.loadUserProfile(userID); profile != nil {
		sb.WriteString("## AUTHORITATIVE USER DATA (live from DB, as of now)\n")
		if profile.Nickname != "" {
			sb.WriteString(fmt.Sprintf("- Name: %s\n", profile.Nickname))
		}
		metab := computeMetabolism(profile)
		if metab.Age > 0 {
			sb.WriteString(fmt.Sprintf("- Age: %d\n", metab.Age))
		}
		if profile.Gender != "" {
			sb.WriteString(fmt.Sprintf("- Sex: %s\n", profile.Gender))
		}
		if profile.Height > 0 {
			sb.WriteString(fmt.Sprintf("- Height: %.1f cm\n", profile.Height))
		}
		if profile.CurrentWeight > 0 {
			sb.WriteString(fmt.Sprintf("- Weight: %.1f kg", profile.CurrentWeight))
			if profile.TargetWeight > 0 {
				sb.WriteString(fmt.Sprintf(", target %.1f kg (delta %.1f kg)",
					profile.TargetWeight, profile.CurrentWeight-profile.TargetWeight))
			}
			sb.WriteString("\n")
		}
		if profile.ActivityLevel >= 1 && profile.ActivityLevel <= 5 {
			levels := [6]string{"", "sedentary", "light", "moderate", "active", "very active"}
			sb.WriteString(fmt.Sprintf("- Activity: %s\n", levels[profile.ActivityLevel]))
		}
		if metab.HasBMR {
			sb.WriteString(fmt.Sprintf("- BMR (Mifflin-St Jeor, pre-computed): **%.0f kcal/day**\n", metab.BMR))
		}
		if metab.HasTDEE {
			sb.WriteString(fmt.Sprintf("- TDEE (BMR × activity %.3f, pre-computed): **%.0f kcal/day**\n",
				metab.ActivityMultiplier, metab.TDEE))
		}

		targets := deriveMacroTargetsBackend(profile)
		sb.WriteString(fmt.Sprintf("- Daily targets: %.0f kcal, %.0f g protein, %.0f g carbs, %.0f g fat\n",
			targets.calorie, targets.protein, targets.carbs, targets.fat))

		if foods := s.loadTodayFood(userID); len(foods) > 0 {
			var totalCal, totalP, totalC, totalF float32
			parts := make([]string, 0, len(foods))
			for _, f := range foods {
				parts = append(parts, fmt.Sprintf("%s (%.0f kcal)", f.name, f.calories))
				totalCal += f.calories
				totalP += f.protein
				totalC += f.carbs
				totalF += f.fat
			}
			sb.WriteString("- Eaten today: " + strings.Join(parts, ", ") + "\n")
			sb.WriteString(fmt.Sprintf("- Today's totals: %.0f kcal, %.0f g protein, %.0f g carbs, %.0f g fat\n",
				totalCal, totalP, totalC, totalF))
		}

		if exs := s.loadTodayExercise(userID); len(exs) > 0 {
			var totalBurned float32
			parts := make([]string, 0, len(exs))
			for _, e := range exs {
				parts = append(parts, fmt.Sprintf("%s %d min (%.0f kcal)",
					e.kind, e.durationMin, e.caloriesBurned))
				totalBurned += e.caloriesBurned
			}
			sb.WriteString("- Exercise today: " + strings.Join(parts, ", ") + "\n")
			sb.WriteString(fmt.Sprintf("- Today burned: %.0f kcal\n", totalBurned))
		}

		// Yesterday at a glance — enables day-over-day context ("你昨天
		// 蛋白质只吃到 95 g") without dumping every record into the prompt.
		if y := s.loadDayAggregate(userID, 1); y.hasAny() {
			sb.WriteString("- Yesterday: " + y.summary() + "\n")
		}

		if trend := s.loadWeightTrend(userID, 7); trend != "" {
			sb.WriteString("- Last 7 days weight: " + trend + "\n")
		}
		sb.WriteString("\n")
	}

	// [2] Long-term facts
	facts := s.loadUserFacts(userID, 20)
	if len(facts) > 0 {
		sb.WriteString("## User facts (extracted from prior chats, lower trust than live data above)\n")
		for _, f := range facts {
			sb.WriteString(fmt.Sprintf("- [%s] %s\n", f.Category, f.Fact))
		}
		sb.WriteString("\n")
	}

	// [3] Thread summary — explicitly de-ranked
	if summary := s.loadThreadSummary(threadID); summary != "" {
		sb.WriteString("## Prior conversation summary (MAY BE STALE — defer to AUTHORITATIVE USER DATA above on any conflict)\n")
		sb.WriteString(summary)
		sb.WriteString("\n\n")
	}

	sb.WriteString(fmt.Sprintf("Reply in %s. Be specific. Name the number, the food, or the protocol — never vague advice. ", lang))
	sb.WriteString("If the user asks about BMR, TDEE, calories, or macros, read the pre-computed values above and state the number directly.\n\n")

	// Tool usage rules — keep concise; full schemas come via the API tools field.
	sb.WriteString("## Tools\n")
	sb.WriteString("You can act on the user's data via tools. When the user reports a measurement or fact you can record, CALL THE TOOL — do not just acknowledge. The chat is the only data-entry surface; if you don't call the tool, the data is not recorded.\n")
	sb.WriteString("- `log_weight`: call when the user states their current body weight (e.g. '今天 75 公斤', 'I weighed in at 168 lb' — convert to kg).\n")
	sb.WriteString("- `log_food`: call when the user reports eating something (e.g. '中午吃了两个鸡蛋一碗米饭', 'had a chicken salad for lunch'). Estimate calories and macros from the description if not given — be honest in your reply that the numbers are estimates.\n")
	sb.WriteString("- `log_training`: call when the user reports completed exercise (e.g. '跑了 5 公里', 'did 45 min of strength'). Estimate calories burned from duration + intensity + body weight if not given.\n")
	sb.WriteString("After a tool returns, give a one-line confirmation in the user's language. Do not re-state the number the user already gave; the UI will show the recorded value as a card. Examples: '记下了。', 'Logged.', '记下了，估算 ~520 kcal。'\n")
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
	protein  float32
	carbs    float32
	fat      float32
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
		out = append(out, foodLite{
			name:     r.FoodName,
			calories: r.Calories,
			protein:  r.Protein,
			carbs:    r.Carbohydrates,
			fat:      r.Fat,
		})
	}
	return out
}

type exerciseLite struct {
	kind           string
	durationMin    int
	caloriesBurned float32
}

func (s *AIService) loadTodayExercise(userID uint) []exerciseLite {
	now := time.Now()
	start := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	end := start.Add(24 * time.Hour)
	var records []models.ExerciseRecord
	if err := s.db.Where("user_id = ? AND exercised_at >= ? AND exercised_at < ?",
		userID, start, end).Order("exercised_at").Find(&records).Error; err != nil {
		return nil
	}
	out := make([]exerciseLite, 0, len(records))
	for _, r := range records {
		out = append(out, exerciseLite{
			kind:           r.Type,
			durationMin:    r.DurationMin,
			caloriesBurned: r.CaloriesBurned,
		})
	}
	return out
}

// dayAggregate collapses one calendar day's intake + expenditure + bodyweight
// into a single object the system prompt can render as one line.
type dayAggregate struct {
	eaten      float32
	protein    float32
	carbs      float32
	fat        float32
	burned     float32
	meals      int
	workouts   int
	weightKg   float32 // last measurement that day, 0 if none
}

func (d dayAggregate) hasAny() bool {
	return d.meals > 0 || d.workouts > 0 || d.weightKg > 0
}

func (d dayAggregate) summary() string {
	parts := make([]string, 0, 4)
	if d.meals > 0 {
		parts = append(parts, fmt.Sprintf("%.0f kcal eaten (P %.0f, C %.0f, F %.0f), %d meal(s)",
			d.eaten, d.protein, d.carbs, d.fat, d.meals))
	}
	if d.workouts > 0 {
		parts = append(parts, fmt.Sprintf("%.0f kcal burned across %d workout(s)", d.burned, d.workouts))
	}
	if d.weightKg > 0 {
		parts = append(parts, fmt.Sprintf("weighed %.1f kg", d.weightKg))
	}
	return strings.Join(parts, "; ")
}

// loadDayAggregate: daysAgo=0 today, 1 yesterday, ... Used for terse day-over-
// day context without piping every per-record row through the prompt.
func (s *AIService) loadDayAggregate(userID uint, daysAgo int) dayAggregate {
	now := time.Now()
	start := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location()).
		AddDate(0, 0, -daysAgo)
	end := start.Add(24 * time.Hour)

	var agg dayAggregate
	var foods []models.FoodRecord
	s.db.Where("user_id = ? AND eaten_at >= ? AND eaten_at < ?", userID, start, end).Find(&foods)
	for _, f := range foods {
		agg.eaten += f.Calories
		agg.protein += f.Protein
		agg.carbs += f.Carbohydrates
		agg.fat += f.Fat
	}
	agg.meals = len(foods)

	var exs []models.ExerciseRecord
	s.db.Where("user_id = ? AND exercised_at >= ? AND exercised_at < ?", userID, start, end).Find(&exs)
	for _, e := range exs {
		agg.burned += e.CaloriesBurned
	}
	agg.workouts = len(exs)

	var w models.WeightRecord
	if err := s.db.Where("user_id = ? AND measured_at >= ? AND measured_at < ?",
		userID, start, end).Order("measured_at DESC").First(&w).Error; err == nil {
		agg.weightKg = w.Weight
	}
	return agg
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
	direction := "flat"
	if diff < -0.1 {
		direction = fmt.Sprintf("down %.1f kg", -diff)
	} else if diff > 0.1 {
		direction = fmt.Sprintf("up %.1f kg", diff)
	}
	return fmt.Sprintf("%s (%d entries, from %.1f kg to %.1f kg)",
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

	prompt := fmt.Sprintf(`You are an information extractor. From the conversation below between a user and an AI recomp coach, extract structured **facts about the user** (preferences, constraints, goals, routines, history).

## Existing facts (avoid restating or paraphrasing these)
%s

## Conversation
%s

## Output
Return a JSON array ONLY — no markdown fence, no prose. Each item:
{
  "category": "preference | constraint | goal | routine | history",
  "fact": "one concise sentence in the same language as the conversation, objective and specific",
  "confidence": 0.0-1.0
}

Rules:
- Only extract facts relevant to fat loss / training / diet / lifestyle.
- Only extract confirmed facts. Do not infer.
- If nothing new is worth extracting, return [].
- Each fact ≤ 140 characters.`,
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

	prompt := fmt.Sprintf(`Below is a slice of a conversation between the user and an AI recomp coach. Compress it into a running summary.

## Existing summary (merge new key points into it, if any)
%s

## This slice
%s

## Requirements
- English, 150-300 words.
- Focus on: what the user asked, advice given, status/mood shifts, notable facts.
- Drop small-talk.
- Do NOT start with meta phrases like "In this conversation...". Write the content directly.`,
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
