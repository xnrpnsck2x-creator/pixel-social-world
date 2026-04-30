package gateway

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
)

func TestGuestUpgradeSupportsH5AndPreservesPlayer(t *testing.T) {
	server := NewServer()
	guest := testGuestLogin(t, server, "H5 Upgrade")
	playerID := guest["player_id"].(string)
	accessToken := guest["access_token"].(string)
	payload := map[string]any{
		"player_id":        playerID,
		"provider":         "google",
		"platform":         "h5",
		"provider_subject": "web-subject-1",
		"identity_token":   "dummy-h5-id-token",
		"email":            "h5@example.test",
	}

	testPostJSON(t, server, "/auth/upgrade", "", payload, http.StatusUnauthorized)
	upgraded := testPostJSON(t, server, "/auth/upgrade", accessToken, payload, http.StatusOK)
	session := upgraded["session"].(map[string]any)
	if session["player_id"] != playerID {
		t.Fatalf("upgrade changed player id: %v", session["player_id"])
	}
	if session["access_token"] == "" || session["access_token"] == accessToken {
		t.Fatal("upgrade did not issue a fresh access token")
	}
	linked := upgraded["linked_account"].(map[string]any)
	if linked["platform"] != "h5" || linked["provider"] != "google" {
		t.Fatalf("unexpected linked account metadata: %#v", linked)
	}

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/me?player_id="+url.QueryEscape(playerID), nil)
	request.Header.Set("Authorization", "Bearer "+session["access_token"].(string))
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("upgraded session could not fetch profile: %d %s", recorder.Code, recorder.Body.String())
	}
	var profile map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &profile); err != nil {
		t.Fatalf("decode profile: %v", err)
	}
	wallet := profile["wallet"].(map[string]any)
	if int(wallet["coin"].(float64)) != startingCoinBalance {
		t.Fatalf("upgrade lost wallet balance: %#v", wallet)
	}

	other := testGuestLogin(t, server, "Other H5")
	payload["player_id"] = other["player_id"].(string)
	conflict := testPostJSON(t, server, "/auth/upgrade", other["access_token"].(string), payload, http.StatusConflict)
	if conflict["error"] != "account_already_linked" {
		t.Fatalf("unexpected duplicate link error: %#v", conflict)
	}
}
