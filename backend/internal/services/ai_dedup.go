package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/your-org/loss-weight/backend/internal/models"
	"go.uber.org/zap"
)

// 判重 verdict 三态。
const (
	conflictExactDup     = "exact_duplicate"
	conflictSameMeal     = "same_meal_conflict"
	conflictNoneVerdict  = "no_conflict"
	dedupCallTimeoutSecs = 8
)

// foodConflictVerdict 是 LLM 判重的结构化结果。
type foodConflictVerdict struct {
	Verdict   string `json:"verdict"`
	MatchedID uint   `json:"matched_id,omitempty"`
	Reason    string `json:"reason,omitempty"`
}

// proposedFood 是即将插入的新食物记录（未落库）。
type proposedFood struct {
	FoodName      string  `json:"food_name"`
	Calories      float32 `json:"calories"`
	Protein       float32 `json:"protein"`
	Carbohydrates float32 `json:"carbohydrates"`
	Fat           float32 `json:"fat"`
	MealType      string  `json:"meal_type"`
}

// classifyFoodConflict 让 Gemini Flash 判新记录跟已有同 meal_type 记录的关系。
//
// 不写硬规则（食物名归一化、热量阈值之类），让 LLM 兜模糊匹配（"一个苹果"
// 与"苹果1个"、"两片面包+鸡蛋"与"两片面包一个鸡蛋"等）。
//
// 调用者保证 existing 至少有 1 条；空时直接当 no_conflict 不必调本函数。
//
// 任何失败（key 缺失、网络错、JSON 不合法、超时）都 fallback 到 no_conflict
// —— 判重不能阻塞用户记录，宁可漏判一条重复也别 5xx。
func (s *AIService) classifyFoodConflict(proposed proposedFood, existing []models.FoodRecord) foodConflictVerdict {
	fallback := foodConflictVerdict{Verdict: conflictNoneVerdict}

	if s.llmAPIKey == "" || len(existing) == 0 {
		return fallback
	}

	type existingItem struct {
		ID            uint    `json:"id"`
		FoodName      string  `json:"food_name"`
		Calories      float32 `json:"calories"`
		Protein       float32 `json:"protein"`
		Carbohydrates float32 `json:"carbohydrates"`
		Fat           float32 `json:"fat"`
	}
	items := make([]existingItem, 0, len(existing))
	for _, e := range existing {
		items = append(items, existingItem{
			ID:            e.ID,
			FoodName:      e.FoodName,
			Calories:      e.Calories,
			Protein:       e.Protein,
			Carbohydrates: e.Carbohydrates,
			Fat:           e.Fat,
		})
	}
	existingJSON, _ := json.Marshal(items)
	proposedJSON, _ := json.Marshal(proposed)

	prompt := fmt.Sprintf(`Classify whether a proposed food log entry conflicts with the user's existing entries
under the same meal_type for today.

Proposed (not yet inserted):
%s

Existing entries (already in DB, same meal_type, same day):
%s

Decide ONE of:
- "exact_duplicate": the proposed entry is essentially the same food/portion as
  one of the existing entries (e.g. user accidentally re-logged the same meal).
  Match should be semantic, not exact string — "一个苹果" vs "苹果1个" vs
  "中等大小苹果" all match. Calories should be within ~10%% to count as match.
  When matched, set matched_id to that existing entry's id.
- "same_meal_conflict": the proposed entry is a DIFFERENT food/meal from any
  existing entry, but the user already logged something else under this meal_type
  today. The user may have intended to overwrite the earlier record OR add a
  separate item — we'll ask them.
- "no_conflict": proposed is clearly a brand-new item that fits naturally
  alongside the existing ones (e.g. existing is "鸡胸肉 200g", proposed is
  "白米饭一碗" — same lunch, different foods, no replacement intent).

Output ONLY a JSON object, no markdown:
{"verdict": "...", "matched_id": <number or 0>, "reason": "<10 words>"}`,
		string(proposedJSON), string(existingJSON))

	apiURL := s.llmAPIURL
	if apiURL == "" {
		apiURL = defaultGeminiURL
	}
	payload := map[string]interface{}{
		"contents": []map[string]interface{}{
			{"role": "user", "parts": []map[string]string{{"text": prompt}}},
		},
		"generationConfig": map[string]interface{}{
			"temperature":      0.0,
			"maxOutputTokens":  256,
			"responseMimeType": "application/json",
			// 关 thinking — Flash 默认开 thinking 多花 3-5s；判重要快。
			"thinkingConfig": map[string]interface{}{"thinkingBudget": 0},
		},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return fallback
	}

	ctx, cancel := context.WithTimeout(context.Background(), dedupCallTimeoutSecs*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, "POST",
		fmt.Sprintf("%s?key=%s", apiURL, s.llmAPIKey),
		bytes.NewBuffer(body))
	if err != nil {
		return fallback
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: dedupCallTimeoutSecs * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		s.logger.Warn("food dedup LLM call failed", zap.Error(err))
		return fallback
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		s.logger.Warn("food dedup LLM non-200",
			zap.Int("status", resp.StatusCode),
			zap.String("body", truncate(string(b), 300)))
		return fallback
	}

	var apiResp struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return fallback
	}
	if err := json.Unmarshal(raw, &apiResp); err != nil {
		return fallback
	}
	if len(apiResp.Candidates) == 0 || len(apiResp.Candidates[0].Content.Parts) == 0 {
		return fallback
	}
	jsonText := stripMarkdownCodeFence(apiResp.Candidates[0].Content.Parts[0].Text)
	var v foodConflictVerdict
	if err := json.Unmarshal([]byte(jsonText), &v); err != nil {
		s.logger.Warn("food dedup JSON parse failed",
			zap.Error(err), zap.String("raw", truncate(jsonText, 300)))
		return fallback
	}
	switch v.Verdict {
	case conflictExactDup, conflictSameMeal, conflictNoneVerdict:
		return v
	default:
		s.logger.Warn("food dedup unknown verdict", zap.String("verdict", v.Verdict))
		return fallback
	}
}
