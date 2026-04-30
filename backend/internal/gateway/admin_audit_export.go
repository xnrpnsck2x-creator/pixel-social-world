package gateway

import (
	"bytes"
	"encoding/csv"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/chat"
	"pixel-social-world/backend/internal/minigame"
)

func wantsCSV(ctx *gin.Context) bool {
	return ctx.Query("format") == "csv"
}

func writeAdminCSV(ctx *gin.Context, filename string, rows [][]string) {
	var buffer bytes.Buffer
	writer := csv.NewWriter(&buffer)
	_ = writer.WriteAll(rows)
	ctx.Header("Content-Type", "text/csv; charset=utf-8")
	ctx.Header("Content-Disposition", `attachment; filename="`+filename+`"`)
	ctx.String(http.StatusOK, buffer.String())
}

func reviewAuditCSVRows(snapshot minigame.ReviewAuditSnapshot) [][]string {
	rows := [][]string{{"game_id", "id", "action", "status", "reviewer", "source", "note", "request_id", "created_unix"}}
	for _, item := range snapshot.Items {
		rows = append(rows, []string{
			item.GameID,
			item.ID,
			item.Action,
			item.Status,
			item.Reviewer,
			item.Source,
			item.Note,
			item.RequestID,
			strconv.FormatInt(item.CreatedUnix, 10),
		})
	}
	return rows
}

func moderationCSVRows(snapshot chat.ModerationSnapshot) [][]string {
	rows := [][]string{{
		"section", "id", "target_player_id", "target_name", "action", "scope", "room_id",
		"reason", "report_id", "moderator_id", "source", "request_id", "created_at", "expires_at",
		"revoked_at", "revoked_by", "revocation_reason",
	}}
	rows = appendModerationRows(rows, "active", snapshot.Active)
	return appendModerationRows(rows, "recent", snapshot.Recent)
}

func appendModerationRows(rows [][]string, section string, items []chat.ModerationAction) [][]string {
	for _, item := range items {
		rows = append(rows, []string{
			section,
			item.ID,
			item.TargetPlayerID,
			item.TargetName,
			item.Action,
			item.Scope,
			item.RoomID,
			item.Reason,
			item.ReportID,
			item.ModeratorID,
			item.Source,
			item.RequestID,
			strconv.FormatInt(item.CreatedAt, 10),
			strconv.FormatInt(item.ExpiresAt, 10),
			strconv.FormatInt(item.RevokedAt, 10),
			item.RevokedBy,
			item.RevocationReason,
		})
	}
	return rows
}
