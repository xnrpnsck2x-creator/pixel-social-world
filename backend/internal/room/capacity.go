package room

import (
	"context"
	"strings"
)

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
	superseded     *clientState
	errorCode      string
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
	h.sessionFenceMu.Lock()
	defer h.sessionFenceMu.Unlock()
	h.mu.Lock()

	limit := h.roomCapacityLimit(roomID)
	current := h.joinedClientCountLocked(roomID, playerID)
	if limit > 0 && current >= limit {
		h.mu.Unlock()
		return joinReservation{accepted: false, limit: limit, current: current}
	}

	previous := client.snapshot()
	active := h.activePlayers[playerID]
	reservation := joinReservation{
		accepted:       true,
		limit:          limit,
		current:        current + 1,
		oldRoomID:      previous.roomID,
		oldPlayerID:    previous.playerID,
		oldDisplayName: previous.displayName,
	}
	if active.client != nil && active.client != client {
		activeState := active.client.snapshot()
		reservation.superseded = active.client
		if activeState.roomID != roomID {
			reservation.oldRoomID = activeState.roomID
			reservation.oldPlayerID = activeState.playerID
			reservation.oldDisplayName = activeState.displayName
			reservation.shouldLeave = activeState.playerID != ""
		}
	}
	if previous.playerID != "" && (previous.roomID != roomID || previous.playerID != playerID) {
		reservation.shouldLeave = true
	}

	if previous.playerID != "" && previous.playerID != playerID {
		if old := h.activePlayers[previous.playerID]; old.client == client && old.generation == previous.generation {
			delete(h.activePlayers, previous.playerID)
		}
	}
	h.nextGeneration++
	generation := h.nextGeneration
	sessionToken := newSessionToken(generation)
	h.mu.Unlock()

	if h.sessionLease != nil {
		if err := h.sessionLease.Claim(
			context.Background(),
			playerID,
			sessionToken,
			h.sessionLeaseTTL(),
		); err != nil {
			return joinReservation{accepted: false, errorCode: "session_lease_unavailable"}
		}
	}

	h.mu.Lock()
	client.setSession(roomID, playerID, displayName, generation, sessionToken)
	h.activePlayers[playerID] = activePlayerSession{client: client, generation: generation}
	h.mu.Unlock()
	return reservation
}

func (h *Hub) joinedClientCountLocked(roomID string, excludedPlayerID string) int {
	count := 0
	for playerID, session := range h.activePlayers {
		if playerID == excludedPlayerID {
			continue
		}
		state := session.client.snapshot()
		if state.playerID == playerID && state.generation == session.generation && state.roomID == roomID {
			count++
		}
	}
	return count
}

func (h *Hub) joinedClientCount(roomID string) int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return h.joinedClientCountLocked(roomID, "")
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
