package player

import "context"

type Profile struct {
	PlayerID    string `json:"player_id"`
	DisplayName string `json:"display_name"`
	Locale      string `json:"locale"`
}

type Service interface {
	GetProfile(ctx context.Context, playerID string) (Profile, error)
}
