package main

import (
	"strings"

	"pixel-social-world/backend/internal/auth"
	"pixel-social-world/backend/internal/config"
)

func authProviderVerifierFromConfig(cfg config.AuthConfig) auth.ProviderVerifier {
	switch strings.ToLower(strings.TrimSpace(cfg.ProviderVerification)) {
	case "oidc", "oidc_jwt", "strict":
		return auth.NewDefaultOIDCProviderVerifier(cfg.AppleClientIDs, cfg.GoogleClientIDs)
	default:
		return auth.NewClaimedProviderVerifier()
	}
}
