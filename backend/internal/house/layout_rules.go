package house

type gridRect struct {
	x int
	y int
	w int
	h int
}

func validatePlacement(catalog Catalog, layout Layout, request PlaceRequest) error {
	item, ok := catalog[request.ItemID]
	if !ok {
		return ErrUnknownItem
	}
	if item.itemType == "surface" {
		return ErrInvalidPlacement
	}
	target, err := placementRect(catalog, request.ItemID, request.TileX, request.TileY, request.Rotation)
	if err != nil {
		return err
	}
	for _, placed := range layout.Items {
		existing, err := placementRect(catalog, placed.ItemID, placed.TileX, placed.TileY, placed.Rotation)
		if err != nil {
			continue
		}
		if rectsOverlap(target, existing) {
			return ErrOccupiedTile
		}
	}
	return nil
}

func validateStyle(catalog Catalog, request StyleRequest) error {
	item, ok := catalog[request.ItemID]
	if !ok {
		return ErrUnknownItem
	}
	if item.itemType != "surface" {
		return ErrInvalidStyle
	}
	if request.Category != "" && request.Category != item.category {
		return ErrInvalidStyle
	}
	return nil
}

func validateMove(catalog Catalog, layout Layout, request MoveRequest) (int, error) {
	index, err := findPlacedItem(layout, request.Item)
	if err != nil {
		return -1, err
	}
	target, err := placementRect(
		catalog,
		request.Item.ItemID,
		request.TargetTileX,
		request.TargetTileY,
		request.TargetRotation,
	)
	if err != nil {
		return -1, err
	}
	for placedIndex, placed := range layout.Items {
		if placedIndex == index {
			continue
		}
		existing, err := placementRect(catalog, placed.ItemID, placed.TileX, placed.TileY, placed.Rotation)
		if err != nil {
			continue
		}
		if rectsOverlap(target, existing) {
			return -1, ErrOccupiedTile
		}
	}
	return index, nil
}

func findPlacedItem(layout Layout, item ItemRef) (int, error) {
	for index, placed := range layout.Items {
		if placed.ItemID == item.ItemID &&
			placed.TileX == item.TileX &&
			placed.TileY == item.TileY &&
			normalizeRotation(placed.Rotation) == normalizeRotation(item.Rotation) {
			return index, nil
		}
	}
	return -1, ErrItemNotPlaced
}

func placementRect(catalog Catalog, itemID string, x int, y int, rotation int) (gridRect, error) {
	item, ok := catalog[itemID]
	if !ok {
		return gridRect{}, ErrUnknownItem
	}
	if !validRotation(item, rotation) {
		return gridRect{}, ErrInvalidPlacement
	}
	width, height := itemSize(item, rotation)
	rect := gridRect{x: x, y: y, w: width, h: height}
	if rect.x < 0 || rect.y < 0 ||
		rect.x+rect.w > RoomGridWidth ||
		rect.y+rect.h > RoomGridHeight {
		return gridRect{}, ErrInvalidPlacement
	}
	return rect, nil
}

func validRotation(item catalogItem, rotation int) bool {
	normalized := normalizeRotation(rotation)
	if normalized == 0 {
		return true
	}
	return item.rotatable && (normalized == 90 || normalized == 180 || normalized == 270)
}

func itemSize(item catalogItem, rotation int) (int, int) {
	width := max(1, item.width)
	height := max(1, item.height)
	normalized := normalizeRotation(rotation)
	if item.rotatable && (normalized == 90 || normalized == 270) {
		return height, width
	}
	return width, height
}

func normalizeRotation(rotation int) int {
	return ((rotation % 360) + 360) % 360
}

func rectsOverlap(a gridRect, b gridRect) bool {
	return a.x < b.x+b.w &&
		a.x+a.w > b.x &&
		a.y < b.y+b.h &&
		a.y+a.h > b.y
}
