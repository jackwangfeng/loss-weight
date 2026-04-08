package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"testing"
	"time"
)

// ============ 测试配置 ============

const (
	BaseURL     = "http://localhost:8000/v1"
	TestTimeout = 30 * time.Second
)

// ============ 测试数据结构 ============

// 用户档案创建请求
type UserProfileCreate struct {
	Nickname      string  `json:"nickname"`
	Gender        string  `json:"gender"`
	Age           int     `json:"age"`
	Height        float64 `json:"height"`
	CurrentWeight float64 `json:"current_weight"`
	TargetWeight  float64 `json:"target_weight"`
	TargetDate    string  `json:"target_date,omitempty"`
}

// 用户档案响应
type UserProfileResponse struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		UserID      int     `json:"user_id"`
		Nickname    string  `json:"nickname"`
		Gender      string  `json:"gender"`
		BMI         float64 `json:"bmi"`
		BMR         float64 `json:"bmr"`
		TDEE        float64 `json:"tdee"`
		DailyBudget int     `json:"daily_budget"`
		Token       string  `json:"token"`
	} `json:"data"`
}

// 饮食记录创建请求
type FoodRecordCreate struct {
	FoodName   string   `json:"food_name"`
	Calories   int      `json:"calories"`
	Protein    *float64 `json:"protein,omitempty"`
	Fat        *float64 `json:"fat,omitempty"`
	Carbs      *float64 `json:"carbs,omitempty"`
	Portion    float64  `json:"portion"`
	Unit       string   `json:"unit"`
	MealType   string   `json:"meal_type"`
	RecordType string   `json:"record_type"`
	RecordedAt string   `json:"recorded_at"`
}

// 体重记录创建请求
type WeightRecordCreate struct {
	Weight     float64 `json:"weight"`
	Note       string  `json:"note,omitempty"`
	RecordedAt string  `json:"recorded_at"`
}

// AI 鼓励请求
type EncouragementRequest struct {
	Event   string                 `json:"event"`
	Context map[string]interface{} `json:"context,omitempty"`
}

// 通用响应
type CommonResponse struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// ============ 测试工具函数 ============

// 创建 HTTP 客户端
func createTestClient() *http.Client {
	return &http.Client{
		Timeout: TestTimeout,
	}
}

// 发送 POST 请求（JSON）
func postJSON(url string, body interface{}, token string) (*http.Response, error) {
	jsonData, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	client := createTestClient()
	return client.Do(req)
}

// 发送 GET 请求
func getJSON(url string, token string) (*http.Response, error) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	client := createTestClient()
	return client.Do(req)
}

