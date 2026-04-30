package ai

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"
)

func TestLocalPolicyReviewerGoldenSet(t *testing.T) {
	failures := EvaluateGoldenSet(
		context.Background(),
		NewLocalPolicyReviewer(),
		DefaultReviewerGoldenSet(),
	)
	if len(failures) > 0 {
		t.Fatalf("golden set failed: %#v", failures)
	}
}

func TestOpenAICompatibleReviewerGoldenSet(t *testing.T) {
	if os.Getenv("PSW_RUN_LLM_GOLDEN") != "1" {
		t.Skip("set PSW_RUN_LLM_GOLDEN=1 to run the live LLM golden set")
	}
	model := os.Getenv("PSW_AI_REVIEWER_MODEL")
	if model == "" {
		model = "qwen/qwen3-coder-next"
	}
	baseURL := os.Getenv("PSW_AI_REVIEWER_BASE_URL")
	if baseURL == "" {
		baseURL = "http://127.0.0.1:1234/v1"
	}
	timeout := 60 * time.Second
	reviewer := NewOpenAICompatibleReviewer(OpenAICompatibleConfig{
		BaseURL: baseURL,
		Model:   model,
		APIKey:  os.Getenv("PSW_AI_REVIEWER_API_KEY"),
		Timeout: timeout,
	})
	ctx, cancel := context.WithTimeout(context.Background(), timeout*time.Duration(len(DefaultReviewerGoldenSet())))
	defer cancel()
	failures := EvaluateGoldenSet(ctx, reviewer, DefaultReviewerGoldenSet())
	if len(failures) > 0 {
		t.Fatalf("live LLM golden set failed:\n%s", formatGoldenFailures(failures))
	}
}

func formatGoldenFailures(failures []GoldenFailure) string {
	lines := make([]string, 0, len(failures))
	for _, failure := range failures {
		lines = append(lines, failure.CaseID+": "+failure.Message)
	}
	return strings.Join(lines, "\n")
}
