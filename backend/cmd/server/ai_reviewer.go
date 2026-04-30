package main

import (
	"strings"
	"time"

	"pixel-social-world/backend/internal/config"
	"pixel-social-world/backend/internal/minigame"
	"pixel-social-world/backend/pkg/ai"
)

func packageReviewerFromConfig(cfg config.AIReviewConfig) minigame.PackageAIReviewer {
	switch strings.ToLower(strings.TrimSpace(cfg.Mode)) {
	case "openai_compatible", "lmstudio":
		timeout := time.Duration(cfg.TimeoutSeconds) * time.Second
		reviewer := ai.NewOpenAICompatibleReviewer(ai.OpenAICompatibleConfig{
			BaseURL: cfg.BaseURL,
			Model:   cfg.Model,
			APIKey:  cfg.APIKey,
			Timeout: timeout,
		})
		fallback := ai.NewFallbackReviewer(reviewer, ai.NewLocalPolicyReviewer())
		return minigame.NewPackageAIReviewAdapter("openai_compatible:"+cfg.Model, fallback)
	default:
		return minigame.NewDefaultPackageAIReviewer()
	}
}
