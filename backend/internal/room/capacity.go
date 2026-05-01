package room

import "strings"

type RoomCapacityPolicy struct {
	MainCity int
	Housing  int
	Minigame int
	Custom   int
}

type joinReservation struct {
	accepted       bool
	limit          int
	current        int
	oldRoomID      string
	oldPlayerID    string
	oldDisplayName string
	shouldLeave    bool
}

func DefaultRoomCapacityPolicy() RoomCapacityPolicy {
	return RoomCapacityPolicy{
		MainCity: 100,
		Housing:  20,
		Minigame: 16,
		Custom:   50,
	}
}

func WithRoomCapacityPolicy(policy RoomCapacityPolicy) Option {
	return func(h *Hub) {
		h.roomCapacityPolicy = normalizedRoomCapacityPolicy(policy)
	}
}

func normalizedRoomCapacityPolicy(policy RoomCapacityPolicy) RoomCapacityPolicy {
	defaults := DefaultRoomCapacityPolicy()
	if policy.MainCity <= 0 {
		policy.MainCity = defaults.MainCity
	}
	if policy.Housing <= 0 {
		policy.Housing = defaults.Housing
	}
	if policy.Minigame <= 0 {
		policy.Minigame = defaults.Minigame
	}
	if policy.Custom <= 0 {
		policy.Custom = defaults.Custom
	}
	return policy
}

func (h *Hub) reserveJoin(client *clientState, playerID string, displayName string, roomID string) joinReservation {
	h.mu.Lock()
	defer h.mu.Unlock()

	limit := h.roomCapacityLimit(roomID)
	current := h.joinedClientCountLocked(roomID, client)
	if limit > 0 && current >= limit {
		return joinReservation{accepted: false, limit: limit, current: current}
	}

	reservation := joinReservation{
		accepted:       true,
		limit:          limit,
		current:        current + 1,
		oldRoomID:      client.roomID,
		oldPlayerID:    client.playerID,
		oldDisplayName: client.displayName,
	}
	reservation.shouldLeave = client.playerID != "" && (client.roomID != roomID || client.playerID != playerID)
	client.roomID = roomID
	client.playerID = playerID
	client.displayName = displayName
	return reservation
}

func (h *Hub) joinedClientCountLocked(roomID string, excluded *clientState) int {
	count := 0
	for _, client := range h.clients {
		if client == excluded || client.playerID == "" {
			continue
		}
		if client.roomID == roomID {
			count++
		}
	}
	return count
}

func (h *Hub) roomCapacityLimit(roomID string) int {
	switch {
	case roomID == "" || roomID == defaultRoomID:
		return h.roomCapacityPolicy.MainCity
	case strings.HasPrefix(roomID, "home:"):
		return h.roomCapacityPolicy.Housing
	case strings.HasPrefix(roomID, "minigame:"):
		return h.roomCapacityPolicy.Minigame
	default:
		return h.roomCapacityPolicy.Custom
	}
}