// 发送 PUT 请求
func putJSON(url string, body interface{}, token string) (*http.Response, error) {
	jsonData, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("PUT", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	client := createTestClient()
	return client.Do(req)
}

// 发送 DELETE 请求
func deleteRequest(url string, token string) (*http.Response, error) {
	req, err := http.NewRequest("DELETE", url, nil)
	if err != nil {
		return nil, err
	}

	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	client := createTestClient()
	return client.Do(req)
}

// 读取响应体
func readResponseBody(resp *http.Response) ([]byte, error) {
	defer resp.Body.Close()
	return io.ReadAll(resp.Body)
}

// 打印测试结果
func printTestResult(testName string, passed bool, message string) {
	status := "✅ PASS"
	if !passed {
		status = "❌ FAIL"
	}
	fmt.Printf("[%s] %s: %s\n", status, testName, message)
}

// ============ 主测试函数 ============

func TestAPI(t *testing.T) {
	fmt.Println("\n🚀 开始 API 接口测试")
	fmt.Println("========================================\n")

	// 存储测试过程中产生的数据
	var token string
	var userID int
	var foodRecordID int
	var weightRecordID int

	// ============ 1. 用户模块测试 ============
	fmt.Println("📋 测试用户模块")
	fmt.Println("----------------------------------------")

	// 1.1 创建用户档案
	t.Run("CreateUserProfile", func(t *testing.T) {
		profile := UserProfileCreate{
			Nickname:      "测试用户",
			Gender:        "male",
			Age:           28,
			Height:        175,
			CurrentWeight: 75.0,
			TargetWeight:  65.0,
			TargetDate:    "2026-08-01",
		}

		resp, err := postJSON(BaseURL+"/users/profile", profile, "")
		if err != nil {
			printTestResult("创建用户档案", false, fmt.Sprintf("请求失败：%v", err))
			t.Fatalf("Failed to create user: %v", err)
		}

		body, err := readResponseBody(resp)
		if err != nil {
			printTestResult("创建用户档案", false, fmt.Sprintf("读取响应失败：%v", err))
			t.Fatalf("Failed to read response: %v", err)
		}

		var result UserProfileResponse
		if err := json.Unmarshal(body, &result); err != nil {
			printTestResult("创建用户档案", false, fmt.Sprintf("解析响应失败：%v", err))
			t.Fatalf("Failed to parse response: %v", err)
		}

		passed := resp.StatusCode == http.StatusOK && result.Code == 200 && result.Data.Token != ""
		printTestResult("创建用户档案", passed, fmt.Sprintf("状态码=%d, UserID=%d", resp.StatusCode, result.Data.UserID))

		if passed {
			token = result.Data.Token
			userID = result.Data.UserID
		}

		if !passed {
			t.Fatalf("创建用户档案失败：%s", string(body))
		}
	})

	// 1.2 获取用户档案
	t.Run("GetUserProfile", func(t *testing.T) {
		resp, err := getJSON(BaseURL+"/users/profile", token)
		if err != nil {
			printTestResult("获取用户档案", false, fmt.Sprintf("请求失败：%v", err))
			t.Fatalf("Failed to get user: %v", err)
		}

		body, err := readResponseBody(resp)
		if err != nil {
			printTestResult("获取用户档案", false, fmt.Sprintf("读取响应失败：%v", err))
			t.Fatalf("Failed to read response: %v", err)
		}

		var result CommonResponse
		if err := json.Unmarshal(body, &result); err != nil {
			printTestResult("获取用户档案", false, fmt.Sprintf("解析响应失败：%v", err))
			t.Fatalf("Failed to parse response: %v", err)
		}

		passed := resp.StatusCode == http.StatusOK && result.Code == 200
		printTestResult("获取用户档案", passed, fmt.Sprintf("状态码=%d", resp.StatusCode))

		if !passed {
			t.Fatalf("获取用户档案失败：%s", string(body))
		}
	})

	// 1.3 更新用户档案
	t.Run("UpdateUserProfile", func(t *testing.T) {
		updateData := map[string]interface{}{
			"current_weight": 74.5,
		}

		resp, err := putJSON(BaseURL+"/users/profile", updateData, token)
		if err != nil {
			printTestResult("更新用户档案", false, fmt.Sprintf("请求失败：%v", err))
			t.Fatalf("Failed to update user: %v", err)
		}

		body, err := readResponseBody(resp)
		if err != nil {
			printTestResult("更新用户档案", false, fmt.Sprintf("读取响应失败：%v", err))
			t.Fatalf("Failed to read response: %v", err)
		}

		var result CommonResponse
		if err := json.Unmarshal(body, &result); err != nil {
			printTestResult("更新用户档案", false, fmt.Sprintf("解析响应失败：%v", err))
			t.Fatalf("Failed to parse response: %v", err)
		}

		passed := resp.StatusCode == http.StatusOK && result.Code == 200
		printTestResult("更新用户档案", passed, fmt.Sprintf("状态码=%d", resp.StatusCode))

		if !passed {
			t.Fatalf("更新用户档案失败：%s", string(body))
		}
	})

	fmt.Println()

	// ============ 2. 饮食模块测试 ============
	fmt.Println("🍽️  测试饮食模块")
	fmt.Println("----------------------------------------")

	// 2.1 添加饮食记录
	t.Run("AddFoodRecord", func(t *testing.T) {
		record := FoodRecordCreate{
			FoodName:   "宫保鸡丁",
			Calories:   520,
			Protein:    floatPtr(25),
			Fat:        floatPtr(30),
			Carbs:      floatPtr(15),
			Portion:    200,
			Unit:       "g",
			MealType:   "lunch",
			RecordType: "manual",
			RecordedAt: time.Now().Format(time.RFC3339),
		}

		resp, err := postJSON(BaseURL+"/food/records", record, token)
		if err != nil {
			printTestResult("添加饮食记录", false, fmt.Sprintf("请求失败：%v", err))
			t.Fatalf("Failed to add food record: %v", err)
		}

		body, err := readResponseBody(resp)
		if err != nil {
			printTestResult("添加饮食记录", false, fmt.Sprintf("读取响应失败：%v", err))
			t.Fatalf("Failed to read response: %v", err)
		}

		var result CommonResponse
		if err := json.Unmarshal(body, &result); err != nil {
			printTestResult("添加饮食记录", false, fmt.Sprintf("解析响应失败：%v", err))
			t.Fatalf("Failed to parse response: %v", err)
		}

		passed := resp.StatusCode == http.StatusOK && result.Code == 200
		printTestResult("添加饮食记录", passed, fmt.Sprintf("状态码=%d", resp.StatusCode))

		if passed {
			// 从响应中提取 record ID（假设响应中有）
			if dataMap, ok := result.Data.(map[string]interface{}); ok {
				if id, exists := dataMap["record_id"]; exists {
					if idFloat, ok := id.(float64); ok {
						foodRecordID = int(idFloat)
					}
				}
			}
		}

		if !passed {
			t.Fatalf("添加饮食记录失败：%s", string(body))
		}
	})

	// 2.2 获取今日饮食汇总
	t.Run("GetTodayFoodSummary", func(t *testing.T) {
		resp, err := getJSON(BaseURL+"/food/records/today", token)
		if err != nil {
			printTestResult("获取今日饮食汇总", false, fmt.Sprintf("请求失败：%v", err))
			t.Fatalf("Failed to get today food summary: %v", err)
		}

		body, err := readResponseBody(resp)
		if err != nil {
			printTestResult("获取今日饮食汇总", false, fmt.Sprintf("读取响应失败：%v", err))
			t.Fatalf("Failed to read response: %v", err)
		}

		var result CommonResponse
		if err := json.Unmarshal(body, &result); err != nil {
			printTestResult("获取今日饮食汇总", false, fmt.Sprintf("解析响应失败：%v", err))
			t.Fatalf("Failed to parse response: %v", err)
		}

		passed := resp.StatusCode == http.StatusOK && result.Code == 200
		printTestResult("获取今日饮食汇总", passed, fmt.Sprintf("状态码=%d", resp.StatusCode))

		if !passed {
			t.Fatalf("获取今日饮食汇总失败：%s", string(body))
		}
	})

	// 2.3 获取饮食记录列表
	t.Run("GetFoodRecords", func(t *testing.T) {
		resp, err := getJSON(BaseURL+"/food/records?page=1&page_size=10", token)
		if err != nil {
			printTestResult("获取饮食记录列表", false, fmt.Sprintf("请求失败：%v", err))
			t.Fatalf("Failed to get food records: %v", err)
		}

		body, err := readResponseBody(resp)
		if err != nil {
			printTestResult("获取饮食记录列表", false, fmt.Sprintf("读取响应失败：%v", err))
			t.Fatalf("Failed to read response: %v", err)
		}

		var result CommonResponse
		if err := json.Unmarshal(body, &result); err != nil {
			printTestResult("获取饮食记录列表", false, fmt.Sprintf("解析响应失败：%v", err))
			t.Fatalf("Failed to parse response: %v", err)
		}

		passed := resp.StatusCode == http.StatusOK && result.Code == 200
		printTestResult("获取饮食记录列表", passed, fmt.Sprintf("状态码=%d", resp.StatusCode))

		if !passed {
			t.Fatalf("获取饮食记录列表失败：%s", string(body))
		}
	})

	fmt.Println()

	// ============ 3. 体重模块测试 ============
	fmt.Println("⚖️  测试体重模块")
	fmt.Println("----------------------------------------")

	// 3.1 记录体重
	t.Run("AddWeightRecord", func(t *testing.T) {
		record := WeightRecordCreate{
			Weight:     72.5,
			Note:       "测试记录",
			RecordedAt: time.Now().Format(time.RFC3339),
		}

		resp, err := postJSON(BaseURL+"/weight/records", record, token)
		if err != nil {
			printTestResult("记录体重", false, fmt.Sprintf("请求失败：%v", err))
			t.Fatalf("Failed to add weight record: %v", err)
		}

		body, err := readResponseBody(resp)
		if err != nil {
			printTestResult("记录体重", false, fmt.Sprintf("读取响应失败：%v", err))
			t.Fatalf("Failed to read response: %v", err)
		}

		var result CommonResponse
		if err := json.Unmarshal(body, &result); err != nil {
			printTestResult("记录体重", false, fmt.Sprintf("解析响应失败：%v", err))
			t.Fatalf("Failed to parse response: %v", err)
		}

		passed := resp.StatusCode == http.StatusOK && result.Code == 200
		printTestResult("记录体重", passed, fmt.Sprintf("状态码=%d", resp.StatusCode))

		if passed {
			// 从响应中提取 record ID
			if dataMap, ok := result.Data.(map[string]interface{}); ok {
				if id, exists := dataMap["record_id"]; exists {
					if idFloat, ok := id.(float64); ok {
						weightRecordID = int(idFloat)
					}
				}
			}
		}

		if !passed {
			t.Fatalf("记录体重失败：%s", string(body))
		}
	})

	// 3.2 获取体重记录列表
	t.Run("GetWeightRecords", func(t *testing.T) {
		resp, err := getJSON(BaseURL+"/weight/records?days=30", token)
		if err != nil {
			printTestResult("获取体重记录列表", false, fmt.Sprintf("请求失败：%v", err))
			t.Fatalf("Failed to get weight records: %v", err)
		}

		body, err := readResponseBody(resp)
		if err != nil {
			printTestResult("获取体重记录列表", false, fmt.Sprintf("读取响应失败：%v", err))
			t.Fatalf("Failed to read response: %v", err)
		}

		var result CommonResponse
		if err := json.Unmarshal(body, &result); err != nil {
			printTestResult("获取体重记录列表", false, fmt.Sprintf("解析响应失败：%v", err))
			t.Fatalf("Failed to parse response: %v", err)
		}

		passed := resp.StatusCode == http.StatusOK && result.Code == 200
		printTestResult("获取体重记录列表", passed, fmt.Sprintf("状态码=%d", resp.StatusCode))

		if !passed {
			t.Fatalf("获取体重记录列表失败：%s", string(body))
		}
	})

	fmt.Println()

	// ============ 4. AI 模块测试 ============
	fmt.Println("🤖 测试 AI 模块")
	fmt.Println("----------------------------------------")

	// 4.1 获取 AI 鼓励
	t.Run("GetEncouragement", func(t *testing.T) {
		request := EncouragementRequest{
			Event: "meal_logged",
			Context: map[string]interface{}{
				"meal_type":   "lunch",
				"calories":    520,
				"daily_total": 1200,
			},
		}

		resp, err := postJSON(BaseURL+"/ai/encouragement", request, token)
		if err != nil {
			printTestResult("获取 AI 鼓励", false, fmt.Sprintf("请求失败：%v", err))
			t.Fatalf("Failed to get encouragement: %v", err)
		}

		body, err := readResponseBody(resp)
		if err != nil {
			printTestResult("获取 AI 鼓励", false, fmt.Sprintf("读取响应失败：%v", err))
			t.Fatalf("Failed to read response: %v", err)
		}

		var result CommonResponse
		if err := json.Unmarshal(body, &result); err != nil {
			printTestResult("获取 AI 鼓励", false, fmt.Sprintf("解析响应失败：%v", err))
			t.Fatalf("Failed to parse response: %v", err)
		}

		passed := resp.StatusCode == http.StatusOK && result.Code == 200
		printTestResult("获取 AI 鼓励", passed, fmt.Sprintf("状态码=%d", resp.StatusCode))

		if !passed {
			t.Fatalf("获取 AI 鼓励失败：%s", string(body))
		}
	})

	// 4.2 AI 对话
	t.Run("ChatWithAI", func(t *testing.T) {
		request := map[string]interface{}{
			"message":    "我今天吃多了，好难受",
			"session_id": "test_session_001",
		}

		resp, err := postJSON(BaseURL+"/ai/chat", request, token)
		if err != nil {
			printTestResult("AI 对话", false, fmt.Sprintf("请求失败：%v", err))
			t.Fatalf("Failed to chat with AI: %v", err)
		}

		body, err := readResponseBody(resp)
		if err != nil {
			printTestResult("AI 对话", false, fmt.Sprintf("读取响应失败：%v", err))
			t.Fatalf("Failed to read response: %v", err)
		}

		var result CommonResponse
		if err := json.Unmarshal(body, &result); err != nil {
			printTestResult("AI 对话", false, fmt.Sprintf("解析响应失败：%v", err))
			t.Fatalf("Failed to parse response: %v", err)
		}

		passed := resp.StatusCode == http.StatusOK && result.Code == 200
		printTestResult("AI 对话", passed, fmt.Sprintf("状态码=%d", resp.StatusCode))

		if !passed {
			t.Fatalf("AI 对话失败：%s", string(body))
		}
	})

	fmt.Println()

	// ============ 测试总结 ============
	fmt.Println("========================================")
	fmt.Println("✅ 所有测试完成！")
	fmt.Println("========================================")
	fmt.Printf("\n测试数据：\n")
	fmt.Printf("  - Token: %s...\n", token[:20])
	fmt.Printf("  - UserID: %d\n", userID)
	fmt.Printf("  - FoodRecordID: %d\n", foodRecordID)
	fmt.Printf("  - WeightRecordID: %d\n", weightRecordID)
	fmt.Println()
}

// 辅助函数：创建 float64 指针
func floatPtr(f float64) *float64 {
	return &f
}

// 测试入口
func TestMain(m *testing.M) {
	// 检查是否设置了测试基础 URL
	baseURL := os.Getenv("TEST_BASE_URL")
	if baseURL != "" {
		// 在测试中使用环境变量
	}
	
	// 运行测试
	os.Exit(m.Run())
}
