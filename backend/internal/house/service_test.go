package house

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestCatalogLoadsSharedHousingItemsConfig(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "housing_items.json")
	config := []byte(`{
		"items": [
			{
				"id": "test_sofa",
				"item_type": "furniture",
				"category": "seat",
				"size": {"width": 2, "height": 1},
				"rotatable": true,
				"price": 99
			}
		]
	}`)
	if err := os.WriteFile(path, config, 0o600); err != nil {
		t.Fatalf("write config: %v", err)
	}
	catalog, err := LoadCatalog(path)
	if err != nil {
		t.Fatalf("LoadCatalog returned error: %v", err)
	}
	item, ok := catalog["test_sofa"]
	if !ok {
		t.Fatalf("test_sofa missing from catalog: %#v", catalog)
	}
	if item.price != 99 || item.width != 2 || item.height != 1 || !item.rotatable {
		t.Fatalf("catalog item did not load from shared JSON: %#v", item)
	}
}

func TestDefaultCatalogCanReadRepoHousingConfig(t *testing.T) {
	catalog := DefaultCatalog()
	for _, itemID := range []string{
		"starter_wallpaper",
		"wooden_floor",
		"simple_chair",
		"tiny_table",
		"potted_plant",
		"arcade_cabinet",
	} {
		if _, ok := catalog[itemID]; !ok {
			t.Fatalf("expected %s from shared housing catalog", itemID)
		}
	}
	if catalog["tiny_table"].width != 2 || catalog["arcade_cabinet"].height != 2 {
		t.Fatalf("shared housing sizes are not reflected in backend catalog: %#v", catalog)
	}
}

func TestMemoryPlaceItemRejectsInvalidAndOccupiedTiles(t *testing.T) {
	service := NewMemoryService()
	ctx := context.Background()

	_, err := service.PlaceItem(ctx, PlaceRequest{
		OwnerID: "player_1",
		ItemID:  "tiny_table",
		TileX:   RoomGridWidth - 1,
		TileY:   0,
	})
	if !errors.Is(err, ErrInvalidPlacement) {
		t.Fatalf("expected invalid placement, got %v", err)
	}

	layout, err := service.PlaceItem(ctx, PlaceRequest{
		OwnerID: "player_1",
		ItemID:  "simple_chair",
		TileX:   0,
		TileY:   0,
	})
	if err != nil {
		t.Fatalf("place first item: %v", err)
	}
	if len(layout.Items) != 1 {
		t.Fatalf("expected one placed item, got %#v", layout.Items)
	}

	_, err = service.PlaceItem(ctx, PlaceRequest{
		OwnerID: "player_1",
		ItemID:  "potted_plant",
		TileX:   0,
		TileY:   0,
	})
	if !errors.Is(err, ErrOccupiedTile) {
		t.Fatalf("expected occupied tile, got %v", err)
	}

	layout, err = service.GetLayout(ctx, "player_1")
	if err != nil {
		t.Fatalf("get layout: %v", err)
	}
	if len(layout.Items) != 1 {
		t.Fatalf("invalid placement mutated layout: %#v", layout.Items)
	}
}

func TestMemoryPlacementUsesRotatedFootprint(t *testing.T) {
	service := NewMemoryService()
	ctx := context.Background()

	_, err := service.PlaceItem(ctx, PlaceRequest{
		OwnerID:  "player_1",
		ItemID:   "arcade_cabinet",
		TileX:    0,
		TileY:    RoomGridHeight - 1,
		Rotation: 0,
	})
	if !errors.Is(err, ErrInvalidPlacement) {
		t.Fatalf("expected unrotated cabinet to exceed bottom edge, got %v", err)
	}

	_, err = service.PlaceItem(ctx, PlaceRequest{
		OwnerID:  "player_1",
		ItemID:   "arcade_cabinet",
		TileX:    RoomGridWidth - 2,
		TileY:    0,
		Rotation: 90,
	})
	if err != nil {
		t.Fatalf("expected rotated cabinet to fit, got %v", err)
	}
}

