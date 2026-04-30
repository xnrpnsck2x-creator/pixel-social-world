package auth

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestClaimedProviderVerifierRequiresSubject(t *testing.T) {
	verifier := NewClaimedProviderVerifier()
	_, err := verifier.VerifyProviderIdentity(context.Background(), UpgradeGuestRequest{
		Provider:      "google",
		IdentityToken: "token",
	})
	if err == nil || err.Error() != "provider_subject_required" {
		t.Fatalf("expected provider_subject_required, got %v", err)
	}
}

func TestMemoryUpgradeUsesVerifiedOIDCSubject(t *testing.T) {
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	jwksServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"keys": []map[string]string{rsaJWK(privateKey.PublicKey, "test-kid")},
		})
	}))
	defer jwksServer.Close()

	verifier := NewOIDCProviderVerifier(map[string]OIDCProviderSettings{
		"google": {
			Issuer:    "https://accounts.google.com",
			JWKSURL:   jwksServer.URL,
			Audiences: []string{"pixel-h5-client"},
		},
	})
	service := NewMemoryServiceWithProviderVerifier(time.Minute, time.Hour, verifier)
	session, err := service.GuestLogin(context.Background(), GuestLoginRequest{DisplayName: "OIDC"})
	if err != nil {
		t.Fatalf("guest login: %v", err)
	}

	token := signedRS256Token(t, privateKey, map[string]any{
		"iss":   "https://accounts.google.com",
		"sub":   "verified-subject",
		"aud":   "pixel-h5-client",
		"email": "verified@example.test",
		"exp":   time.Now().Add(time.Hour).Unix(),
		"iat":   time.Now().Add(-time.Minute).Unix(),
	})
	upgraded, err := service.UpgradeGuest(context.Background(), UpgradeGuestRequest{
		PlayerID:        session.PlayerID,
		Provider:        "google",
		Platform:        "h5",
		ProviderSubject: "verified-subject",
		IdentityToken:   token,
	})
	if err != nil {
		t.Fatalf("UpgradeGuest returned error: %v", err)
	}
	if upgraded.LinkedAccount.ProviderSubject != "verified-subject" {
		t.Fatalf("upgrade did not use verified subject: %#v", upgraded.LinkedAccount)
	}
	if upgraded.LinkedAccount.Email != "verified@example.test" {
		t.Fatalf("upgrade did not use verified email: %#v", upgraded.LinkedAccount)
	}
}

func TestOIDCVerifierRejectsAudienceAndSubjectMismatch(t *testing.T) {
	privateKey, _ := rsa.GenerateKey(rand.Reader, 2048)
	jwksServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"keys": []map[string]string{rsaJWK(privateKey.PublicKey, "test-kid")},
		})
	}))
	defer jwksServer.Close()

	verifier := NewOIDCProviderVerifier(map[string]OIDCProviderSettings{
		"apple": {
			Issuer:    "https://appleid.apple.com",
			JWKSURL:   jwksServer.URL,
			Audiences: []string{"pixel-ios-client"},
		},
	})
	token := signedRS256Token(t, privateKey, map[string]any{
		"iss": "https://appleid.apple.com",
		"sub": "apple-subject",
		"aud": "wrong-client",
		"exp": time.Now().Add(time.Hour).Unix(),
		"iat": time.Now().Add(-time.Minute).Unix(),
	})
	_, err := verifier.VerifyProviderIdentity(context.Background(), UpgradeGuestRequest{
		Provider:      "apple",
		IdentityToken: token,
	})
	if err == nil || err.Error() != "provider_audience_mismatch" {
		t.Fatalf("expected provider_audience_mismatch, got %v", err)
	}

	token = signedRS256Token(t, privateKey, map[string]any{
		"iss": "https://appleid.apple.com",
		"sub": "apple-subject",
		"aud": "pixel-ios-client",
		"exp": time.Now().Add(time.Hour).Unix(),
		"iat": time.Now().Add(-time.Minute).Unix(),
	})
	_, err = verifyUpgradeRequest(context.Background(), verifier, UpgradeGuestRequest{
		PlayerID:        "guest_1",
		Provider:        "apple",
		Platform:        "ios",
		ProviderSubject: "client-spoofed-subject",
		IdentityToken:   token,
	})
	if err == nil || err.Error() != "provider_subject_mismatch" {
		t.Fatalf("expected provider_subject_mismatch, got %v", err)
	}
}

func signedRS256Token(t *testing.T, key *rsa.PrivateKey, claims map[string]any) string {
	t.Helper()
	header := map[string]any{"alg": "RS256", "kid": "test-kid", "typ": "JWT"}
	headerBytes, _ := json.Marshal(header)
	claimBytes, _ := json.Marshal(claims)
	input := base64.RawURLEncoding.EncodeToString(headerBytes) + "." +
		base64.RawURLEncoding.EncodeToString(claimBytes)
	digest := sha256.Sum256([]byte(input))
	signature, err := rsa.SignPKCS1v15(rand.Reader, key, crypto.SHA256, digest[:])
	if err != nil {
		t.Fatalf("sign token: %v", err)
	}
	return input + "." + base64.RawURLEncoding.EncodeToString(signature)
}

func rsaJWK(key rsa.PublicKey, kid string) map[string]string {
	e := big.NewInt(int64(key.E)).Bytes()
	return map[string]string{
		"kty": "RSA",
		"use": "sig",
		"kid": kid,
		"alg": "RS256",
		"n":   base64.RawURLEncoding.EncodeToString(key.N.Bytes()),
		"e":   base64.RawURLEncoding.EncodeToString(e),
	}
}
