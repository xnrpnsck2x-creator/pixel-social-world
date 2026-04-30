package gateway

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"pixel-social-world/backend/internal/utility"
)

func TestUtilityPanelsRequirePlayerAuthAndReturnConfiguredRows(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	session := testGuestLogin(t, server, "Utility Owner")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)

	testGetJSON(t, server, "/utility/panels?player_id="+playerID, "", http.StatusUnauthorized)

	panels := testGetJSON(t, server, "/utility/panels?player_id="+playerID, token, http.StatusOK)
	if panels["player_id"] != playerID {
		t.Fatalf("utility panels did not return player scope: %#v", panels)
	}
	shop := panels["shop"].(map[string]any)
	items := shop["items"].([]any)
	if len(items) == 0 || items[0].(map[string]any)["item_id"] == "" {
		t.Fatalf("utility panels did not include shop items: %#v", panels)
	}
	mail := panels["mail"].(map[string]any)
	messages := mail["messages"].([]any)
	if len(messages) == 0 || messages[0].(map[string]any)["subject_key"] == "" {
		t.Fatalf("utility panels did not include mail messages: %#v", panels)
	}

	notices := testGetJSON(t, server, "/utility/notices?player_id="+playerID, token, http.StatusOK)
	noticeItems := notices["notices"].([]any)
	if len(noticeItems) == 0 || noticeItems[0].(map[string]any)["action_id"] == "" {
		t.Fatalf("utility notices did not include action data: %#v", notices)
	}
}

func TestAdminCanReplaceUtilityPanels(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "test-admin"
	server := NewServerWithDependencies(deps)
	session := testGuestLogin(t, server, "Live Ops Owner")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)
	panels := utility.DefaultPanels()
	panels.Shop.Items = append(panels.Shop.Items, utility.ShopOffer{
		ID:        "live_ops_table_offer",
		ItemID:    "tiny_table",
		ActionID:  "home",
		ActionKey: "world.panel.action.home",
	})

	testPutUtilityPanels(t, server, panels, "", http.StatusForbidden)
	updated := testPutUtilityPanels(t, server, panels, "test-admin", http.StatusOK)
	shop := updated["shop"].(map[string]any)
	items := shop["items"].([]any)
	if items[len(items)-1].(map[string]any)["id"] != "live_ops_table_offer" {
		t.Fatalf("admin utility update did not return new offer: %#v", updated)
	}

	fetched := testGetJSON(t, server, "/utility/panels?player_id="+playerID, token, http.StatusOK)
	fetchedItems := fetched["shop"].(map[string]any)["items"].([]any)
	if fetchedItems[len(fetchedItems)-1].(map[string]any)["item_id"] != "tiny_table" {
		t.Fatalf("utility panels did not serve live ops update: %#v", fetched)
	}
}

func testPutUtilityPanels(
	t *testing.T,
	server *Server,
	panels utility.Panels,
	adminToken string,
	wantStatus int,
) map[string]any {
	t.Helper()
	body, err := json.Marshal(panels)
	if err != nil {
		t.Fatalf("marshal panels: %v", err)
	}
	request := httptest.NewRequest(http.MethodPut, "/admin/utility/panels", bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	if adminToken != "" {
		request.Header.Set("X-Admin-Token", adminToken)
	}
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != wantStatus {
		t.Fatalf("expected %d, got %d: %s", wantStatus, recorder.Code, recorder.Body.String())
	}
	var decoded map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	return decoded
}
