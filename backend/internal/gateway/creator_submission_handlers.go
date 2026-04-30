package gateway

import (
	"io"
	"net/http"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/minigame"
)

func (s *Server) submitCreatorDraft(ctx *gin.Context) {
	var request minigame.SubmitRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.Author)
	if !ok {
		return
	}
	request.Author = playerID
	record, err := s.minigameService.Submit(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusAccepted, record)
}

func (s *Server) submitCreatorPackage(ctx *gin.Context) {
	var request minigame.PackageSubmitRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.Author)
	if !ok {
		return
	}
	request.Author = playerID
	record, err := s.minigameService.SubmitPackageAsync(ctx.Request.Context(), request)
	if err != nil {
		status := http.StatusBadRequest
		if record.GameID != "" {
			status = http.StatusUnprocessableEntity
		}
		ctx.JSON(status, gin.H{"error": err.Error(), "record": record})
		return
	}
	ctx.JSON(http.StatusAccepted, record)
}

func (s *Server) submitCreatorPackageZip(ctx *gin.Context) {
	ctx.Request.Body = http.MaxBytesReader(
		ctx.Writer,
		ctx.Request.Body,
		int64(minigame.MaxCreatorPackageArchiveBytes+1024*1024),
	)
	author := ctx.PostForm("author")
	if author == "" {
		author = ctx.Query("player_id")
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, author)
	if !ok {
		return
	}
	file, _, err := ctx.Request.FormFile("package")
	if err != nil {
		file, _, err = ctx.Request.FormFile("file")
	}
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "package_file_required"})
		return
	}
	defer file.Close()
	archive, err := io.ReadAll(io.LimitReader(file, int64(minigame.MaxCreatorPackageArchiveBytes+1)))
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "package_read_failed"})
		return
	}
	if len(archive) > minigame.MaxCreatorPackageArchiveBytes {
		ctx.JSON(http.StatusRequestEntityTooLarge, gin.H{"error": "package_archive_too_large"})
		return
	}
	request, err := minigame.PackageSubmitRequestFromZip(playerID, archive)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	record, err := s.minigameService.SubmitPackageAsync(ctx.Request.Context(), request)
	if err != nil {
		status := http.StatusBadRequest
		if record.GameID != "" {
			status = http.StatusUnprocessableEntity
		}
		ctx.JSON(status, gin.H{"error": err.Error(), "record": record})
		return
	}
	ctx.JSON(http.StatusAccepted, record)
}

func (s *Server) creatorSubmissionStatus(ctx *gin.Context) {
	playerID, ok := s.requireAuthorizedPlayer(ctx, ctx.Query("player_id"))
	if !ok {
		return
	}
	record, found := s.minigameService.Get(ctx.Request.Context(), ctx.Param("id"))
	if !found {
		ctx.JSON(http.StatusNotFound, gin.H{"error": "not_found"})
		return
	}
	if record.Author != playerID {
		ctx.JSON(http.StatusForbidden, gin.H{"error": "creator_submission_forbidden"})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{
		"game_id": record.GameID,
		"mode_id": record.ModeID,
		"version": record.Version,
		"status":  record.Status,
		"package": record.Package,
	})
}