func TestMemoryMoveAndRemoveItem(t *testing.T) {
	service := NewMemoryService()
	ctx := context.Background()

	layout, err := service.PlaceItem(ctx, PlaceRequest{
		OwnerID: "player_1",
		ItemID:  "tiny_table",
		TileX:   0,
		TileY:   0,
	})
	if err != nil {
		t.Fatalf("place table: %v", err)
	}
	_, err = service.PlaceItem(ctx, PlaceRequest{
		OwnerID: "player_1",
		ItemID:  "simple_chair",
		TileX:   5,
		TileY:   2,
	})
	if err != nil {
		t.Fatalf("place chair: %v", err)
	}

	layout, err = service.MoveItem(ctx, MoveRequest{
		OwnerID: "player_1",
		Item: ItemRef{
			ItemID:   "tiny_table",
			TileX:    layout.Items[0].TileX,
			TileY:    layout.Items[0].TileY,
			Rotation: layout.Items[0].Rotation,
		},
		TargetTileX:    3,
		TargetTileY:    2,
		TargetRotation: 90,
	})
	if err != nil {
		t.Fatalf("move table: %v", err)
	}
	if layout.Items[0].TileX != 3 || layout.Items[0].TileY != 2 || layout.Items[0].Rotation != 90 {
		t.Fatalf("move did not update the table: %#v", layout.Items[0])
	}

	_, err = service.MoveItem(ctx, MoveRequest{
		OwnerID: "player_1",
		Item: ItemRef{
			ItemID:   "tiny_table",
			TileX:    3,
			TileY:    2,
			Rotation: 90,
		},
		TargetTileX:    5,
		TargetTileY:    2,
		TargetRotation: 0,
	})
	if !errors.Is(err, ErrOccupiedTile) {
		t.Fatalf("expected occupied move to fail, got %v", err)
	}

	layout, removed, err := service.RemoveItem(ctx, RemoveRequest{
		OwnerID: "player_1",
		Item: ItemRef{
			ItemID:   "tiny_table",
			TileX:    3,
			TileY:    2,
			Rotation: 90,
		},
	})
	if err != nil {
		t.Fatalf("remove table: %v", err)
	}
	if removed.ItemID != "tiny_table" || len(layout.Items) != 1 {
		t.Fatalf("remove returned unexpected layout or item: %#v %#v", removed, layout.Items)
	}

	_, _, err = service.RemoveItem(ctx, RemoveRequest{
		OwnerID: "player_1",
		Item: ItemRef{
			ItemID: "tiny_table",
			TileX:  3,
			TileY:  2,
		},
	})
	if !errors.Is(err, ErrItemNotPlaced) {
		t.Fatalf("expected missing item error, got %v", err)
	}
}

func TestMemoryApplyStyleRejectsFurnitureAndCategoryMismatch(t *testing.T) {
	service := NewMemoryService()
	ctx := context.Background()

	_, err := service.ApplyStyle(ctx, StyleRequest{
		OwnerID:  "player_1",
		Category: "wall",
		ItemID:   "simple_chair",
	})
	if !errors.Is(err, ErrInvalidStyle) {
		t.Fatalf("expected invalid style for furniture, got %v", err)
	}

	_, err = service.ApplyStyle(ctx, StyleRequest{
		OwnerID:  "player_1",
		Category: "floor",
		ItemID:   "starter_wallpaper",
	})
	if !errors.Is(err, ErrInvalidStyle) {
		t.Fatalf("expected category mismatch, got %v", err)
	}

	layout, err := service.ApplyStyle(ctx, StyleRequest{
		OwnerID:  "player_1",
		Category: "wall",
		ItemID:   "starter_wallpaper",
	})
	if err != nil {
		t.Fatalf("valid style rejected: %v", err)
	}
	if layout.Styles["wall"] != "starter_wallpaper" {
		t.Fatalf("expected wall style to update, got %#v", layout.Styles)
	}
}
