package utility

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

const activePanelRecordID = "active"

type PanelRecord struct {
	ID         string `gorm:"primaryKey;size:40"`
	PanelsJSON string `gorm:"type:text;not null"`
	UpdatedAt  int64  `gorm:"not null"`
}

func (PanelRecord) TableName() string {
	return "utility_panel_records"
}

func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(&PanelRecord{})
}

type GormService struct {
	db   *gorm.DB
	seed Panels
}

func NewGormService(db *gorm.DB, seed Panels) *GormService {
	if err := validatePanels(seed); err != nil {
		seed = DefaultPanels()
	}
	return &GormService{db: db, seed: clonePanels(seed)}
}

func (s *GormService) Panels(ctx context.Context, playerID string) (Panels, error) {
	if err := ctx.Err(); err != nil {
		return Panels{}, err
	}
	if playerID == "" {
		return Panels{}, errors.New("player_required")
	}
	panels, err := s.loadPanels(ctx)
	if err != nil {
		return Panels{}, err
	}
	panels.PlayerID = playerID
	panels.ServerTime = time.Now().Unix()
	return panels, nil
}

func (s *GormService) Shop(ctx context.Context, playerID string) (ShopPanel, error) {
	panels, err := s.Panels(ctx, playerID)
	return panels.Shop, err
}

func (s *GormService) Mail(ctx context.Context, playerID string) (MailPanel, error) {
	panels, err := s.Panels(ctx, playerID)
	return panels.Mail, err
}

func (s *GormService) Notices(ctx context.Context, playerID string) (NoticePanel, error) {
	panels, err := s.Panels(ctx, playerID)
	return panels.Notice, err
}

func (s *GormService) UpdatePanels(ctx context.Context, panels Panels) (Panels, error) {
	if err := ctx.Err(); err != nil {
		return Panels{}, err
	}
	if err := validatePanels(panels); err != nil {
		return Panels{}, err
	}
	updated := clonePanels(panels)
	if err := s.savePanels(ctx, updated); err != nil {
		return Panels{}, err
	}
	updated.PlayerID = ""
	updated.ServerTime = time.Now().Unix()
	return updated, nil
}

func (s *GormService) loadPanels(ctx context.Context) (Panels, error) {
	var record PanelRecord
	err := s.db.WithContext(ctx).First(&record, "id = ?", activePanelRecordID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		seed := clonePanels(s.seed)
		if err := s.savePanels(ctx, seed); err != nil {
			return Panels{}, err
		}
		return seed, nil
	}
	if err != nil {
		return Panels{}, err
	}
	panels, err := record.ToPanels()
	if err != nil {
		return Panels{}, err
	}
	if err := validatePanels(panels); err != nil {
		return Panels{}, err
	}
	return clonePanels(panels), nil
}

func (s *GormService) savePanels(ctx context.Context, panels Panels) error {
	record, err := NewPanelRecord(panels)
	if err != nil {
		return err
	}
	return s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "id"}},
		UpdateAll: true,
	}).Create(&record).Error
}

func NewPanelRecord(panels Panels) (PanelRecord, error) {
	if err := validatePanels(panels); err != nil {
		return PanelRecord{}, err
	}
	stored := clonePanels(panels)
	stored.PlayerID = ""
	stored.ServerTime = 0
	bytes, err := json.Marshal(stored)
	if err != nil {
		return PanelRecord{}, err
	}
	return PanelRecord{
		ID:         activePanelRecordID,
		PanelsJSON: string(bytes),
		UpdatedAt:  time.Now().Unix(),
	}, nil
}

func (r PanelRecord) ToPanels() (Panels, error) {
	var panels Panels
	if err := json.Unmarshal([]byte(r.PanelsJSON), &panels); err != nil {
		return Panels{}, err
	}
	panels.PlayerID = ""
	panels.ServerTime = 0
	return panels, nil
}
