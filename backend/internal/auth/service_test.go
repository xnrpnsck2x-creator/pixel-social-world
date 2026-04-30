package auth

import (
	"context"
	"testing"
	"time"
)

func TestMemoryServiceRefreshRotatesTokens(t *testing.T) {
	service := NewMemoryServiceWithTTL(time.Minute, time.Hour)
	ctx := context.Background()
	session, err := service.GuestLogin(ctx, GuestLoginRequest{DisplayName: "Tester"})
	if err != nil {
		t.Fatalf("GuestLogin returned error: %v", err)
	}
	if !service.ValidateAccessToken(ctx, session.PlayerID, session.AccessToken) {
		t.Fatal("initial access token was not valid")
	}
	next, err := service.RefreshAccessToken(ctx, RefreshRequest{
		PlayerID:     session.PlayerID,
		RefreshToken: session.RefreshToken,
	})
	if err != nil {
		t.Fatalf("RefreshAccessToken returned error: %v", err)
	}
	if next.AccessToken == session.AccessToken || next.RefreshToken == session.RefreshToken {
		t.Fatal("refresh did not rotate both tokens")
	}
	if service.ValidateAccessToken(ctx, session.PlayerID, session.AccessToken) {
		t.Fatal("old access token remained valid after refresh")
	}
	if !service.ValidateAccessToken(ctx, next.PlayerID, next.AccessToken) {
		t.Fatal("new access token was not valid")
	}
}

func TestMemoryServiceExpiresAccessToken(t *testing.T) {
	service := NewMemoryServiceWithTTL(time.Millisecond, time.Hour)
	ctx := context.Background()
	session, err := service.GuestLogin(ctx, GuestLoginRequest{DisplayName: "Tester"})
	if err != nil {
		t.Fatalf("GuestLogin returned error: %v", err)
	}
	time.Sleep(2 * time.Millisecond)
	if service.ValidateAccessToken(ctx, session.PlayerID, session.AccessToken) {
		t.Fatal("expired access token remained valid")
	}
}

func TestMemoryServiceUpgradeGuestLinksProvider(t *testing.T) {
	service := NewMemoryServiceWithTTL(time.Minute, time.Hour)
	ctx := context.Background()
	session, _ := service.GuestLogin(ctx, GuestLoginRequest{DisplayName: "Tester"})
	upgraded, err := service.UpgradeGuest(ctx, UpgradeGuestRequest{
		PlayerID:        session.PlayerID,
		Provider:        "google",
		Platform:        "web",
		ProviderSubject: "subject-1",
		IdentityToken:   "dummy-token",
	})
	if err != nil {
		t.Fatalf("UpgradeGuest returned error: %v", err)
	}
	if upgraded.Session.PlayerID != session.PlayerID {
		t.Fatal("upgrade changed player id")
	}
	if upgraded.LinkedAccount.Platform != "h5" {
		t.Fatalf("web platform was not normalized to h5: %#v", upgraded.LinkedAccount)
	}

	other, _ := service.GuestLogin(ctx, GuestLoginRequest{DisplayName: "Other"})
	_, err = service.UpgradeGuest(ctx, UpgradeGuestRequest{
		PlayerID:        other.PlayerID,
		Provider:        "google",
		Platform:        "h5",
		ProviderSubject: "subject-1",
		IdentityToken:   "dummy-token",
	})
	if err == nil || err.Error() != "account_already_linked" {
		t.Fatalf("expected duplicate provider link error, got %v", err)
	}
}
