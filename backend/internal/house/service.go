package house

import (
	"context"
	"sync"
)

type PlacedItem struct {
	ItemID          string `json:"item_id"`
	TileX           int    `json:"tile_x"`
	TileY           int    `json:"tile_y"`
	Rotation        int    `json:"rotation"`
	InventoryLocked bool   `json:"inventory_locked,omitempty"`
	InventorySource string `json:"inventory_source,omitempty"`
	ReservationID   string `json:"reservation_id,omitempty"`
}

type Layout struct {
	OwnerID string            `json:"owner_id"`
	Version int               `json:"version"`
	Items   []PlacedItem      `json:"items"`
	Styles  map[string]string `json:"styles"`
}

type PlaceRequest struct {
	OwnerID         string `json:"owner_id"`
	ItemID          string `json:"item_id"`
	TileX           int    `json:"tile_x"`
	TileY           int    `json:"tile_y"`
	Rotation        int    `json:"rotation"`
	InventoryLocked bool   `json:"inventory_locked"`
	InventorySource string `json:"inventory_source"`
	ReservationID   string `json:"reservation_id"`
}

type StyleRequest struct {
	OwnerID  string `json:"owner_id"`
	Category string `json:"category"`
	ItemID   string `json:"item_id"`
}

type ItemRef struct {
	ItemID   string `json:"item_id"`
	TileX    int    `json:"tile_x"`
	TileY    int    `json:"tile_y"`
	Rotation int    `json:"rotation"`
}

type MoveRequest struct {
	OwnerID        string `json:"owner_id"`
	Item           ItemRef
	TargetTileX    int `json:"target_tile_x"`
	TargetTileY    int `json:"target_tile_y"`
	TargetRotation int `json:"target_rotation"`
}

type RemoveRequest struct {
	OwnerID string `json:"owner_id"`
	Item    ItemRef
}

type Service interface {
	GetLayout(ctx context.Context, ownerID string) (Layout, error)
	SaveLayout(ctx context.Context, layout Layout) error
	ValidatePlacement(ctx context.Context, request PlaceRequest) error
	PlaceItem(ctx context.Context, request PlaceRequest) (Layout, error)
	ValidateStyle(ctx context.Context, request StyleRequest) error
	ApplyStyle(ctx context.Context, request StyleRequest) (Layout, error)
	MoveItem(ctx context.Context, request MoveRequest) (Layout, error)
	RemoveItem(ctx context.Context, request RemoveRequest) (Layout, PlacedItem, error)
	ItemPrice(itemID string) (int, bool)
}

type MemoryService struct {
	mu      sync.Mutex
	layouts map[string]Layout
	catalog Catalog
}

func NewMemoryService() Service {
	return NewMemoryServiceWithCatalog(DefaultCatalog())
}

func NewMemoryServiceWithCatalog(catalog Catalog) Service {
	if len(catalog) == 0 {
		catalog = DefaultCatalog()
	}
	return &MemoryService{layouts: map[string]Layout{}, catalog: cloneCatalog(catalog)}
}

func (s *MemoryService) GetLayout(_ context.Context, ownerID string) (Layout, error) {
	ownerID = normalizeOwnerID(ownerID)
	s.mu.Lock()
	defer s.mu.Unlock()
	layout, ok := s.layouts[ownerID]
	if ok {
		return cloneLayout(layout), nil
	}
	return defaultLayout(ownerID), nil
}

