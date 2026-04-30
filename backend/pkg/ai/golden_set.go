package ai

import (
	"context"
	"fmt"
)

type GoldenCase struct {
	ID             string
	Description    string
	Request        ReviewRequest
	ExpectApproved bool
}

type GoldenFailure struct {
	CaseID  string
	Message string
	Result  ReviewResult
}

func DefaultReviewerGoldenSet() []GoldenCase {
	cases := []GoldenCase{}
	for _, mode := range goldenModes {
		cases = append(cases, GoldenCase{
			ID:             "allow_" + mode.ID,
			Description:    "safe creator package for " + mode.ID,
			Request:        goldenModeRequest(mode),
			ExpectApproved: true,
		})
	}
	return append(cases, GoldenCase{
		ID:             "block_external_url",
		Description:    "creator script contains an external URL",
		Request:        goldenBadTextRequest("const SUPPORT_URL = \"https://example.test\"\n"),
		ExpectApproved: false,
	}, GoldenCase{
		ID:             "block_api_key",
		Description:    "creator script contains a secret-like API key name",
		Request:        goldenBadTextRequest("const API_KEY = \"abc123\"\n"),
		ExpectApproved: false,
	}, GoldenCase{
		ID:             "block_token",
		Description:    "creator script contains token-like text",
		Request:        goldenBadTextRequest("var auth_token := \"abc123\"\n"),
		ExpectApproved: false,
	}, GoldenCase{
		ID:             "block_scanner_file_access",
		Description:    "scanner found a forbidden filesystem API",
		Request:        goldenScanIssueRequest("forbidden_script_pattern:FileAccess"),
		ExpectApproved: false,
	}, GoldenCase{
		ID:             "block_scanner_root_access",
		Description:    "scanner found root-node access outside the sandbox",
		Request:        goldenScanIssueRequest("forbidden_script_pattern:get_tree().root"),
		ExpectApproved: false,
	})
}

func EvaluateGoldenSet(
	ctx context.Context,
	reviewer Reviewer,
	cases []GoldenCase,
) []GoldenFailure {
	failures := []GoldenFailure{}
	for _, testCase := range cases {
		result, err := reviewer.ReviewMinigame(ctx, testCase.Request)
		if err != nil {
			failures = append(failures, GoldenFailure{
				CaseID:  testCase.ID,
				Message: err.Error(),
			})
			continue
		}
		if result.Approved != testCase.ExpectApproved {
			failures = append(failures, GoldenFailure{
				CaseID: testCase.ID,
				Message: fmt.Sprintf(
					"expected approved=%t, got approved=%t",
					testCase.ExpectApproved,
					result.Approved,
				),
				Result: result,
			})
			continue
		}
		if !testCase.ExpectApproved && !hasBlocker(result.Notes) {
			failures = append(failures, GoldenFailure{
				CaseID:  testCase.ID,
				Message: "blocked case did not include a blocker note",
				Result:  result,
			})
		}
	}
	return failures
}

func hasBlocker(notes []ReviewNote) bool {
	for _, note := range notes {
		if note.Severity == "blocker" {
			return true
		}
	}
	return false
}
