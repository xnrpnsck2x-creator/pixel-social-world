package gateway

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/creatorregistry"
	"pixel-social-world/backend/internal/minigame"
	"pixel-social-world/backend/pkg/creatorcontract"
)

type creatorDiscoveryRequest struct {
	PlayerID string `json:"player_id"`
	creatorregistry.DiscoveryRequest
}

type creatorResolveRequest struct {
	PlayerID string                   `json:"player_id"`
	Manifest creatorcontract.Manifest `json:"manifest"`
}

func (s *Server) creatorRegistryIndex(ctx *gin.Context) {
	if !s.requireCreatorRegistry(ctx) {
		return
	}
	if match := ctx.GetHeader("If-None-Match"); match != "" && match == s.creatorRegistry.ETag() {
		ctx.Status(http.StatusNotModified)
		return
	}
	cursor, _ := strconv.Atoi(ctx.Query("cursor"))
	limit, _ := strconv.Atoi(ctx.Query("limit"))
	page := s.creatorRegistry.Search(creatorregistry.Query{
		Kind:   strings.TrimSpace(ctx.Query("kind")),
		ModeID: strings.TrimSpace(ctx.Query("mode_id")),
		Locale: strings.TrimSpace(ctx.Query("locale")),
		Text:   strings.TrimSpace(ctx.Query("q")),
		Cursor: cursor,
		Limit:  limit,
	})
	ctx.Header("ETag", s.creatorRegistry.ETag())
	ctx.Header("Cache-Control", "public, max-age=60, must-revalidate")
	ctx.JSON(http.StatusOK, page)
}

func (s *Server) creatorRegistryEntry(ctx *gin.Context) {
	if !s.requireCreatorRegistry(ctx) {
		return
	}
	entry, ok := s.creatorRegistry.Get(ctx.Param("id"))
	if !ok {
		ctx.JSON(http.StatusNotFound, gin.H{"error": "registry_entry_not_found"})
		return
	}
	ctx.Header("ETag", s.creatorRegistry.ETag())
	ctx.JSON(http.StatusOK, gin.H{"revision": s.creatorRegistry.Revision(), "entry": entry})
}

func (s *Server) discoverCreatorKeywords(ctx *gin.Context) {
	if !s.requireCreatorRegistry(ctx) {
		return
	}
	var request creatorDiscoveryRequest
	if !bindCreatorJSON(ctx, &request, minigame.MaxCreatorDraftJSONBytes) {
		return
	}
	if _, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID); !ok {
		return
	}
	if strings.TrimSpace(request.Text) == "" {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "discovery_text_required"})
		return
	}
	ctx.JSON(http.StatusOK, s.creatorRegistry.Discover(request.DiscoveryRequest))
}

func (s *Server) resolveCreatorManifest(ctx *gin.Context) {
	if !s.requireCreatorRegistry(ctx) {
		return
	}
	var request creatorResolveRequest
	if !bindCreatorJSON(ctx, &request, minigame.MaxCreatorDraftJSONBytes) {
		return
	}
	if _, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID); !ok {
		return
	}
	response := s.creatorRegistry.Resolve(request.Manifest)
	status := http.StatusOK
	if !response.OK {
		status = http.StatusUnprocessableEntity
	}
	ctx.JSON(status, response)
}

func (s *Server) requireCreatorRegistry(ctx *gin.Context) bool {
	if s.creatorRegistry != nil {
		return true
	}
	ctx.JSON(http.StatusServiceUnavailable, gin.H{"error": "creator_registry_unavailable"})
	return false
}
