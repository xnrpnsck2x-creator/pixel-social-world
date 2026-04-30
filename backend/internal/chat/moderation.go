package chat

import (
	"context"
	"errors"
	"fmt"
	"time"
)

const ModerationActionMute = "mute"
const ModerationActionBan = "ban"
const ModerationActionRestore = "restore"
const ModerationScopeRoom = "room"
const ModerationScopeGlobal = "global"
const defaultMuteDurationSeconds = 3600
const maxModerationReasonLength = 160

type ModerationAction struct {
	ID               string `json:"id"`
	TargetPlayerID   string `json:"target_player_id"`
	TargetName       string `json:"target_name,omitempty"`
	Action           string `json:"action"`
	Scope            string `json:"scope"`
	RoomID           string `json:"room_id,omitempty"`
	Reason           string `json:"reason,omitempty"`
	ReportID         string `json:"report_id,omitempty"`
	ModeratorID      string `json:"moderator_id"`
	Source           string `json:"source"`
	RequestID        string `json:"request_id,omitempty"`
	CreatedAt        int64  `json:"created_at"`
	ExpiresAt        int64  `json:"expires_at,omitempty"`
	RevokedAt        int64  `json:"revoked_at,omitempty"`
	RevokedBy        string `json:"revoked_by,omitempty"`
	RevocationReason string `json:"revocation_reason,omitempty"`
}

type ModerationActionRequest struct {
	TargetPlayerID  string `json:"target_player_id"`
	TargetName      string `json:"target_name"`
	Action          string `json:"action"`
	Scope           string `json:"scope"`
	RoomID          string `json:"room_id"`
	DurationSeconds int    `json:"duration_seconds"`
	Reason          string `json:"reason"`
	ReportID        string `json:"report_id"`
	ModeratorID     string `json:"moderator_id"`
	Source          string `json:"source"`
	RequestID       string `json:"request_id"`
}

type ModerationListRequest struct {
	TargetPlayerID string `json:"target_player_id"`
	Action         string `json:"action"`
	Limit          int    `json:"limit"`
	Offset         int    `json:"offset"`
}

type ModerationSnapshot struct {
	GeneratedAt int64              `json:"generated_at"`
	Active      []ModerationAction `json:"active"`
	Recent      []ModerationAction `json:"recent"`
	Limit       int                `json:"limit,omitempty"`
	Offset      int                `json:"offset,omitempty"`
}

func normalizeModerationRequest(request ModerationActionRequest) (ModerationActionRequest, error) {
	request.Action = normalize(request.Action, ModerationActionMute)
	if request.Action != ModerationActionMute && request.Action != ModerationActionBan && request.Action != ModerationActionRestore {
		return request, errors.New("invalid_moderation_action")
	}
	if request.TargetPlayerID == "" {
		return request, errors.New("target_player_required")
	}
	request.Scope = normalize(request.Scope, ModerationScopeRoom)
	if request.Scope != ModerationScopeRoom && request.Scope != ModerationScopeGlobal {
		return request, errors.New("invalid_moderation_scope")
	}
	if request.Scope == ModerationScopeRoom {
		request.RoomID = normalize(request.RoomID, defaultRoomID)
	} else {
		request.RoomID = ""
	}
	request.Reason = truncateRunes(normalize(request.Reason, request.Action), maxModerationReasonLength)
	request.ModeratorID = normalize(request.ModeratorID, "admin:unknown")
	request.Source = normalize(request.Source, "admin-api")
	if request.Action == ModerationActionMute && request.DurationSeconds <= 0 {
		request.DurationSeconds = defaultMuteDurationSeconds
	}
	return request, nil
}

func moderationActionFromRequest(request ModerationActionRequest, now int64, nextIndex int) ModerationAction {
	action := ModerationAction{
		ID:             fmt.Sprintf("mod-%d-%06d", now, nextIndex),
		TargetPlayerID: request.TargetPlayerID,
		TargetName:     request.TargetName,
		Action:         request.Action,
		Scope:          request.Scope,
		RoomID:         request.RoomID,
		Reason:         request.Reason,
		ReportID:       request.ReportID,
		ModeratorID:    request.ModeratorID,
		Source:         request.Source,
		RequestID:      request.RequestID,
		CreatedAt:      now,
	}
	if request.Action == ModerationActionMute {
		action.ExpiresAt = now + int64(request.DurationSeconds)
	}
	return action
}

func moderationListLimit(limit int) int {
	if limit <= 0 || limit > 100 {
		return 50
	}
	return limit
}

func restrictionError(action string) error {
	if action == ModerationActionBan {
		return errors.New("chat_banned")
	}
	return errors.New("chat_muted")
}

func nowUnix() int64 {
	return time.Now().Unix()
}

func activeModeration(action ModerationAction, roomID string, now int64) bool {
	if action.Action != ModerationActionMute && action.Action != ModerationActionBan {
		return false
	}
	if action.RevokedAt > 0 || (action.ExpiresAt > 0 && action.ExpiresAt <= now) {
		return false
	}
	return action.Scope == ModerationScopeGlobal || action.RoomID == roomID
}

func (s *MemoryService) activeRestriction(_ context.Context, playerID string, roomID string) (ModerationAction, bool) {
	now := nowUnix()
	for index := len(s.moderationActions) - 1; index >= 0; index-- {
		action := s.moderationActions[index]
		if action.TargetPlayerID == playerID && activeModeration(action, roomID, now) {
			return action, true
		}
	}
	return ModerationAction{}, false
}
