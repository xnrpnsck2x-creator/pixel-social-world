package gateway

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

const (
	AdminRoleViewer    = "viewer"
	AdminRoleModerator = "moderator"
	AdminRoleReviewer  = "reviewer"
	AdminRoleOwner     = "owner"
)

type adminIdentity struct {
	Role  string
	Token string
}

type adminTokenRule struct {
	Role  string
	Token string
}

func (s *Server) adminSession(ctx *gin.Context) {
	identity, ok := s.requireAdminIdentity(ctx, AdminRoleViewer)
	if !ok {
		return
	}
	ctx.JSON(http.StatusOK, gin.H{
		"role":                  identity.Role,
		"capabilities":          adminCapabilities(identity.Role),
		"confirmation_required": []string{"ban", "rollback", "unpublish"},
	})
}

func (s *Server) requireAdminRole(ctx *gin.Context, minRole string) bool {
	_, ok := s.requireAdminIdentity(ctx, minRole)
	return ok
}

func (s *Server) requireAdminIdentity(ctx *gin.Context, minRole string) (adminIdentity, bool) {
	if s.adminToken == "" {
		ctx.JSON(http.StatusForbidden, gin.H{"error": "admin_disabled"})
		return adminIdentity{}, false
	}
	identity, ok := s.matchAdminCredential(ctx)
	if !ok {
		ctx.JSON(http.StatusForbidden, gin.H{"error": "admin_forbidden"})
		return adminIdentity{}, false
	}
	if !adminRoleAllows(identity.Role, minRole) {
		ctx.JSON(http.StatusForbidden, gin.H{"error": "admin_role_forbidden", "required_role": minRole})
		return adminIdentity{}, false
	}
	return identity, true
}

func (s *Server) matchAdminCredential(ctx *gin.Context) (adminIdentity, bool) {
	token := adminCredential(ctx)
	if token == "" {
		return adminIdentity{}, false
	}
	for _, rule := range parseAdminTokenRules(s.adminToken) {
		if token == rule.Token {
			return adminIdentity{Role: rule.Role, Token: token}, true
		}
	}
	return adminIdentity{}, false
}

func (s *Server) adminRole(ctx *gin.Context) string {
	identity, ok := s.matchAdminCredential(ctx)
	if !ok {
		return ""
	}
	return identity.Role
}

func parseAdminTokenRules(spec string) []adminTokenRule {
	parts := strings.Split(spec, ",")
	rules := make([]adminTokenRule, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		role := AdminRoleOwner
		token := part
		if strings.Contains(part, ":") {
			chunks := strings.SplitN(part, ":", 2)
			if validAdminRole(chunks[0]) {
				role = chunks[0]
				token = strings.TrimSpace(chunks[1])
			}
		}
		if token != "" {
			rules = append(rules, adminTokenRule{Role: role, Token: token})
		}
	}
	return rules
}

func validAdminRole(role string) bool {
	switch role {
	case AdminRoleViewer, AdminRoleModerator, AdminRoleReviewer, AdminRoleOwner:
		return true
	default:
		return false
	}
}

func adminRoleAllows(role string, minRole string) bool {
	return adminRoleRank(role) >= adminRoleRank(minRole)
}

func adminRoleRank(role string) int {
	switch role {
	case AdminRoleOwner:
		return 4
	case AdminRoleReviewer:
		return 3
	case AdminRoleModerator:
		return 2
	case AdminRoleViewer:
		return 1
	default:
		return 0
	}
}

func adminCapabilities(role string) []string {
	all := []string{"read_ops"}
	if adminRoleAllows(role, AdminRoleModerator) {
		all = append(all, "review_chat_reports", "mute_chat", "restore_chat")
	}
	if adminRoleAllows(role, AdminRoleReviewer) {
		all = append(all, "review_creator_packages")
	}
	if adminRoleAllows(role, AdminRoleOwner) {
		all = append(all, "ban_chat", "publish_creator_packages", "rollback_creator_packages", "unpublish_creator_packages", "edit_liveops_config")
	}
	return all
}

func requireConfirmedAction(ctx *gin.Context, action string, confirmed bool) bool {
	if confirmed {
		return true
	}
	ctx.JSON(http.StatusBadRequest, gin.H{"error": "confirmation_required", "action": action})
	return false
}

func requireActionNote(ctx *gin.Context, action string, note string) bool {
	if strings.TrimSpace(note) != "" {
		return true
	}
	ctx.JSON(http.StatusBadRequest, gin.H{"error": "note_required", "action": action})
	return false
}
