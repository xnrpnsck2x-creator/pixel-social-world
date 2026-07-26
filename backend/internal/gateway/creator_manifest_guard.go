package gateway

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/minigame"
	"pixel-social-world/backend/pkg/creatorcontract"
)

func (s *Server) validateResolvedCreatorManifest(
	ctx *gin.Context,
	request *minigame.PackageSubmitRequest,
) bool {
	if request.ResolvedManifest == nil {
		ctx.JSON(http.StatusUnprocessableEntity, gin.H{"error": "creator_manifest_required"})
		return false
	}
	if s.creatorRegistry == nil {
		ctx.JSON(http.StatusServiceUnavailable, gin.H{"error": "creator_registry_unavailable"})
		return false
	}
	if request.ResolvedManifest.GameID != request.GameID ||
		request.ResolvedManifest.ModeID != request.ModeID {
		ctx.JSON(http.StatusUnprocessableEntity, gin.H{"error": "creator_manifest_submission_mismatch"})
		return false
	}
	resolved := s.creatorRegistry.Resolve(request.ResolvedManifest.Manifest)
	if !resolved.OK {
		ctx.JSON(http.StatusUnprocessableEntity, gin.H{
			"error":  "creator_manifest_invalid",
			"issues": resolved.Issues,
		})
		return false
	}
	if request.ResolvedManifest.LockDigest == "" ||
		request.ResolvedManifest.LockDigest != resolved.Resolved.LockDigest {
		ctx.JSON(http.StatusUnprocessableEntity, gin.H{"error": "creator_manifest_lock_mismatch"})
		return false
	}
	request.ResolvedManifest = creatorcontract.CloneResolvedManifest(&resolved.Resolved)
	return true
}
