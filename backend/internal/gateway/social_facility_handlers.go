package gateway

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func (s *Server) socialFacilities(ctx *gin.Context) {
	playerID, ok := s.requireSocialFacilityPlayer(ctx)
	if !ok {
		return
	}
	catalog, err := s.facilityService.Catalog(ctx.Request.Context(), playerID)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, catalog)
}

func (s *Server) socialFacility(ctx *gin.Context) {
	playerID, ok := s.requireSocialFacilityPlayer(ctx)
	if !ok {
		return
	}
	facility, err := s.facilityService.Facility(ctx.Request.Context(), playerID, ctx.Param("id"))
	if err != nil {
		ctx.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, facility)
}

func (s *Server) requireSocialFacilityPlayer(ctx *gin.Context) (string, bool) {
	playerID := ctx.Query("player_id")
	return s.requireAuthorizedPlayer(ctx, playerID)
}
