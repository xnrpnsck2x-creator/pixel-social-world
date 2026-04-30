package minigame

import (
	"context"
	"errors"
	"fmt"
	"time"
)

func (s *MemoryService) CreateSession(_ context.Context, request CreateSessionRequest) (Session, error) {
	if request.GameID == "" {
		return Session{}, errors.New("game_id_required")
	}
	request.RoomID = normalize(request.RoomID, "world_town_square")
	request.HostPlayerID = normalize(request.HostPlayerID, "offline-player")

	now := time.Now().Unix()
	s.mu.Lock()
	defer s.mu.Unlock()
	if request.MaxPlayers <= 0 {
		request.MaxPlayers = s.maxPlayersForGameLocked(request.GameID)
	}
	status := "waiting"
	if request.MaxPlayers <= 1 {
		status = "active"
	}
	s.sessionSequence++
	session := Session{
		ID:           fmt.Sprintf("session_%06d", s.sessionSequence),
		GameID:       request.GameID,
		RoomID:       request.RoomID,
		HostPlayerID: request.HostPlayerID,
		Status:       status,
		Players:      []string{request.HostPlayerID},
		MaxPlayers:   request.MaxPlayers,
		Version:      1,
		CreatedAt:    now,
		UpdatedAt:    now,
		ExpiresAt:    sessionExpiry(now),
	}
	s.sessions[session.ID] = cloneSession(session)
	return session, nil
}

func (s *MemoryService) JoinSession(_ context.Context, request JoinSessionRequest) (Session, error) {
	request.PlayerID = normalize(request.PlayerID, "offline-player")
	s.mu.Lock()
	defer s.mu.Unlock()
	session, ok := s.sessions[request.SessionID]
	if !ok {
		return Session{}, errors.New("session_not_found")
	}
	if session.Status == "ended" {
		return Session{}, errors.New("session_ended")
	}
	if containsPlayer(session.Players, request.PlayerID) {
		return cloneSession(session), nil
	}
	if len(session.Players) >= session.MaxPlayers {
		return Session{}, errors.New("session_full")
	}
	session.Players = append(session.Players, request.PlayerID)
	if len(session.Players) >= session.MaxPlayers {
		session.Status = "active"
	}
	session.Version++
	session.UpdatedAt = time.Now().Unix()
	session.ExpiresAt = sessionExpiry(session.UpdatedAt)
	s.sessions[request.SessionID] = cloneSession(session)
	return cloneSession(session), nil
}

func (s *MemoryService) LeaveSession(_ context.Context, request LeaveSessionRequest) (Session, error) {
	request.PlayerID = normalize(request.PlayerID, "offline-player")
	s.mu.Lock()
	defer s.mu.Unlock()
	session, ok := s.sessions[request.SessionID]
	if !ok {
		return Session{}, errors.New("session_not_found")
	}
	session.Players = removePlayer(session.Players, request.PlayerID)
	if len(session.Players) == 0 {
		session.Status = "ended"
	} else if session.HostPlayerID == request.PlayerID {
		session.HostPlayerID = session.Players[0]
	}
	session.Version++
	session.UpdatedAt = time.Now().Unix()
	session.ExpiresAt = sessionExpiry(session.UpdatedAt)
	s.sessions[request.SessionID] = cloneSession(session)
	return cloneSession(session), nil
}

func (s *MemoryService) EndSession(_ context.Context, sessionID string) (Session, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	session, ok := s.sessions[sessionID]
	if !ok {
		return Session{}, errors.New("session_not_found")
	}
	session.Status = "ended"
	session.Version++
	session.UpdatedAt = time.Now().Unix()
	session.ExpiresAt = sessionExpiry(session.UpdatedAt)
	s.sessions[sessionID] = cloneSession(session)
	return cloneSession(session), nil
}

func (s *MemoryService) GetSession(_ context.Context, sessionID string) (Session, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	session, ok := s.sessions[sessionID]
	if !ok || session.Status == "ended" || sessionExpired(session, time.Now().Unix()) {
		delete(s.sessions, sessionID)
		return Session{}, false
	}
	return cloneSession(session), true
}

func (s *MemoryService) ListSessions(_ context.Context, roomID string) []Session {
	roomID = normalize(roomID, "world_town_square")
	s.mu.Lock()
	defer s.mu.Unlock()
	sessions := []Session{}
	now := time.Now().Unix()
	for _, session := range s.sessions {
		if sessionExpired(session, now) {
			delete(s.sessions, session.ID)
			continue
		}
		if session.RoomID == roomID && session.Status != "ended" {
			sessions = append(sessions, cloneSession(session))
		}
	}
	return sessions
}

func (s *MemoryService) maxPlayersForGameLocked(gameID string) int {
	record, ok := s.records[gameID]
	if ok && record.MaxPlayers > 0 {
		return record.MaxPlayers
	}
	return 4
}

func (s *MemoryService) maxPlayersForGame(gameID string) int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.maxPlayersForGameLocked(gameID)
}

func cloneSession(session Session) Session {
	players := make([]string, len(session.Players))
	copy(players, session.Players)
	session.Players = players
	return session
}

func containsPlayer(players []string, playerID string) bool {
	for _, id := range players {
		if id == playerID {
			return true
		}
	}
	return false
}

func removePlayer(players []string, playerID string) []string {
	remaining := []string{}
	for _, id := range players {
		if id != playerID {
			remaining = append(remaining, id)
		}
	}
	return remaining
}

func normalize(value string, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}