func (s *MemoryService) SaveLayout(_ context.Context, layout Layout) error {
	layout.OwnerID = normalizeOwnerID(layout.OwnerID)
	if layout.Version <= 0 {
		layout.Version = 1
	}
	if layout.Styles == nil {
		layout.Styles = map[string]string{}
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.layouts[layout.OwnerID] = cloneLayout(layout)
	return nil
}

func (s *MemoryService) ValidatePlacement(_ context.Context, request PlaceRequest) error {
	request.OwnerID = normalizeOwnerID(request.OwnerID)
	s.mu.Lock()
	defer s.mu.Unlock()
	return validatePlacement(s.catalog, s.layoutForOwner(request.OwnerID), request)
}

func (s *MemoryService) PlaceItem(_ context.Context, request PlaceRequest) (Layout, error) {
	request.OwnerID = normalizeOwnerID(request.OwnerID)
	s.mu.Lock()
	defer s.mu.Unlock()
	layout := s.layoutForOwner(request.OwnerID)
	if err := validatePlacement(s.catalog, layout, request); err != nil {
		return Layout{}, err
	}
	layout.Items = append(layout.Items, PlacedItem{
		ItemID:          request.ItemID,
		TileX:           request.TileX,
		TileY:           request.TileY,
		Rotation:        normalizeRotation(request.Rotation),
		InventoryLocked: request.InventoryLocked,
		InventorySource: request.InventorySource,
		ReservationID:   request.ReservationID,
	})
	layout.Version++
	s.layouts[request.OwnerID] = cloneLayout(layout)
	return cloneLayout(layout), nil
}

func (s *MemoryService) ValidateStyle(_ context.Context, request StyleRequest) error {
	return validateStyle(s.catalog, request)
}

func (s *MemoryService) ApplyStyle(_ context.Context, request StyleRequest) (Layout, error) {
	request.OwnerID = normalizeOwnerID(request.OwnerID)
	if request.Category == "" {
		request.Category = "style"
	}
	if err := validateStyle(s.catalog, request); err != nil {
		return Layout{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	layout := s.layoutForOwner(request.OwnerID)
	layout.Styles[request.Category] = request.ItemID
	layout.Version++
	s.layouts[request.OwnerID] = cloneLayout(layout)
	return cloneLayout(layout), nil
}

func (s *MemoryService) MoveItem(_ context.Context, request MoveRequest) (Layout, error) {
	request.OwnerID = normalizeOwnerID(request.OwnerID)
	s.mu.Lock()
	defer s.mu.Unlock()
	layout := s.layoutForOwner(request.OwnerID)
	index, err := validateMove(s.catalog, layout, request)
	if err != nil {
		return Layout{}, err
	}
	layout.Items[index].TileX = request.TargetTileX
	layout.Items[index].TileY = request.TargetTileY
	layout.Items[index].Rotation = normalizeRotation(request.TargetRotation)
	layout.Version++
	s.layouts[request.OwnerID] = cloneLayout(layout)
	return cloneLayout(layout), nil
}

func (s *MemoryService) RemoveItem(_ context.Context, request RemoveRequest) (Layout, PlacedItem, error) {
	request.OwnerID = normalizeOwnerID(request.OwnerID)
	s.mu.Lock()
	defer s.mu.Unlock()
	layout := s.layoutForOwner(request.OwnerID)
	index, err := findPlacedItem(layout, request.Item)
	if err != nil {
		return Layout{}, PlacedItem{}, err
	}
	removed := layout.Items[index]
	layout.Items = append(layout.Items[:index], layout.Items[index+1:]...)
	layout.Version++
	s.layouts[request.OwnerID] = cloneLayout(layout)
	return cloneLayout(layout), removed, nil
}

func (s *MemoryService) ItemPrice(itemID string) (int, bool) {
	item, ok := s.catalog[itemID]
	return item.price, ok
}

func (s *MemoryService) layoutForOwner(ownerID string) Layout {
	layout, ok := s.layouts[ownerID]
	if ok {
		return cloneLayout(layout)
	}
	return defaultLayout(ownerID)
}

func defaultLayout(ownerID string) Layout {
	return Layout{
		OwnerID: ownerID,
		Version: 1,
		Items:   []PlacedItem{},
		Styles:  map[string]string{"wall": "starter_wallpaper", "floor": "wooden_floor"},
	}
}

func cloneLayout(layout Layout) Layout {
	copiedItems := make([]PlacedItem, len(layout.Items))
	copy(copiedItems, layout.Items)
	copiedStyles := map[string]string{}
	for key, value := range layout.Styles {
		copiedStyles[key] = value
	}
	layout.Items = copiedItems
	layout.Styles = copiedStyles
	return layout
}

func normalizeOwnerID(ownerID string) string {
	if ownerID == "" {
		return "offline-player"
	}
	return ownerID
}
