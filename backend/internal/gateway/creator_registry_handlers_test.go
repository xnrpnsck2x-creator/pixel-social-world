package gateway

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"pixel-social-world/backend/internal/creatorregistry"
)

func TestCreatorRegistryDiscoveryAndManifestResolution(t *testing.T) {
	registry := testCreatorRegistry(t)
	deps := DefaultMemoryDependencies()
	deps.CreatorRegistry = registry
	server := NewServerWithDependencies(deps)

	page := testGetJSON(
		t,
		server,
		"/creator-registry?kind=keyword&mode_id=casual_activity&q=fishing",
		"",
		http.StatusOK,
	)
	items := page["items"].([]any)
	if len(items) != 1 || items[0].(map[string]any)["id"] != "keyword.activity.fishing" {
		t.Fatalf("unexpected creator registry page: %#v", page)
	}

	session := testGuestLogin(t, server, "Registry Creator")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)
	discovery := testPostJSON(t, server, "/creator-discovery/keywords", token, map[string]any{
		"player_id": playerID,
		"text":      "我想做河边钓鱼和点击时机玩法",
		"locale":    "zh-Hans",
		"mode_id":   "casual_activity",
	}, http.StatusOK)
	matches := discovery["matches"].([]any)
	if len(matches) == 0 || matches[0].(map[string]any)["id"] != "keyword.activity.fishing" {
		t.Fatalf("unexpected creator keyword discovery: %#v", discovery)
	}

	resolution := resolveCreatorFishingManifest(t, server, token, playerID)
	if !resolution["ok"].(bool) {
		t.Fatalf("creator manifest resolution failed: %#v", resolution)
	}
	resolved := resolution["resolved_manifest"].(map[string]any)
	if resolved["lock_digest"] == "" {
		t.Fatalf("creator manifest was not locked: %#v", resolved)
	}
}

func TestCreatorRegistryETagAndDeclarativePackageGuard(t *testing.T) {
	registry := testCreatorRegistry(t)
	deps := DefaultMemoryDependencies()
	deps.CreatorRegistry = registry
	server := NewServerWithDependencies(deps)

	request := httptest.NewRequest(http.MethodGet, "/creator-registry", nil)
	request.Header.Set("If-None-Match", registry.ETag())
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusNotModified {
		t.Fatalf("expected registry 304, got %d: %s", recorder.Code, recorder.Body.String())
	}

	session := testGuestLogin(t, server, "Declarative Creator")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)
	resolution := resolveCreatorFishingManifest(t, server, token, playerID)
	resolved := resolution["resolved_manifest"].(map[string]any)

	meta := map[string]any{
		"game_id":            "creator_registry_fishing",
		"version":            "1.0.0",
		"author":             playerID,
		"mode_id":            "casual_activity",
		"name":               map[string]any{"en": "River Tap", "ja": "River Tap", "zh": "河畔点击"},
		"min_players":        1,
		"max_players":        1,
		"tags":               []any{"fishing", "timing"},
		"requires_network":   false,
		"runtime_contract":   map[string]any{"camera": "contained", "input_profile": "tap_timing", "network_profile": "offline_optional"},
		"entry_scene":        "",
		"main_script":        "",
		"asset_budget_bytes": 64 * 1024,
	}
	manifestJSON := mustCreatorJSON(t, resolved)
	entryJSON := mustCreatorJSON(t, map[string]any{
		"schema_version": 1,
		"game_id":        "creator_registry_fishing",
		"mode_id":        "casual_activity",
		"type":           "tap_timing",
		"settings":       map[string]any{"round_seconds": 45, "target_score": 10},
	})
	payload := cloneCreatorMap(meta)
	payload["resolved_manifest"] = resolved
	payload["files"] = []map[string]any{
		{"path": "meta.json", "content_text": mustCreatorJSON(t, meta)},
		{"path": "creator_manifest.json", "content_text": manifestJSON},
		{"path": "content/game.json", "content_text": entryJSON},
		{"path": "README.md", "content_text": "Declarative creator registry integration fixture."},
	}

	submitted := testPostJSON(
		t,
		server,
		"/creator-submissions/package",
		token,
		payload,
		http.StatusAccepted,
	)
	if submitted["status"] != "submitted" {
		t.Fatalf("unexpected declarative submit response: %#v", submitted)
	}
	waitCreatorStatus(
		t,
		server,
		"/creator-submissions/creator_registry_fishing/status?player_id="+playerID,
		token,
		"needs_review",
	)
	if _, err := server.minigameService.SetReviewStatus(
		t.Context(),
		"creator_registry_fishing",
		"approved",
	); err != nil {
		t.Fatalf("approve declarative package: %v", err)
	}
	if _, err := server.minigameService.SetReviewStatus(
		t.Context(),
		"creator_registry_fishing",
		"published",
	); err != nil {
		t.Fatalf("publish declarative package: %v", err)
	}
	runtime := testGetJSON(
		t,
		server,
		"/minigames/creator_registry_fishing/runtime",
		"",
		http.StatusOK,
	)
	if runtime["game_id"] != "creator_registry_fishing" ||
		runtime["definition"].(map[string]any)["type"] != "tap_timing" {
		t.Fatalf("unexpected public declarative runtime: %#v", runtime)
	}
	if _, exposed := runtime["install_uri"]; exposed {
		t.Fatalf("public runtime exposed server install paths: %#v", runtime)
	}
	creatorSession := testPostJSON(t, server, "/minigame-sessions", token, map[string]any{
		"game_id":        "creator_registry_fishing",
		"room_id":        "world_town_square",
		"host_player_id": playerID,
		"max_players":    99,
	}, http.StatusCreated)
	if creatorSession["game_id"] != "creator_registry_fishing" ||
		int(creatorSession["max_players"].(float64)) != 1 {
		t.Fatalf("published creator session ignored its catalog contract: %#v", creatorSession)
	}

	tampered := cloneCreatorMap(payload)
	tamperedManifest := cloneCreatorMap(resolved)
	tamperedManifest["lock_digest"] = "tampered"
	tampered["resolved_manifest"] = tamperedManifest
	testPostJSON(
		t,
		server,
		"/creator-submissions/package",
		token,
		tampered,
		http.StatusUnprocessableEntity,
	)
	if _, err := server.minigameService.UnpublishPackage(
		t.Context(),
		"creator_registry_fishing",
	); err != nil {
		t.Fatalf("unpublish creator session fixture: %v", err)
	}
	blockedJoin := testPostJSON(
		t,
		server,
		"/minigame-sessions/"+creatorSession["id"].(string)+"/join",
		token,
		map[string]any{"player_id": playerID},
		http.StatusGone,
	)
	if blockedJoin["error"] != "game_unavailable" {
		t.Fatalf("unpublished creator session remained joinable: %#v", blockedJoin)
	}
	sessionList := testGetJSON(
		t,
		server,
		"/minigame-sessions/world_town_square",
		"",
		http.StatusOK,
	)
	if len(sessionList["sessions"].([]any)) != 0 {
		t.Fatalf("unpublished creator session remained visible: %#v", sessionList)
	}
}

