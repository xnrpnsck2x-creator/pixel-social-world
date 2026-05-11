package player

import (
	"context"
	"errors"
	"sort"
	"strings"
	"sync"
	"time"
)

const DefaultMapID = "city_forest_dawn_v1"
const SourceDefault = "default"
const SourceArrival = "arrival"
const SourceNPC = "npc"
const SourceItem = "item"
const SourceEvent = "event"
const SourceAdmin = "admin"
const SourceSync = "sync"

type Profile struct {
	PlayerID    string `json:"player_id"`
	DisplayName string `json:"display_name"`
	Locale      string `json:"locale"`
}

type DiscoveredMaps struct {
	PlayerID  string         `json:"player_id"`
	MapIDs    []string       `json:"map_ids"`
	Maps      []MapDiscovery `json:"maps"`
	UpdatedAt int64          `json:"updated_at"`
}

type MapDiscovery struct {
	MapID        string `json:"map_id"`
	Source       string `json:"source"`
	DiscoveredAt int64  `json:"discovered_at"`
}

type Service interface {
	GetProfile(ctx context.Context, playerID string) (Profile, error)
	DiscoveredMaps(ctx context.Context, playerID string) (DiscoveredMaps, error)
	DiscoverMap(ctx context.Context, playerID string, mapID string, source string) (DiscoveredMaps, error)
	SyncDiscoveredMaps(ctx context.Context, playerID string, mapIDs []string, source string) (DiscoveredMaps, error)
}

type MemoryService struct {
	mu          sync.Mutex
	discoveries map[string]map[string]MapDiscovery
}

func NewMemoryService() Service {
	return &MemoryService{discoveries: map[string]map[string]MapDiscovery{}}
}

func (s *MemoryService) GetProfile(ctx context.Context, playerID string) (Profile, error) {
	if err := ctx.Err(); err != nil {
		return Profile{}, err
	}
	playerID = normalizePlayerID(playerID)
	if playerID == "" {
		return Profile{}, errors.New("player_required")
	}
	return Profile{PlayerID: playerID, DisplayName: "Guest", Locale: "en"}, nil
}

func (s *MemoryService) DiscoveredMaps(ctx context.Context, playerID string) (DiscoveredMaps, error) {
	if err := ctx.Err(); err != nil {
		return DiscoveredMaps{}, err
	}
	playerID = normalizePlayerID(playerID)
	if playerID == "" {
		return DiscoveredMaps{}, errors.New("player_required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.snapshotLocked(playerID), nil
}

func (s *MemoryService) DiscoverMap(ctx context.Context, playerID string, mapID string, source string) (DiscoveredMaps, error) {
	if err := ctx.Err(); err != nil {
		return DiscoveredMaps{}, err
	}
	playerID = normalizePlayerID(playerID)
	mapID = normalizeMapID(mapID)
	source = normalizeDiscoverySource(source, SourceArrival)
	if playerID == "" {
		return DiscoveredMaps{}, errors.New("player_required")
	}
	if mapID == "" {
		return DiscoveredMaps{}, errors.New("map_required")
	}
	if source == "" {
		return DiscoveredMaps{}, errors.New("source_required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.saveDiscoveryLocked(playerID, mapID, source)
	return s.snapshotLocked(playerID), nil
}

func (s *MemoryService) SyncDiscoveredMaps(ctx context.Context, playerID string, mapIDs []string, source string) (DiscoveredMaps, error) {
	if err := ctx.Err(); err != nil {
		return DiscoveredMaps{}, err
	}
	playerID = normalizePlayerID(playerID)
	source = normalizeDiscoverySource(source, SourceSync)
	if playerID == "" {
		return DiscoveredMaps{}, errors.New("player_required")
	}
	if source == "" {
		return DiscoveredMaps{}, errors.New("source_required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.ensurePlayerLocked(playerID)
	for _, mapID := range mapIDs {
		mapID = normalizeMapID(mapID)
		if mapID != "" {
			s.saveDiscoveryLocked(playerID, mapID, source)
		}
	}
	return s.snapshotLocked(playerID), nil
}

func (s *MemoryService) snapshotLocked(playerID string) DiscoveredMaps {
	rows := s.ensurePlayerLocked(playerID)
	mapIDs := make([]string, 0, len(rows))
	maps := make([]MapDiscovery, 0, len(rows))
	updatedAt := int64(0)
	for mapID, discovery := range rows {
		mapIDs = append(mapIDs, mapID)
		maps = append(maps, discovery)
		if discovery.DiscoveredAt > updatedAt {
			updatedAt = discovery.DiscoveredAt
		}
	}
	sort.Strings(mapIDs)
	sort.Slice(maps, func(i int, j int) bool {
		return maps[i].MapID < maps[j].MapID
	})
	return DiscoveredMaps{PlayerID: playerID, MapIDs: mapIDs, Maps: maps, UpdatedAt: updatedAt}
}

func (s *MemoryService) ensurePlayerLocked(playerID string) map[string]MapDiscovery {
	rows, ok := s.discoveries[playerID]
	if !ok {
		rows = map[string]MapDiscovery{}
		s.discoveries[playerID] = rows
	}
	if rows[DefaultMapID].DiscoveredAt == 0 {
		rows[DefaultMapID] = MapDiscovery{
			MapID:        DefaultMapID,
			Source:       SourceDefault,
			DiscoveredAt: time.Now().Unix(),
		}
	}
	return rows
}

func (s *MemoryService) saveDiscoveryLocked(playerID string, mapID string, source string) {
	rows := s.ensurePlayerLocked(playerID)
	existing := rows[mapID]
	if existing.MapID != "" {
		return
	}
	rows[mapID] = MapDiscovery{MapID: mapID, Source: source, DiscoveredAt: time.Now().Unix()}
}

func normalizePlayerID(playerID string) string {
	return strings.TrimSpace(playerID)
}

func normalizeMapID(mapID string) string {
	mapID = strings.TrimSpace(mapID)
	if len(mapID) > 80 {
		return ""
	}
	for _, char := range mapID {
		if char == '_' || char == '-' {
			continue
		}
		if char >= 'a' && char <= 'z' || char >= '0' && char <= '9' {
			continue
		}
		return ""
	}
	return mapID
}

func normalizeDiscoverySource(source string, fallback string) string {
	source = strings.TrimSpace(source)
	if source == "" {
		source = fallback
	}
	switch source {
	case SourceDefault, SourceArrival, SourceNPC, SourceItem, SourceEvent, SourceAdmin, SourceSync:
		return source
	default:
		return ""
	}
}
