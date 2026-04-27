package services

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/your-org/loss-weight/backend/internal/models"
	"go.uber.org/zap"
)

// 工具调用上限：一次用户输入最多让 LLM 走 N 轮工具循环。
// 超过这个上限就强制结束（防止死循环 / 单次请求 token 爆炸）。
const maxToolIterations = 3

// toolCall 是从 Gemini 流里解析出来的待执行工具调用。
type toolCall struct {
	Name string                 `json:"name"`
	Args map[string]interface{} `json:"args"`
}

// toolDeclarations 返回 Gemini API 的 tools[].function_declarations 数组。
// 增工具：在这里加一项声明 + 在 executeTool 里加一个 case 分支。
func (s *AIService) toolDeclarations() []map[string]interface{} {
	return []map[string]interface{}{
		{
			"name": "log_weight",
			"description": "Record the user's body-weight measurement. " +
				"Call this whenever the user reports their current weight (e.g. 'I'm 75kg today', " +
				"'我今天体重 73 公斤'). Do not call it for past historical references or hypothetical numbers.",
			"parameters": map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"weight_kg": map[string]interface{}{
						"type":        "number",
						"description": "Body weight in kilograms.",
					},
					"measured_at": map[string]interface{}{
						"type":        "string",
						"description": "ISO 8601 datetime when the measurement was taken. Omit if the user implies 'now / today' — backend defaults to the current time.",
					},
					"note": map[string]interface{}{
						"type":        "string",
						"description": "Optional short note from the user (e.g. 'morning, fasted').",
					},
				},
				"required": []string{"weight_kg"},
			},
		},
		{
			"name": "log_food",
			"description": "Record a meal / food the user ate. " +
				"Call this whenever the user reports eating something (e.g. 'I had 200g chicken breast for lunch', " +
				"'我中午吃了两个鸡蛋一碗米饭'). Estimate calories and macros from the description if the user " +
				"didn't give exact numbers — be honest about it being an estimate in your reply. " +
				"Do not call this for hypothetical 'should I eat X' questions.",
			"parameters": map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"food_name": map[string]interface{}{
						"type":        "string",
						"description": "Short human-readable name of the food / meal (e.g. 'Chicken breast 200g', '鸡蛋米饭').",
					},
					"calories": map[string]interface{}{
						"type":        "number",
						"description": "Total calories (kcal) for the portion described.",
					},
					"meal_type": map[string]interface{}{
						"type":        "string",
						"enum":        []string{"breakfast", "lunch", "dinner", "snack"},
						"description": "Which meal this belongs to. Infer from the time of day or the user's wording.",
					},
					"protein": map[string]interface{}{
						"type":        "number",
						"description": "Protein in grams. Estimate if not given.",
					},
					"carbohydrates": map[string]interface{}{
						"type":        "number",
						"description": "Carbohydrates in grams. Estimate if not given.",
					},
					"fat": map[string]interface{}{
						"type":        "number",
						"description": "Fat in grams. Estimate if not given.",
					},
					"fiber": map[string]interface{}{
						"type":        "number",
						"description": "Fiber in grams. Optional.",
					},
					"portion": map[string]interface{}{
						"type":        "number",
						"description": "Portion amount (numeric). Optional.",
					},
					"unit": map[string]interface{}{
						"type":        "string",
						"description": "Portion unit (e.g. 'g', 'ml', 'piece'). Optional.",
					},
					"eaten_at": map[string]interface{}{
						"type":        "string",
						"description": "ISO 8601 datetime. Omit for 'now / just ate' — backend defaults to current time.",
					},
				},
				"required": []string{"food_name", "calories", "meal_type"},
			},
		},
		{
			"name": "log_training",
			"description": "Record an exercise / training session. " +
				"Call this whenever the user reports exercise (e.g. 'ran 5k in 30 minutes', " +
				"'今天力量训练一小时'). Estimate calories burned from duration + intensity if not given. " +
				"Do not call this for planned / hypothetical workouts.",
			"parameters": map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"type": map[string]interface{}{
						"type":        "string",
						"description": "Exercise type (e.g. 'running', 'strength', 'cycling', '跑步', '力量训练'). Use the user's wording.",
					},
					"duration_min": map[string]interface{}{
						"type":        "integer",
						"description": "Duration in minutes.",
					},
					"intensity": map[string]interface{}{
						"type":        "string",
						"enum":        []string{"low", "medium", "high"},
						"description": "Subjective intensity. Infer from the user's description.",
					},
					"calories_burned": map[string]interface{}{
						"type":        "number",
						"description": "Estimated calories burned. Estimate from duration + intensity + body weight if not given.",
					},
					"distance": map[string]interface{}{
						"type":        "number",
						"description": "Distance in km — only meaningful for running / cycling / walking.",
					},
					"notes": map[string]interface{}{
						"type":        "string",
						"description": "Optional short note from the user.",
					},
					"exercised_at": map[string]interface{}{
						"type":        "string",
						"description": "ISO 8601 datetime. Omit for 'just finished' — backend defaults to current time.",
					},
				},
				"required": []string{"type", "duration_min"},
			},
		},
	}
}

