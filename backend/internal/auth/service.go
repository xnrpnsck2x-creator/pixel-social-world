package auth

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"sync"
	"time"
)

const defaultAccessTTL = 15 * time.Minute
const defaultRefreshTTL = 30 * 24 * time.Hour

type GuestLoginRequest struct {
	DeviceID    string `json:"device_id"`
	DisplayName string `json:"display_name"`
}

type RefreshRequest struct {
	PlayerID     string `json:"player_id"`
	RefreshToken string `json:"refresh_token"`
}

type UpgradeGuestRequest struct {
	PlayerID          string `json:"player_id"`
	Provider          string `json:"provider"`
	Platform          string `json:"platform"`
	ProviderSubject   string `json:"provider_subject"`
	IdentityToken     string `json:"identity_token,omitempty"`
	AuthorizationCode string `json:"authorization_code,omitempty"`
	Email             string `json:"email,omitempty"`
	DisplayName       string `json:"display_name,omitempty"`
}

type Session struct {
	PlayerID         string `json:"player_id"`
	SessionID        string `json:"session_id"`
	AccessToken      string `json:"access_token"`
	RefreshToken     string `json:"refresh_token"`
	AccessExpiresAt  int64  `json:"access_expires_at"`
	RefreshExpiresAt int64  `json:"refresh_expires_at"`
}

type LinkedAccount struct {
	PlayerID        string `json:"player_id"`
	Provider        string `json:"provider"`
	Platform        string `json:"platform"`
	ProviderSubject string `json:"provider_subject"`
	Email           string `json:"email,omitempty"`
	DisplayName     string `json:"display_name,omitempty"`
	LinkedAt        int64  `json:"linked_at"`
}

type UpgradeGuestResponse struct {
	Session       Session       `json:"session"`
	LinkedAccount LinkedAccount `json:"linked_account"`
}

type Service interface {
	GuestLogin(ctx context.Context, request GuestLoginRequest) (Session, error)
	RefreshAccessToken(ctx context.Context, request RefreshRequest) (Session, error)
	UpgradeGuest(ctx context.Context, request UpgradeGuestRequest) (UpgradeGuestResponse, error)
	ValidateAccessToken(ctx context.Context, playerID string, accessToken string) bool
}

type MemoryService struct {
	mu             sync.RWMutex
	accessTTL      time.Duration
	refreshTTL     time.Duration
	verifier       ProviderVerifier
	accessTokens   map[string]Session
	refreshTokens  map[string]Session
	linkedAccounts map[string]LinkedAccount
}

func NewMemoryService() Service {
	return NewMemoryServiceWithTTL(defaultAccessTTL, defaultRefreshTTL)
}

func NewMemoryServiceWithTTL(accessTTL time.Duration, refreshTTL time.Duration) Service {
	return NewMemoryServiceWithProviderVerifier(accessTTL, refreshTTL, nil)
}

func NewMemoryServiceWithProviderVerifier(
	accessTTL time.Duration,
	refreshTTL time.Duration,
	verifier ProviderVerifier,
) Service {
	if accessTTL <= 0 {
		accessTTL = defaultAccessTTL
	}
	if refreshTTL <= 0 {
		refreshTTL = defaultRefreshTTL
	}
	if verifier == nil {
		verifier = NewClaimedProviderVerifier()
	}
	return &MemoryService{
		accessTTL:      accessTTL,
		refreshTTL:     refreshTTL,
		verifier:       verifier,
		accessTokens:   make(map[string]Session),
		refreshTokens:  make(map[string]Session),
		linkedAccounts: make(map[string]LinkedAccount),
	}
}

func (s *MemoryService) GuestLogin(_ context.Context, request GuestLoginRequest) (Session, error) {
	if request.DisplayName == "" {
		request.DisplayName = "Guest"
	}
	now := time.Now().UnixNano()
	session := newSession(fmt.Sprintf("guest_%d", now), s.accessTTL, s.refreshTTL)
	s.mu.Lock()
	s.saveLocked(session)
	s.mu.Unlock()
	return session, nil
}

func (s *MemoryService) RefreshAccessToken(_ context.Context, request RefreshRequest) (Session, error) {
	if request.PlayerID == "" || request.RefreshToken == "" {
		return Session{}, fmt.Errorf("invalid_refresh")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	old, ok := s.refreshTokens[request.RefreshToken]
	if !ok || old.PlayerID != request.PlayerID || old.RefreshExpiresAt <= time.Now().UnixMilli() {
		return Session{}, fmt.Errorf("invalid_refresh")
	}
	delete(s.accessTokens, old.AccessToken)
	delete(s.refreshTokens, old.RefreshToken)
	next := newSession(old.PlayerID, s.accessTTL, s.refreshTTL)
	s.saveLocked(next)
	return next, nil
}

func (s *MemoryService) ValidateAccessToken(_ context.Context, playerID string, accessToken string) bool {
	if playerID == "" || accessToken == "" {
		return false
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	session, ok := s.accessTokens[accessToken]
	if !ok || session.PlayerID != playerID {
		return false
	}
	if session.AccessExpiresAt <= time.Now().UnixMilli() {
		delete(s.accessTokens, accessToken)
		return false
	}
	return true
}

func (s *MemoryService) saveLocked(session Session) {
	s.accessTokens[session.AccessToken] = session
	s.refreshTokens[session.RefreshToken] = session
}

func newSession(playerID string, accessTTL time.Duration, refreshTTL time.Duration) Session {
	now := time.Now()
	return Session{
		PlayerID:         playerID,
		SessionID:        fmt.Sprintf("session_%d", now.UnixNano()),
		AccessToken:      randomToken("access"),
		RefreshToken:     randomToken("refresh"),
		AccessExpiresAt:  now.Add(accessTTL).UnixMilli(),
		RefreshExpiresAt: now.Add(refreshTTL).UnixMilli(),
	}
}

func randomToken(prefix string) string {
	bytes := make([]byte, 24)
	if _, err := rand.Read(bytes); err != nil {
		return fmt.Sprintf("%s_%d", prefix, time.Now().UnixNano())
	}
	return prefix + "_" + hex.EncodeToString(bytes)
}
