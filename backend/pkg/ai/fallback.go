package ai

import "context"

type FallbackReviewer struct {
	primary  Reviewer
	fallback Reviewer
}

func NewFallbackReviewer(primary Reviewer, fallback Reviewer) FallbackReviewer {
	if fallback == nil {
		fallback = NewLocalPolicyReviewer()
	}
	return FallbackReviewer{primary: primary, fallback: fallback}
}

func (r FallbackReviewer) ReviewMinigame(ctx context.Context, request ReviewRequest) (ReviewResult, error) {
	if r.primary == nil {
		return r.fallback.ReviewMinigame(ctx, request)
	}
	result, err := r.primary.ReviewMinigame(ctx, request)
	if err == nil {
		return result, nil
	}
	fallbackResult, fallbackErr := r.fallback.ReviewMinigame(ctx, request)
	if fallbackErr != nil {
		return ReviewResult{}, err
	}
	fallbackResult.Notes = append([]ReviewNote{{
		Code:     "llm_review_fallback",
		Severity: "warning",
		Message:  "LLM reviewer failed; local policy fallback was used.",
	}}, fallbackResult.Notes...)
	return fallbackResult, nil
}
