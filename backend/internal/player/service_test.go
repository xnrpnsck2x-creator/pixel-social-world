package player

import (
	"context"
	"testing"
)

func TestMemoryServiceMapDiscoveryDefaultsAndSync(t *testing.T) {
	service := NewMemoryService()
	ctx := context.Background()
	playerID := "player_map_test"

	initial, err := service.DiscoveredMaps(ctx, playerID)
	if err != nil {
		t.Fatalf("initial discovered maps: %v", err)
	}
	assertPlayerMapIDs(t, initial.MapIDs, []string{DefaultMapID})

	discovered, err := service.DiscoverMap(ctx, playerID, "city_port_market_v1", SourceArrival)
	if err != nil {
		t.Fatalf("discover map: %v", err)
	}
	assertPlayerMapIDs(t, discovered.MapIDs, []string{DefaultMapID, "city_port_market_v1"})
	assertPlayerMapSource(t, discovered.Maps, "city_port_market_v1", SourceArrival)

	synced, err := service.SyncDiscoveredMaps(ctx, playerID, []string{"life_crystal_mine_v1", "../bad"}, SourceSync)
	if err != nil {
		t.Fatalf("sync discovered maps: %v", err)
	}
	assertPlayerMapIDs(
		t,
		synced.MapIDs,
		[]string{DefaultMapID, "city_port_market_v1", "life_crystal_mine_v1"},
	)
	assertPlayerMapSource(t, synced.Maps, "city_port_market_v1", SourceArrival)
	assertPlayerMapSource(t, synced.Maps, "life_crystal_mine_v1", SourceSync)
}

func TestMemoryServiceRejectsInvalidMapID(t *testing.T) {
	service := NewMemoryService()
	_, err := service.DiscoverMap(context.Background(), "player_map_test", "City_Port", SourceArrival)
	if err == nil || err.Error() != "map_required" {
		t.Fatalf("expected map_required, got %v", err)
	}
}

func TestMemoryServiceRejectsInvalidDiscoverySource(t *testing.T) {
	service := NewMemoryService()
	_, err := service.DiscoverMap(context.Background(), "player_map_test", "city_port_market_v1", "quest")
	if err == nil || err.Error() != "source_required" {
		t.Fatalf("expected source_required, got %v", err)
	}
}

func TestMemoryServiceKeepsFirstUnlockSource(t *testing.T) {
	service := NewMemoryService()
	ctx := context.Background()
	playerID := "player_first_source"
	first, err := service.DiscoverMap(ctx, playerID, "life_fishing_riverbend_v1", SourceNPC)
	if err != nil {
		t.Fatalf("npc discover: %v", err)
	}
	assertPlayerMapSource(t, first.Maps, "life_fishing_riverbend_v1", SourceNPC)
	second, err := service.DiscoverMap(ctx, playerID, "life_fishing_riverbend_v1", SourceArrival)
	if err != nil {
		t.Fatalf("arrival discover: %v", err)
	}
	assertPlayerMapSource(t, second.Maps, "life_fishing_riverbend_v1", SourceNPC)
}

func assertPlayerMapIDs(t *testing.T, actual []string, expected []string) {
	t.Helper()
	seen := map[string]bool{}
	for _, mapID := range actual {
		seen[mapID] = true
	}
	for _, mapID := range expected {
		if !seen[mapID] {
			t.Fatalf("expected %s in %#v", mapID, actual)
		}
	}
	if len(actual) != len(expected) {
		t.Fatalf("expected only %#v, got %#v", expected, actual)
	}
}

func assertPlayerMapSource(t *testing.T, actual []MapDiscovery, mapID string, source string) {
	t.Helper()
	for _, discovery := range actual {
		if discovery.MapID == mapID {
			if discovery.Source != source {
				t.Fatalf("expected %s source %s, got %#v", mapID, source, discovery)
			}
			return
		}
	}
	t.Fatalf("expected %s in %#v", mapID, actual)
}
