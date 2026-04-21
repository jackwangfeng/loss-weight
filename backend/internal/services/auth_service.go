package services

import (
	"fmt"
	"math/rand"
	"os"
	"time"

	"github.com/your-org/loss-weight/backend/internal/models"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

type AuthService struct {
	db         *gorm.DB
	logger     *zap.Logger
	skipVerify bool // 是否跳过验证码校验（测试模式）
}

func NewAuthService(db *gorm.DB, logger *zap.Logger) *AuthService {
	// 从环境变量读取是否跳过验证码校验
	// 测试模式下，SKIP_SMS_VERIFY=true
	skipVerify := os.Getenv("SKIP_SMS_VERIFY") == "true"

	return &AuthService{
		db:         db,
		logger:     logger,
		skipVerify: skipVerify,
	}
}

type SendSMSRequest struct {
	Phone   string `json:"phone" binding:"required"`
	Purpose string `json:"purpose" binding:"required"` // login, register
}

type VerifySMSRequest struct {
	Phone string `json:"phone" binding:"required"`
	Code  string `json:"code" binding:"required"`
}

type LoginResponse struct {
	Token     string              `json:"token"`
	UserID    uint                `json:"user_id"`
	Account   *models.UserAccount `json:"account"`
	IsNewUser bool                `json:"is_new_user"`
}

// 生成 6 位数字验证码
func (s *AuthService) generateCode() string {
	rand.Seed(time.Now().UnixNano())
	return fmt.Sprintf("%06d", rand.Intn(1000000))
}

// 发送短信验证码（Mock 模式）
func (s *AuthService) SendSMSCode(req *SendSMSRequest) error {
	// 验证手机号格式
	if len(req.Phone) != 11 || req.Phone[0] != '1' {
		return fmt.Errorf("无效的手机号")
	}

	// 生成验证码
	code := s.generateCode()

	// 保存到数据库
	smsCode := &models.SMSCode{
		Phone:     req.Phone,
		Code:      code,
		Purpose:   req.Purpose,
		ExpiresAt: time.Now().Add(5 * time.Minute), // 5 分钟有效期
	}

	if err := s.db.Create(smsCode).Error; err != nil {
		s.logger.Error("failed to save sms code", zap.Error(err))
		return err
	}

	// TODO: 调用短信服务商 API 发送短信
	// 腾讯云短信：https://cloud.tencent.com/product/sms
	// 阿里云短信：https://www.aliyun.com/product/sms

	s.logger.Info("SMS code sent (MOCK)",
		zap.String("phone", req.Phone),
		zap.String("code", code),
		zap.String("purpose", req.Purpose))

	// Mock 模式：日志输验证码，实际使用时删除这行
	fmt.Printf("【Mock 短信】手机号：%s，验证码：%s，有效期 5 分钟\n", req.Phone, code)

	return nil
}

// 验证短信验证码
func (s *AuthService) VerifySMSCode(req *VerifySMSRequest) error {
	// 测试模式：跳过验证码校验
	if s.skipVerify {
		s.logger.Info("SMS code verified (TEST MODE - SKIP)",
			zap.String("phone", req.Phone),
			zap.String("code", req.Code))
		return nil
	}

	// 生产模式：正常校验验证码
	var smsCode models.SMSCode
	if err := s.db.Where("phone = ? AND code = ? AND purpose = ? AND is_used = ?",
		req.Phone, req.Code, "login", false).
		Order("created_at DESC").
		First(&smsCode).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return fmt.Errorf("验证码错误或已过期")
		}
		s.logger.Error("failed to verify sms code", zap.Error(err))
		return err
	}

	// 检查是否过期
	if smsCode.ExpiresAt.Before(time.Now()) {
		return fmt.Errorf("验证码已过期")
	}

	// 标记为已使用
	smsCode.IsUsed = true
	if err := s.db.Save(&smsCode).Error; err != nil {
		s.logger.Error("failed to mark sms code as used", zap.Error(err))
		return err
	}

	return nil
}

// 手机号登录
func (s *AuthService) PhoneLogin(phone, code string, ip string) (*LoginResponse, error) {
	// 验证验证码
	if err := s.VerifySMSCode(&VerifySMSRequest{
		Phone: phone,
		Code:  code,
	}); err != nil {
		return nil, err
	}

	// 查找或创建用户账号
	var account models.UserAccount
	isNewUser := false
	if err := s.db.Where("phone = ?", phone).First(&account).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			// 新用户，创建账号
			account = models.UserAccount{
				Phone:       phone,
				LastLoginIP: ip,
			}
			if err := s.db.Create(&account).Error; err != nil {
				s.logger.Error("failed to create user account", zap.Error(err))
				return nil, err
			}
			isNewUser = true
		} else {
			s.logger.Error("failed to find user account", zap.Error(err))
			return nil, err
		}
	}

	// 检查是否需要创建用户档案
	if account.UserProfileID == nil {
		isNewUser = true
		// 创建默认用户档案
		defaultProfile := models.UserProfile{
			OpenID:         fmt.Sprintf("phone_%s", phone),
			Nickname:       "新用户",
			CurrentWeight:  70.0, // 默认体重
			TargetWeight:   65.0, // 默认目标体重
			ActivityLevel:  1,
			TargetCalorie:  2000, // 默认目标卡路里
		}
		if err := s.db.Create(&defaultProfile).Error; err != nil {
			s.logger.Error("failed to create user profile", zap.Error(err))
		} else {
			// 更新账号关联的用户档案ID
			account.UserProfileID = &defaultProfile.ID
			s.db.Save(&account)
		}
	}

	// 更新最后登录时间
	now := time.Now()
	account.LastLoginAt = &now
	account.LastLoginIP = ip
	if err := s.db.Save(&account).Error; err != nil {
		s.logger.Error("failed to update last login", zap.Error(err))
		return nil, err
	}

	// 生成 Token（简单 JWT，生产环境应该使用更安全的实现）
	token := fmt.Sprintf("token_%d_%s", account.ID, time.Now().Format("20060102150405"))

	return &LoginResponse{
		Token:     token,
		UserID:    account.ID,
		Account:   &account,
		IsNewUser: isNewUser,
	}, nil
}

// 获取用户账号信息
func (s *AuthService) GetAccountByID(id uint) (*models.UserAccount, error) {
	var account models.UserAccount
	if err := s.db.Preload("UserProfile").First(&account, id).Error; err != nil {
		return nil, err
	}
	return &account, nil
}

// 获取用户账号信息（按手机号）
func (s *AuthService) GetAccountByPhone(phone string) (*models.UserAccount, error) {
	var account models.UserAccount
	if err := s.db.Preload("UserProfile").Where("phone = ?", phone).First(&account).Error; err != nil {
		return nil, err
	}
	return &account, nil
}
