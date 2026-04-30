package auth

import (
	"context"
	"errors"
	"strings"
)

type ProviderIdentity struct {
	Subject     string
	Email       string
	DisplayName string
}

type ProviderVerifier interface {
	VerifyProviderIdentity(ctx context.Context, request UpgradeGuestRequest) (ProviderIdentity, error)
}

type ClaimedProviderVerifier struct{}

func NewClaimedProviderVerifier() ProviderVerifier {
	return ClaimedProviderVerifier{}
}

func (ClaimedProviderVerifier) VerifyProviderIdentity(
	_ context.Context,
	request UpgradeGuestRequest,
) (ProviderIdentity, error) {
	subject := strings.TrimSpace(request.ProviderSubject)
	if subject == "" {
		return ProviderIdentity{}, errors.New("provider_subject_required")
	}
	if strings.TrimSpace(request.IdentityToken) == "" &&
		strings.TrimSpace(request.AuthorizationCode) == "" {
		return ProviderIdentity{}, errors.New("missing_identity_proof")
	}
	return ProviderIdentity{
		Subject:     subject,
		Email:       strings.TrimSpace(request.Email),
		DisplayName: strings.TrimSpace(request.DisplayName),
	}, nil
}

func verifyUpgradeRequest(
	ctx context.Context,
	verifier ProviderVerifier,
	request UpgradeGuestRequest,
) (UpgradeGuestRequest, error) {
	normalized, err := normalizeUpgradeShape(request)
	if err != nil {
		return normalized, err
	}
	if verifier == nil {
		verifier = NewClaimedProviderVerifier()
	}
	identity, err := verifier.VerifyProviderIdentity(ctx, normalized)
	if err != nil {
		return normalized, err
	}
	identity.Subject = strings.TrimSpace(identity.Subject)
	if identity.Subject == "" {
		return normalized, errors.New("provider_subject_required")
	}
	if normalized.ProviderSubject != "" && normalized.ProviderSubject != identity.Subject {
		return normalized, errors.New("provider_subject_mismatch")
	}
	normalized.ProviderSubject = identity.Subject
	if strings.TrimSpace(identity.Email) != "" {
		normalized.Email = strings.TrimSpace(identity.Email)
	}
	if strings.TrimSpace(identity.DisplayName) != "" {
		normalized.DisplayName = strings.TrimSpace(identity.DisplayName)
	}
	return normalized, nil
}
