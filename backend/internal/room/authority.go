package room

import "context"

type RoomAuthorizer interface {
	CanJoinRoom(ctx context.Context, playerID string, roomID string) bool
}

func WithRoomAuthorizer(authorizer RoomAuthorizer) Option {
	return func(h *Hub) {
		h.authorizer = authorizer
	}
}

func (h *Hub) canJoinRoom(playerID string, roomID string) bool {
	if h.authorizer == nil {
		return true
	}
	return h.authorizer.CanJoinRoom(context.Background(), playerID, roomID)
}