// executeTool 执行工具调用。返回三件东西：
//   - resultForLLM: 要回喂给 Gemini 的 functionResponse.response 对象
//   - chunk: 推给前端的 action 帧（卡片渲染用）；nil 表示这次工具不展示卡片
//   - err: 工具执行失败（DB 出错等）。即使 err != nil，resultForLLM 也会带 error 字段，
//     让 LLM 自己跟用户说"出问题了"。
func (s *AIService) executeTool(userID uint, call toolCall) (map[string]interface{}, *StreamChunk, error) {
	switch call.Name {
	case "log_weight":
		return s.execLogWeight(userID, call.Args)
	case "log_food":
		return s.execLogFood(userID, call.Args)
	case "log_training":
		return s.execLogTraining(userID, call.Args)
	default:
		return map[string]interface{}{"error": fmt.Sprintf("unknown tool: %s", call.Name)}, nil,
			fmt.Errorf("unknown tool: %s", call.Name)
	}
}

func (s *AIService) execLogWeight(userID uint, args map[string]interface{}) (map[string]interface{}, *StreamChunk, error) {
	weight, ok := numberArg(args, "weight_kg")
	if !ok || weight <= 0 {
		return map[string]interface{}{"error": "weight_kg is required and must be positive"}, nil,
			fmt.Errorf("invalid weight_kg in args: %v", args["weight_kg"])
	}

	measuredAt := time.Now()
	if raw, ok := args["measured_at"].(string); ok && raw != "" {
		if t, err := time.Parse(time.RFC3339, raw); err == nil {
			measuredAt = t
		}
	}
	note, _ := args["note"].(string)

	rec := &models.WeightRecord{
		UserID:     userID,
		Weight:     float32(weight),
		Note:       note,
		MeasuredAt: measuredAt,
	}
	if err := s.db.Create(rec).Error; err != nil {
		s.logger.Error("log_weight tool: db create failed", zap.Error(err))
		return map[string]interface{}{"error": "database error saving weight"}, nil, err
	}
	s.logger.Info("log_weight tool",
		zap.Uint("user_id", userID),
		zap.Uint("record_id", rec.ID),
		zap.Float32("weight", rec.Weight),
	)

	payload := map[string]interface{}{
		"record_id":   rec.ID,
		"weight_kg":   rec.Weight,
		"measured_at": rec.MeasuredAt.Format(time.RFC3339),
		"note":        rec.Note,
	}
	payloadJSON, _ := json.Marshal(payload)

	return map[string]interface{}{
			"ok":          true,
			"record_id":   rec.ID,
			"weight_kg":   rec.Weight,
			"measured_at": rec.MeasuredAt.Format(time.RFC3339),
		},
		&StreamChunk{
			Action:        "log_weight",
			ActionPayload: string(payloadJSON),
		},
		nil
}

