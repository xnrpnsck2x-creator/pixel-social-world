package auth

import (
	"context"
	"fmt"
	"strings"
	"time"
)

func (s *MemoryService) UpgradeGuest(ctx context.Context, request UpgradeGuestRequest) (UpgradeGuestResponse, error) {
	normalized, err := verifyUpgradeRequest(ctx, s.verifier, request)
	if err != nil {
		return UpgradeGuestResponse{}, err
	}
	key := linkedAccountMapKey(normalized.Provider, normalized.ProviderSubject)
	session := newSession(normalized.PlayerID, s.accessTTL, s.refreshTTL)

	s.mu.Lock()
	defer s.mu.Unlock()
	account, exists := s.linkedAccounts[key]
	if exists && account.PlayerID != normalized.PlayerID {
		return UpgradeGuestResponse{}, fmt.Errorf("account_already_linked")
	}
	if !exists {
		account = LinkedAccount{
			PlayerID:        normalized.PlayerID,
			Provider:        normalized.Provider,
			Platform:        normalized.Platform,
			ProviderSubject: normalized.ProviderSubject,
			Email:           normalized.Email,
			DisplayName:     normalized.DisplayName,
			LinkedAt:        time.Now().UnixMilli(),
		}
		s.linkedAccounts[key] = account
	}
	s.saveLocked(session)
	return UpgradeGuestResponse{Session: session, LinkedAccount: account}, nil
}

func normalizeUpgradeShape(request UpgradeGuestRequest) (UpgradeGuestRequest, error) {
	request.PlayerID = strings.TrimSpace(request.PlayerID)
	request.Provider = strings.ToLower(strings.TrimSpace(request.Provider))
	request.Platform = normalizePlatform(request.Platform)
	request.ProviderSubject = strings.TrimSpace(request.ProviderSubject)
	request.IdentityToken = strings.TrimSpace(request.IdentityToken)
	request.AuthorizationCode = strings.TrimSpace(request.AuthorizationCode)
	request.Email = strings.TrimSpace(request.Email)
	request.DisplayName = strings.TrimSpace(request.DisplayName)

	if request.PlayerID == "" {
		return request, fmt.Errorf("player_required")
	}
	if !supportedProvider(request.Provider) {
		return request, fmt.Errorf("unsupported_provider")
	}
	if !supportedPlatform(request.Platform) {
		return request, fmt.Errorf("unsupported_platform")
	}
	if request.IdentityToken == "" && request.AuthorizationCode == "" {
		return request, fmt.Errorf("missing_identity_proof")
	}
	return request, nil
}

func normalizePlatform(platform string) string {
	platform = strings.ToLower(strings.TrimSpace(platform))
	if platform == "web" {
		return "h5"
	}
	return platform
}

func supportedProvider(provider string) bool {
	return provider == "apple" || provider == "google"
}

func supportedPlatform(platform string) bool {
	switch platform {
	case "ios", "android", "h5", "desktop", "pc":
		return true
	default:
		return false
	}
}

func linkedAccountMapKey(provider string, subject string) string {
	return provider + ":" + subject
}
