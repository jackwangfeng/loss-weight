// Package auth implements JWT (HS256) token issuance and verification,
// replacing the legacy "token_<uid>_<ts>" string format that the SMS flow
// used. Signed with the shared secret from config; audience-/issuer-less —
// this is a session token for our own API, not an OAuth token.
package auth

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Claims holds the fields we care about. We use a short custom key "uid" so
// the middleware doesn't have to round-trip through "sub"/string parsing.
type Claims struct {
	UserID uint `json:"uid"`
	jwt.RegisteredClaims
}

// TokenIssuer is a tiny value object around the HMAC secret + TTL.
// Share a single instance — it's cheap but config-bound.
type TokenIssuer struct {
	secret  []byte
	ttl     time.Duration
}

// NewTokenIssuer: `secret` should come from config.SecretKey; swap it to
// invalidate every active session. `expireDays` <= 0 defaults to 7.
func NewTokenIssuer(secret string, expireDays int) *TokenIssuer {
	if expireDays <= 0 {
		expireDays = 7
	}
	return &TokenIssuer{
		secret: []byte(secret),
		ttl:    time.Duration(expireDays) * 24 * time.Hour,
	}
}

// Issue signs a token for `userID` that expires after the configured TTL.
func (ti *TokenIssuer) Issue(userID uint) (string, error) {
	now := time.Now()
	claims := Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(ti.ttl)),
			Subject:   fmt.Sprintf("%d", userID),
		},
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return tok.SignedString(ti.secret)
}

// Verify parses and validates a token string, returning the user ID on success.
// Signature mismatch, expiry, malformed → error.
func (ti *TokenIssuer) Verify(tokenStr string) (uint, error) {
	claims := &Claims{}
	tok, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return ti.secret, nil
	})
	if err != nil {
		return 0, err
	}
	if !tok.Valid {
		return 0, errors.New("invalid token")
	}
	if claims.UserID == 0 {
		return 0, errors.New("token missing uid claim")
	}
	return claims.UserID, nil
}
