package gateway

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/minigame"
)

func (s *Server) publishedMinigameRuntime(ctx *gin.Context) {
	runtime, err := s.minigameService.PublishedRuntime(
		ctx.Request.Context(),
		ctx.Param("id"),
	)
	if err != nil {
		if errors.Is(err, minigame.ErrPackageNotPublished) ||
			err.Error() == "package_not_published" {
			ctx.JSON(http.StatusNotFound, gin.H{"error": "not_found"})
			return
		}
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "runtime_unavailable"})
		return
	}
	ctx.Header("ETag", `"`+runtime.SourceSHA256+`"`)
	ctx.Header("Cache-Control", "public, max-age=30, must-revalidate")
	ctx.JSON(http.StatusOK, runtime)
}
