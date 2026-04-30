package ai

import (
	"context"
	"strings"
)

type ReviewFile struct {
	Path        string
	SizeBytes   int64
	ContentText string
}

type ReviewRequest struct {
	GameID          string
	Version         string
	Author          string
	ModeID          string
	Tags            []string
	RequiresNetwork bool
	RuntimeContract map[string]any
	Files           []ReviewFile
	ScanIssues      []string
}

type ReviewNote struct {
	Code     string `json:"code"`
	Severity string `json:"severity"`
	Message  string `json:"message"`
	Path     string `json:"path,omitempty"`
}

type ReviewResult struct {
	Approved  bool         `json:"approved"`
	RiskLevel string       `json:"risk_level,omitempty"`
	Notes     []ReviewNote `json:"notes"`
}

type Reviewer interface {
	ReviewMinigame(ctx context.Context, request ReviewRequest) (ReviewResult, error)
}

type LocalPolicyReviewer struct{}

func NewLocalPolicyReviewer() LocalPolicyReviewer {
	return LocalPolicyReviewer{}
}

func (LocalPolicyReviewer) ReviewMinigame(_ context.Context, request ReviewRequest) (ReviewResult, error) {
	result := ReviewResult{Approved: true}
	if len(request.ScanIssues) > 0 {
		result.Approved = false
		result.Notes = append(result.Notes, ReviewNote{
			Code:     "scan_issues_present",
			Severity: "blocker",
			Message:  "Package has unresolved safety scanner issues.",
		})
		return result, nil
	}
	if request.RequiresNetwork {
		result.Notes = append(result.Notes, ReviewNote{
			Code:     "network_contract_review",
			Severity: "warning",
			Message:  "Networked creator games require manual multiplayer contract review.",
		})
	}
	for _, file := range request.Files {
		for _, pattern := range localPolicyBlockedContentPatterns {
			if strings.Contains(strings.ToLower(file.ContentText), pattern) {
				result.Approved = false
				result.Notes = append(result.Notes, ReviewNote{
					Code:     "blocked_content_pattern",
					Severity: "blocker",
					Message:  "Package text contains content that must be reviewed before intake.",
					Path:     file.Path,
				})
			}
		}
	}
	if result.Approved && len(result.Notes) == 0 {
		result.Notes = append(result.Notes, ReviewNote{
			Code:     "policy_review_passed",
			Severity: "info",
			Message:  "Package passed the local AI review policy adapter.",
		})
	}
	return result, nil
}

var localPolicyBlockedContentPatterns = []string{
	"http://",
	"https://",
	"api_key",
	"password",
	"secret",
	"token",
}