func TestMinigameSessionRejectsUnknownGame(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	session := testGuestLogin(t, server, "Unknown Game")
	response := testPostJSON(t, server, "/minigame-sessions", session["access_token"].(string), map[string]any{
		"game_id":        "not_in_catalog",
		"room_id":        "world_town_square",
		"host_player_id": session["player_id"],
		"max_players":    4,
	}, http.StatusBadRequest)
	if response["error"] != "game_unavailable" {
		t.Fatalf("unknown game session was not rejected: %#v", response)
	}
}

func TestCreatorPackagePublicEndpointRequiresResolvedManifest(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	session := testGuestLogin(t, server, "Manifest Guard")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)
	payload := creatorPackagePayload(t, playerID, "creator_manifest_required", safePackageScript())
	delete(payload, "resolved_manifest")

	response := testPostJSON(
		t,
		server,
		"/creator-submissions/package",
		token,
		payload,
		http.StatusUnprocessableEntity,
	)
	if response["error"] != "creator_manifest_required" {
		t.Fatalf("legacy code package was not rejected: %#v", response)
	}
}

func TestCreatorPackageBodyRejectsUnknownFields(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	session := testGuestLogin(t, server, "Strict Body")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)
	payload := creatorPackagePayload(t, playerID, "creator_unknown_body", safePackageScript())
	payload["system_api"] = "forbidden"

	testPostJSON(
		t,
		server,
		"/creator-submissions/package",
		token,
		payload,
		http.StatusBadRequest,
	)
}

func resolveCreatorFishingManifest(
	t *testing.T,
	server *Server,
	token string,
	playerID string,
) map[string]any {
	t.Helper()
	return testPostJSON(t, server, "/creator-manifests/resolve", token, map[string]any{
		"player_id": playerID,
		"manifest": map[string]any{
			"schema_version":    2,
			"registry_revision": "2026-07-25.2",
			"game_id":           "creator_registry_fishing",
			"mode_id":           "casual_activity",
			"interface": map[string]any{
				"id": "interface.declarative_runtime", "version": "1.0.0", "required": true,
			},
			"keywords": []any{"keyword.activity.fishing", "keyword.loop.tap_timing"},
			"capabilities": []any{
				map[string]any{"id": "cap.timer.local", "version": "1.0.0", "required": true},
				map[string]any{"id": "cap.score.submit", "version": "1.0.0"},
			},
			"assets": []any{
				map[string]any{"id": "assetpack.ui.pixel.base", "version": "1.0.0"},
			},
			"entry": map[string]any{"type": "declarative_v1", "path": "content/game.json"},
		},
	}, http.StatusOK)
}

func testCreatorRegistry(t *testing.T) *creatorregistry.Service {
	t.Helper()
	registry, err := creatorregistry.Load("../../../configs/creator_registry.json")
	if err != nil {
		t.Fatalf("load creator registry: %v", err)
	}
	return registry
}

func mustCreatorJSON(t *testing.T, value any) string {
	t.Helper()
	encoded, err := json.Marshal(value)
	if err != nil {
		t.Fatalf("marshal creator fixture: %v", err)
	}
	return string(encoded)
}

func cloneCreatorMap(source map[string]any) map[string]any {
	cloned := make(map[string]any, len(source))
	for key, value := range source {
		cloned[key] = value
	}
	return cloned
}
