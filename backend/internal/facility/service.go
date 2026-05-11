package facility

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"sync"
	"time"
)

type Row struct {
	ID       string `json:"id"`
	TitleKey string `json:"title_key"`
	BodyKey  string `json:"body_key"`
	StateKey string `json:"state_key"`
	IconID   string `json:"icon_id"`
}

type Facility struct {
	MapID     string `json:"map_id"`
	Status    string `json:"status"`
	TitleKey  string `json:"title_key"`
	BodyKey   string `json:"body_key"`
	DetailKey string `json:"detail_key"`
	IconID    string `json:"icon_id"`
	Rows      []Row  `json:"rows"`
}

type Catalog struct {
	SchemaVersion int                 `json:"schema_version"`
	Facilities    map[string]Facility `json:"facilities"`
	PlayerID      string              `json:"player_id,omitempty"`
	ServerTime    int64               `json:"server_time,omitempty"`
}

type Service interface {
	Catalog(ctx context.Context, playerID string) (Catalog, error)
	Facility(ctx context.Context, playerID string, facilityID string) (Facility, error)
}

type StaticService struct {
	mu      sync.RWMutex
	catalog Catalog
}

func NewStaticService(catalog Catalog) *StaticService {
	if err := validateCatalog(catalog); err != nil {
		catalog = DefaultCatalog()
	}
	return &StaticService{catalog: cloneCatalog(catalog)}
}

func NewDefaultService() *StaticService {
	catalog, err := LoadCatalog("")
	if err != nil {
		catalog = DefaultCatalog()
	}
	return NewStaticService(catalog)
}

func LoadCatalog(path string) (Catalog, error) {
	bytes, err := readCatalogConfig(path)
	if err != nil {
		return Catalog{}, err
	}
	var catalog Catalog
	if err := json.Unmarshal(bytes, &catalog); err != nil {
		return Catalog{}, err
	}
	if err := validateCatalog(catalog); err != nil {
		return Catalog{}, err
	}
	return catalog, nil
}

func (s *StaticService) Catalog(ctx context.Context, playerID string) (Catalog, error) {
	if err := ctx.Err(); err != nil {
		return Catalog{}, err
	}
	if playerID == "" {
		return Catalog{}, errors.New("player_required")
	}
	s.mu.RLock()
	catalog := cloneCatalog(s.catalog)
	s.mu.RUnlock()
	catalog.PlayerID = playerID
	catalog.ServerTime = time.Now().Unix()
	return catalog, nil
}

func (s *StaticService) Facility(ctx context.Context, playerID string, facilityID string) (Facility, error) {
	catalog, err := s.Catalog(ctx, playerID)
	if err != nil {
		return Facility{}, err
	}
	facility, ok := catalog.Facilities[facilityID]
	if !ok {
		return Facility{}, errors.New("facility_not_found")
	}
	return cloneFacility(facility), nil
}

func DefaultCatalog() Catalog {
	return Catalog{
		SchemaVersion: 1,
		Facilities: map[string]Facility{
			"trade": {
				MapID:     "social_trade_market_v1",
				Status:    "local_contract",
				TitleKey:  "facility.trade.title",
				BodyKey:   "facility.trade.body",
				DetailKey: "facility.trade.detail",
				IconID:    "icon.coin",
				Rows: []Row{
					{ID: "market_board", TitleKey: "facility.trade.board.title", BodyKey: "facility.trade.board.body", StateKey: "facility.state.local", IconID: "icon.shop"},
					{ID: "creator_stalls", TitleKey: "facility.trade.creator_stalls.title", BodyKey: "facility.trade.creator_stalls.body", StateKey: "facility.state.locked_backend", IconID: "icon.gift"},
				},
			},
			"guild": {
				MapID:     "social_guild_garden_v1",
				Status:    "local_contract",
				TitleKey:  "facility.guild.title",
				BodyKey:   "facility.guild.body",
				DetailKey: "facility.guild.detail",
				IconID:    "icon.friends",
				Rows: []Row{
					{ID: "guild_board", TitleKey: "facility.guild.board.title", BodyKey: "facility.guild.board.body", StateKey: "facility.state.local", IconID: "icon.quest"},
					{ID: "group_photo", TitleKey: "facility.guild.group_photo.title", BodyKey: "facility.guild.group_photo.body", StateKey: "facility.state.ready", IconID: "icon.chat"},
				},
			},
		},
	}
}

func readCatalogConfig(path string) ([]byte, error) {
	paths := []string{}
	if path != "" {
		paths = append(paths, path)
	}
	paths = append(paths,
		"configs/social_facilities.json",
		"../configs/social_facilities.json",
		"../../configs/social_facilities.json",
		"../../../configs/social_facilities.json",
		"../../../../configs/social_facilities.json",
	)
	var firstErr error
	for _, candidate := range paths {
		bytes, err := os.ReadFile(candidate)
		if err == nil {
			return bytes, nil
		}
		if firstErr == nil {
			firstErr = err
		}
	}
	return nil, firstErr
}

func validateCatalog(catalog Catalog) error {
	if catalog.SchemaVersion <= 0 {
		return errors.New("facility_schema_version_required")
	}
	if len(catalog.Facilities) == 0 {
		return errors.New("facility_catalog_required")
	}
	for id, facility := range catalog.Facilities {
		if id == "" || facility.MapID == "" || facility.TitleKey == "" ||
			facility.BodyKey == "" || facility.DetailKey == "" || facility.IconID == "" {
			return errors.New("invalid_facility")
		}
		if len(facility.Rows) == 0 {
			return errors.New("facility_rows_required")
		}
		for _, row := range facility.Rows {
			if row.ID == "" || row.TitleKey == "" || row.BodyKey == "" || row.StateKey == "" || row.IconID == "" {
				return errors.New("invalid_facility_row")
			}
		}
	}
	return nil
}

func cloneCatalog(catalog Catalog) Catalog {
	next := catalog
	next.Facilities = make(map[string]Facility, len(catalog.Facilities))
	for id, facility := range catalog.Facilities {
		next.Facilities[id] = cloneFacility(facility)
	}
	return next
}

func cloneFacility(facility Facility) Facility {
	next := facility
	next.Rows = append([]Row(nil), facility.Rows...)
	return next
}