func (s *AIService) execLogFood(userID uint, args map[string]interface{}) (map[string]interface{}, *StreamChunk, error) {
	foodName, _ := args["food_name"].(string)
	if foodName == "" {
		return map[string]interface{}{"error": "food_name is required"}, nil,
			fmt.Errorf("missing food_name")
	}
	calories, ok := numberArg(args, "calories")
	if !ok || calories < 0 {
		return map[string]interface{}{"error": "calories is required and must be >= 0"}, nil,
			fmt.Errorf("invalid calories: %v", args["calories"])
	}
	mealType, _ := args["meal_type"].(string)
	switch mealType {
	case "breakfast", "lunch", "dinner", "snack":
	default:
		return map[string]interface{}{"error": "meal_type must be breakfast | lunch | dinner | snack"}, nil,
			fmt.Errorf("invalid meal_type: %q", mealType)
	}

	eatenAt := time.Now()
	if raw, ok := args["eaten_at"].(string); ok && raw != "" {
		if t, err := time.Parse(time.RFC3339, raw); err == nil {
			eatenAt = t
		}
	}
	protein, _ := numberArg(args, "protein")
	carbs, _ := numberArg(args, "carbohydrates")
	fat, _ := numberArg(args, "fat")
	fiber, _ := numberArg(args, "fiber")
	portion, _ := numberArg(args, "portion")
	unit, _ := args["unit"].(string)

	rec := &models.FoodRecord{
		UserID:        userID,
		FoodName:      foodName,
		Calories:      float32(calories),
		Protein:       float32(protein),
		Carbohydrates: float32(carbs),
		Fat:           float32(fat),
		Fiber:         float32(fiber),
		Portion:       float32(portion),
		Unit:          unit,
		MealType:      mealType,
		EatenAt:       eatenAt,
	}
	if err := s.db.Create(rec).Error; err != nil {
		s.logger.Error("log_food tool: db create failed", zap.Error(err))
		return map[string]interface{}{"error": "database error saving food"}, nil, err
	}
	s.logger.Info("log_food tool",
		zap.Uint("user_id", userID),
		zap.Uint("record_id", rec.ID),
		zap.String("food", rec.FoodName),
		zap.Float32("kcal", rec.Calories),
	)

	payload := map[string]interface{}{
		"record_id":     rec.ID,
		"food_name":     rec.FoodName,
		"calories":      rec.Calories,
		"protein":       rec.Protein,
		"carbohydrates": rec.Carbohydrates,
		"fat":           rec.Fat,
		"meal_type":     rec.MealType,
		"eaten_at":      rec.EatenAt.Format(time.RFC3339),
	}
	payloadJSON, _ := json.Marshal(payload)

	return map[string]interface{}{
			"ok":        true,
			"record_id": rec.ID,
			"food_name": rec.FoodName,
			"calories":  rec.Calories,
			"meal_type": rec.MealType,
		},
		&StreamChunk{
			Action:        "log_food",
			ActionPayload: string(payloadJSON),
		},
		nil
}

func (s *AIService) execLogTraining(userID uint, args map[string]interface{}) (map[string]interface{}, *StreamChunk, error) {
	exType, _ := args["type"].(string)
	if exType == "" {
		return map[string]interface{}{"error": "type is required"}, nil,
			fmt.Errorf("missing type")
	}
	duration, ok := numberArg(args, "duration_min")
	if !ok || duration <= 0 {
		return map[string]interface{}{"error": "duration_min is required and must be positive"}, nil,
			fmt.Errorf("invalid duration_min: %v", args["duration_min"])
	}
	intensity, _ := args["intensity"].(string)
	switch intensity {
	case "", "low", "medium", "high":
	default:
		intensity = "" // unknown values are dropped rather than failing the call
	}
	calories, _ := numberArg(args, "calories_burned")
	distance, _ := numberArg(args, "distance")
	notes, _ := args["notes"].(string)

	exercisedAt := time.Now()
	if raw, ok := args["exercised_at"].(string); ok && raw != "" {
		if t, err := time.Parse(time.RFC3339, raw); err == nil {
			exercisedAt = t
		}
	}

	rec := &models.ExerciseRecord{
		UserID:         userID,
		Type:           exType,
		DurationMin:    int(duration),
		Intensity:      intensity,
		CaloriesBurned: float32(calories),
		Distance:       float32(distance),
		Notes:          notes,
		ExercisedAt:    exercisedAt,
	}
	if err := s.db.Create(rec).Error; err != nil {
		s.logger.Error("log_training tool: db create failed", zap.Error(err))
		return map[string]interface{}{"error": "database error saving training"}, nil, err
	}
	s.logger.Info("log_training tool",
		zap.Uint("user_id", userID),
		zap.Uint("record_id", rec.ID),
		zap.String("type", rec.Type),
		zap.Int("min", rec.DurationMin),
	)

	payload := map[string]interface{}{
		"record_id":       rec.ID,
		"type":            rec.Type,
		"duration_min":    rec.DurationMin,
		"intensity":       rec.Intensity,
		"calories_burned": rec.CaloriesBurned,
		"distance":        rec.Distance,
		"exercised_at":    rec.ExercisedAt.Format(time.RFC3339),
	}
	payloadJSON, _ := json.Marshal(payload)

	return map[string]interface{}{
			"ok":              true,
			"record_id":       rec.ID,
			"type":            rec.Type,
			"duration_min":    rec.DurationMin,
			"calories_burned": rec.CaloriesBurned,
		},
		&StreamChunk{
			Action:        "log_training",
			ActionPayload: string(payloadJSON),
		},
		nil
}

// numberArg: Gemini 返回的数值在 JSON 里通常是 float64，
// 但偶尔会塞个字符串。两种都接。
func numberArg(args map[string]interface{}, key string) (float64, bool) {
	if v, ok := args[key]; ok {
		switch n := v.(type) {
		case float64:
			return n, true
		case int:
			return float64(n), true
		case int64:
			return float64(n), true
		case string:
			var f float64
			if _, err := fmt.Sscanf(n, "%f", &f); err == nil {
				return f, true
			}
		}
	}
	return 0, false
}
