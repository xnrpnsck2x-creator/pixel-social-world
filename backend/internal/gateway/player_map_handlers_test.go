package gateway

import (
	"net/http"
	"testing"
)

func TestPlayerMapDiscoveryLifecycle(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	alice := testGuestLogin(t, server, "Map Alice")
	token := alice["access_token"].(string)
	playerID := alice["player_id"].(string)

	initial := testGetJSON(
		t,
		server,
		"/players/maps/discovered?player_id="+playerID,
		token,
		http.StatusOK,
	)
	assertMapIDs(t, initial, []string{"city_forest_dawn_v1"})

	discovered := testPostJSON(t, server, "/players/maps/discovered", token, map[string]any{
		"player_id": playerID,
		"map_id":    "city_port_market_v1",
		"source":    "arrival",
	}, http.StatusOK)
	assertMapIDs(t, discovered, []string{"city_forest_dawn_v1", "city_port_market_v1"})
	assertMapSource(t, discovered, "city_port_market_v1", "arrival")

	synced := testPostJSON(t, server, "/players/maps/discovered/sync", token, map[string]any{
		"player_id": playerID,
		"map_ids":   []string{"life_crystal_mine_v1", "../../bad"},
		"source":    "sync",
	}, http.StatusOK)
	assertMapIDs(
		t,
		synced,
		[]string{"city_forest_dawn_v1", "city_port_market_v1", "life_crystal_mine_v1"},
	)
	assertMapSource(t, synced, "city_port_market_v1", "arrival")
	assertMapSource(t, synced, "life_crystal_mine_v1", "sync")
}

func TestPlayerMapDiscoveryAuthAndValidation(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	alice := testGuestLogin(t, server, "Map Owner")
	bob := testGuestLogin(t, server, "Map Visitor")
	aliceID := alice["player_id"].(string)

	testGetJSON(
		t,
		server,
		"/players/maps/discovered?player_id="+aliceID,
		bob["access_token"].(string),
		http.StatusUnauthorized,
	)

	invalid := testPostJSON(t, server, "/players/maps/discovered", alice["access_token"].(string), map[string]any{
		"player_id": aliceID,
		"map_id":    "../../bad",
	}, http.StatusBadRequest)
	if invalid["error"] != "map_required" {
		t.Fatalf("expected map_required, got %#v", invalid)
	}

	invalidSource := testPostJSON(t, server, "/players/maps/discovered", alice["access_token"].(string), map[string]any{
		"player_id": aliceID,
		"map_id":    "city_port_market_v1",
		"source":    "quest",
	}, http.StatusBadRequest)
	if invalidSource["error"] != "source_required" {
		t.Fatalf("expected source_required, got %#v", invalidSource)
	}
}

func TestAdminCanUnlockPlayerMap(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "viewer:view-token,owner:owner-token"
	server := NewServerWithDependencies(deps)
	alice := testGuestLogin(t, server, "Admin Map Owner")
	aliceID := alice["player_id"].(string)

	testPostJSON(t, server, "/admin/players/maps/discovered", "view-token", map[string]any{
		"player_id": aliceID,
		"map_id":    "social_trade_market_v1",
		"confirm":   true,
	}, http.StatusForbidden)

	confirmation := testPostJSON(t, server, "/admin/players/maps/discovered", "owner-token", map[string]any{
		"player_id": aliceID,
		"map_id":    "social_trade_market_v1",
	}, http.StatusBadRequest)
	if confirmation["error"] != "confirmation_required" {
		t.Fatalf("expected confirmation_required, got %#v", confirmation)
	}

	unlocked := testPostJSON(t, server, "/admin/players/maps/discovered", "owner-token", map[string]any{
		"player_id": aliceID,
		"map_id":    "social_trade_market_v1",
		"confirm":   true,
		"note":      "alpha route grant",
	}, http.StatusOK)
	discovered := unlocked["discovered"].(map[string]any)
	assertMapSource(t, discovered, "social_trade_market_v1", "admin")
}

func assertMapIDs(t *testing.T, response map[string]any, expected []string) {
	t.Helper()
	raw, ok := response["map_ids"].([]any)
	if !ok {
		t.Fatalf("expected map_ids array, got %#v", response)
	}
	seen := map[string]bool{}
	for _, value := range raw {
		seen[value.(string)] = true
	}
	for _, mapID := range expected {
		if !seen[mapID] {
			t.Fatalf("expected map %s in %#v", mapID, response)
		}
	}
	if len(seen) != len(expected) {
		t.Fatalf("expected only %#v, got %#v", expected, response)
	}
}

func assertMapSource(t *testing.T, response map[string]any, mapID string, source string) {
	t.Helper()
	raw, ok := response["maps"].([]any)
	if !ok {
		t.Fatalf("expected maps array, got %#v", response)
	}
	for _, value := range raw {
		row := value.(map[string]any)
		if row["map_id"] == mapID {
			if row["source"] != source {
				t.Fatalf("expected %s source %s, got %#v", mapID, source, row)
			}
			return
		}
	}
	t.Fatalf("expected map source for %s in %#v", mapID, response)
}
