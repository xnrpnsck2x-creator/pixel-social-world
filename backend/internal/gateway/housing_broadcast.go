package gateway

import (
	"pixel-social-world/backend/internal/house"
	"pixel-social-world/backend/internal/room"
)

const housingLayoutUpdatedMessage = "housing.layout.updated"

func (s *Server) broadcastHousingLayout(ownerID string, action string, layout house.Layout) {
	roomID := housingRoomID(ownerID)
	s.roomHub.BroadcastToRoom(roomID, room.Envelope{
		SchemaVersion: 1,
		Type:          housingLayoutUpdatedMessage,
		Payload: map[string]interface{}{
			"action":   action,
			"layout":   layout,
			"owner_id": ownerID,
			"room_id":  roomID,
			"version":  layout.Version,
		},
	})
}
