package house

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
)

const (
	RoomGridWidth  = 8
	RoomGridHeight = 5
)

var (
	ErrUnknownItem      = errors.New("unknown_item")
	ErrInvalidPlacement = errors.New("invalid_placement")
	ErrOccupiedTile     = errors.New("occupied_tile")
	ErrInvalidStyle     = errors.New("invalid_style")
	ErrItemNotPlaced    = errors.New("item_not_placed")
)

type catalogItem struct {
	price     int
	itemType  string
	category  string
	width     int
	height    int
	rotatable bool
}

type Catalog map[string]catalogItem

var fallbackCatalog = Catalog{
	"starter_wallpaper": {
		price:    8,
		itemType: "surface",
		category: "wall",
		width:    1,
		height:   1,
	},
	"wooden_floor": {
		price:    8,
		itemType: "surface",
		category: "floor",
		width:    1,
		height:   1,
	},
	"simple_chair": {
		price:     25,
		itemType:  "furniture",
		category:  "seat",
		width:     1,
		height:    1,
		rotatable: true,
	},
	"tiny_table": {
		price:     35,
		itemType:  "furniture",
		category:  "table",
		width:     2,
		height:    1,
		rotatable: true,
	},
	"potted_plant": {
		price:    45,
		itemType: "decor",
		category: "plant",
		width:    1,
		height:   1,
	},
	"arcade_cabinet": {
		price:     120,
		itemType:  "furniture",
		category:  "activity",
		width:     1,
		height:    2,
		rotatable: true,
	},
}

func DefaultCatalog() Catalog {
	for _, path := range []string{
		"configs/housing_items.json",
		"../configs/housing_items.json",
		"../../configs/housing_items.json",
		"../../../configs/housing_items.json",
	} {
		catalog, err := LoadCatalog(path)
		if err == nil {
			return catalog
		}
	}
	return cloneCatalog(fallbackCatalog)
}

func LoadCatalog(path string) (Catalog, error) {
	if path == "" {
		return DefaultCatalog(), nil
	}
	bytes, err := readHousingCatalog(path)
	if err != nil {
		return nil, err
	}
	var config struct {
		Items []struct {
			ID       string `json:"id"`
			ItemType string `json:"item_type"`
			Category string `json:"category"`
			Size     struct {
				Width  int `json:"width"`
				Height int `json:"height"`
			} `json:"size"`
			Rotatable bool `json:"rotatable"`
			Price     int  `json:"price"`
		} `json:"items"`
	}
	if err := json.Unmarshal(bytes, &config); err != nil {
		return nil, err
	}
	catalog := Catalog{}
	for _, item := range config.Items {
		if item.ID == "" {
			return nil, fmt.Errorf("housing catalog item missing id")
		}
		if item.ItemType == "" {
			return nil, fmt.Errorf("housing catalog item %s missing item_type", item.ID)
		}
		if item.Category == "" {
			return nil, fmt.Errorf("housing catalog item %s missing category", item.ID)
		}
		if item.Price < 0 {
			return nil, fmt.Errorf("housing catalog item %s has negative price", item.ID)
		}
		catalog[item.ID] = catalogItem{
			price:     item.Price,
			itemType:  item.ItemType,
			category:  item.Category,
			width:     max(1, item.Size.Width),
			height:    max(1, item.Size.Height),
			rotatable: item.Rotatable,
		}
	}
	if len(catalog) == 0 {
		return nil, fmt.Errorf("housing catalog must contain items")
	}
	return catalog, nil
}

func readHousingCatalog(path string) ([]byte, error) {
	bytes, err := os.ReadFile(path)
	if err == nil || !os.IsNotExist(err) {
		return bytes, err
	}
	for _, fallback := range []string{
		"configs/housing_items.json",
		"../configs/housing_items.json",
		"../../configs/housing_items.json",
		"../../../configs/housing_items.json",
	} {
		if fallback == path {
			continue
		}
		bytes, fallbackErr := os.ReadFile(fallback)
		if fallbackErr == nil {
			return bytes, nil
		}
	}
	return nil, err
}

func cloneCatalog(catalog Catalog) Catalog {
	cloned := Catalog{}
	for id, item := range catalog {
		cloned[id] = item
	}
	return cloned
}
