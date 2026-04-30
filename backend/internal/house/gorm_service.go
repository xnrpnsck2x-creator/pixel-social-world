package house

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type LayoutRecord struct {
	OwnerID     string `gorm:"primaryKey;size:80"`
	Version     int
	ItemsJSON   string
	StylesJSON  string
	CreatedUnix int64
	UpdatedUnix int64
}

type GormService struct {
	db      *gorm.DB
	catalog Catalog
}

func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(&LayoutRecord{})
}

func NewGormService(db *gorm.DB) Service {
	return NewGormServiceWithCatalog(db, DefaultCatalog())
}

func NewGormServiceWithCatalog(db *gorm.DB, catalog Catalog) Service {
	if len(catalog) == 0 {
		catalog = DefaultCatalog()
	}
	return &GormService{db: db, catalog: cloneCatalog(catalog)}
}

func (s *GormService) GetLayout(ctx context.Context, ownerID string) (Layout, error) {
	ownerID = normalizeOwnerID(ownerID)
	var record LayoutRecord
	err := s.db.WithContext(ctx).First(&record, "owner_id = ?", ownerID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return defaultLayout(ownerID), nil
	}
	if err != nil {
		return Layout{}, err
	}
	return record.toLayout()
}

func (s *GormService) SaveLayout(ctx context.Context, layout Layout) error {
	layout.OwnerID = normalizeOwnerID(layout.OwnerID)
	if layout.Version <= 0 {
		layout.Version = 1
	}
	record, err := layoutRecord(layout)
	if err != nil {
		return err
	}
	return s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "owner_id"}},
		UpdateAll: true,
	}).Create(&record).Error
}

func (s *GormService) ValidatePlacement(ctx context.Context, request PlaceRequest) error {
	request.OwnerID = normalizeOwnerID(request.OwnerID)
	layout, err := s.GetLayout(ctx, request.OwnerID)
	if err != nil {
		return err
	}
	return validatePlacement(s.catalog, layout, request)
}

func (s *GormService) PlaceItem(ctx context.Context, request PlaceRequest) (Layout, error) {
	request.OwnerID = normalizeOwnerID(request.OwnerID)
	var result Layout
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		layout, err := s.layoutForUpdate(tx, request.OwnerID)
		if err != nil {
			return err
		}
		if err := validatePlacement(s.catalog, layout, request); err != nil {
			return err
		}
		layout.Items = append(layout.Items, PlacedItem{
			ItemID:   request.ItemID,
			TileX:    request.TileX,
			TileY:    request.TileY,
			Rotation: normalizeRotation(request.Rotation),
		})
		layout.Version++
		if err := saveLayout(tx, layout); err != nil {
			return err
		}
		result = cloneLayout(layout)
		return nil
	})
	return result, err
}

func (s *GormService) ValidateStyle(_ context.Context, request StyleRequest) error {
	return validateStyle(s.catalog, request)
}

func (s *GormService) ApplyStyle(ctx context.Context, request StyleRequest) (Layout, error) {
	request.OwnerID = normalizeOwnerID(request.OwnerID)
	if request.Category == "" {
		request.Category = "style"
	}
	if err := validateStyle(s.catalog, request); err != nil {
		return Layout{}, err
	}
	var result Layout
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		layout, err := s.layoutForUpdate(tx, request.OwnerID)
		if err != nil {
			return err
		}
		layout.Styles[request.Category] = request.ItemID
		layout.Version++
		if err := saveLayout(tx, layout); err != nil {
			return err
		}
		result = cloneLayout(layout)
		return nil
	})
	return result, err
}

func (s *GormService) MoveItem(ctx context.Context, request MoveRequest) (Layout, error) {
	request.OwnerID = normalizeOwnerID(request.OwnerID)
	var result Layout
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		layout, err := s.layoutForUpdate(tx, request.OwnerID)
		if err != nil {
			return err
		}
		index, err := validateMove(s.catalog, layout, request)
		if err != nil {
			return err
		}
		layout.Items[index].TileX = request.TargetTileX
		layout.Items[index].TileY = request.TargetTileY
		layout.Items[index].Rotation = normalizeRotation(request.TargetRotation)
		layout.Version++
		if err := saveLayout(tx, layout); err != nil {
			return err
		}
		result = cloneLayout(layout)
		return nil
	})
	return result, err
}

func (s *GormService) RemoveItem(ctx context.Context, request RemoveRequest) (Layout, PlacedItem, error) {
	request.OwnerID = normalizeOwnerID(request.OwnerID)
	var result Layout
	var removed PlacedItem
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		layout, err := s.layoutForUpdate(tx, request.OwnerID)
		if err != nil {
			return err
		}
		index, err := findPlacedItem(layout, request.Item)
		if err != nil {
			return err
		}
		removed = layout.Items[index]
		layout.Items = append(layout.Items[:index], layout.Items[index+1:]...)
		layout.Version++
		if err := saveLayout(tx, layout); err != nil {
			return err
		}
		result = cloneLayout(layout)
		return nil
	})
	return result, removed, err
}

func (s *GormService) ItemPrice(itemID string) (int, bool) {
	item, ok := s.catalog[itemID]
	return item.price, ok
}

func (s *GormService) layoutForUpdate(tx *gorm.DB, ownerID string) (Layout, error) {
	var record LayoutRecord
	err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
		First(&record, "owner_id = ?", ownerID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		layout := defaultLayout(ownerID)
		return layout, saveLayout(tx, layout)
	}
	if err != nil {
		return Layout{}, err
	}
	return record.toLayout()
}

func saveLayout(tx *gorm.DB, layout Layout) error {
	record, err := layoutRecord(layout)
	if err != nil {
		return err
	}
	return tx.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "owner_id"}},
		UpdateAll: true,
	}).Create(&record).Error
}

func layoutRecord(layout Layout) (LayoutRecord, error) {
	items, err := json.Marshal(layout.Items)
	if err != nil {
		return LayoutRecord{}, err
	}
	styles, err := json.Marshal(layout.Styles)
	if err != nil {
		return LayoutRecord{}, err
	}
	now := time.Now().Unix()
	return LayoutRecord{
		OwnerID:     layout.OwnerID,
		Version:     layout.Version,
		ItemsJSON:   string(items),
		StylesJSON:  string(styles),
		CreatedUnix: now,
		UpdatedUnix: now,
	}, nil
}

func (r LayoutRecord) toLayout() (Layout, error) {
	items := []PlacedItem{}
	if r.ItemsJSON != "" {
		if err := json.Unmarshal([]byte(r.ItemsJSON), &items); err != nil {
			return Layout{}, err
		}
	}
	styles := map[string]string{}
	if r.StylesJSON != "" {
		if err := json.Unmarshal([]byte(r.StylesJSON), &styles); err != nil {
			return Layout{}, err
		}
	}
	if len(styles) == 0 {
		styles = defaultLayout(r.OwnerID).Styles
	}
	return Layout{
		OwnerID: r.OwnerID,
		Version: r.Version,
		Items:   items,
		Styles:  styles,
	}, nil
}
