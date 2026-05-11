package player

import (
	"context"
	"errors"
	"sort"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type MapDiscoveryRecord struct {
	PlayerID       string `gorm:"primaryKey;size:80"`
	MapID          string `gorm:"primaryKey;size:80"`
	Source         string `gorm:"size:24;not null;default:sync"`
	DiscoveredUnix int64
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

type GormService struct {
	db *gorm.DB
}

func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(&MapDiscoveryRecord{})
}

func NewGormService(db *gorm.DB) Service {
	return &GormService{db: db}
}

func (s *GormService) GetProfile(ctx context.Context, playerID string) (Profile, error) {
	playerID = normalizePlayerID(playerID)
	if playerID == "" {
		return Profile{}, errors.New("player_required")
	}
	return Profile{PlayerID: playerID, DisplayName: "Guest", Locale: "en"}, nil
}

func (s *GormService) DiscoveredMaps(ctx context.Context, playerID string) (DiscoveredMaps, error) {
	playerID = normalizePlayerID(playerID)
	if playerID == "" {
		return DiscoveredMaps{}, errors.New("player_required")
	}
	if err := s.ensureDefault(ctx, playerID); err != nil {
		return DiscoveredMaps{}, err
	}
	records := []MapDiscoveryRecord{}
	err := s.db.WithContext(ctx).
		Where("player_id = ?", playerID).
		Order("map_id asc").
		Find(&records).Error
	if err != nil {
		return DiscoveredMaps{}, err
	}
	return discoveryFromRecords(playerID, records), nil
}

func (s *GormService) DiscoverMap(ctx context.Context, playerID string, mapID string, source string) (DiscoveredMaps, error) {
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
	if err := s.saveDiscovery(ctx, playerID, mapID, source); err != nil {
		return DiscoveredMaps{}, err
	}
	return s.DiscoveredMaps(ctx, playerID)
}

func (s *GormService) SyncDiscoveredMaps(ctx context.Context, playerID string, mapIDs []string, source string) (DiscoveredMaps, error) {
	playerID = normalizePlayerID(playerID)
	source = normalizeDiscoverySource(source, SourceSync)
	if playerID == "" {
		return DiscoveredMaps{}, errors.New("player_required")
	}
	if source == "" {
		return DiscoveredMaps{}, errors.New("source_required")
	}
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		service := &GormService{db: tx}
		if err := service.saveDiscovery(ctx, playerID, DefaultMapID, SourceDefault); err != nil {
			return err
		}
		for _, mapID := range mapIDs {
			mapID = normalizeMapID(mapID)
			if mapID == "" {
				continue
			}
			if err := service.saveDiscovery(ctx, playerID, mapID, source); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return DiscoveredMaps{}, err
	}
	return s.DiscoveredMaps(ctx, playerID)
}

func (s *GormService) ensureDefault(ctx context.Context, playerID string) error {
	return s.saveDiscovery(ctx, playerID, DefaultMapID, SourceDefault)
}

func (s *GormService) saveDiscovery(ctx context.Context, playerID string, mapID string, source string) error {
	now := time.Now().Unix()
	record := MapDiscoveryRecord{PlayerID: playerID, MapID: mapID, Source: source, DiscoveredUnix: now}
	return s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "player_id"}, {Name: "map_id"}},
		DoNothing: true,
	}).Create(&record).Error
}

func discoveryFromRecords(playerID string, records []MapDiscoveryRecord) DiscoveredMaps {
	mapIDs := make([]string, 0, len(records))
	maps := make([]MapDiscovery, 0, len(records))
	updatedAt := int64(0)
	for _, record := range records {
		source := normalizeDiscoverySource(record.Source, SourceSync)
		if source == "" {
			source = SourceSync
		}
		mapIDs = append(mapIDs, record.MapID)
		maps = append(maps, MapDiscovery{
			MapID:        record.MapID,
			Source:       source,
			DiscoveredAt: record.DiscoveredUnix,
		})
		if record.DiscoveredUnix > updatedAt {
			updatedAt = record.DiscoveredUnix
		}
	}
	sort.Strings(mapIDs)
	sort.Slice(maps, func(i int, j int) bool {
		return maps[i].MapID < maps[j].MapID
	})
	return DiscoveredMaps{PlayerID: playerID, MapIDs: mapIDs, Maps: maps, UpdatedAt: updatedAt}
}
