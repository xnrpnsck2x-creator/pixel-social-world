package auth

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"sync"
	"time"
)

type OIDCProviderSettings struct {
	Issuer    string
	JWKSURL   string
	Audiences []string
}

type OIDCProviderVerifier struct {
	client    *http.Client
	providers map[string]OIDCProviderSettings
	mu        sync.Mutex
	keys      map[string]jwkSet
}

type jwkSet struct {
	Keys     []jwk `json:"keys"`
	Fetched  time.Time
	CacheTTL time.Duration
}

type jwk struct {
	Kty string `json:"kty"`
	Kid string `json:"kid"`
	Alg string `json:"alg"`
	Use string `json:"use"`
	N   string `json:"n"`
	E   string `json:"e"`
	Crv string `json:"crv"`
	X   string `json:"x"`
	Y   string `json:"y"`
}

type jwtHeader struct {
	Alg string `json:"alg"`
	Kid string `json:"kid"`
}

type jwtClaims struct {
	Issuer  string          `json:"iss"`
	Subject string          `json:"sub"`
	Aud     json.RawMessage `json:"aud"`
	Email   string          `json:"email"`
	Name    string          `json:"name"`
	Exp     int64           `json:"exp"`
	Iat     int64           `json:"iat"`
}

func NewOIDCProviderVerifier(providers map[string]OIDCProviderSettings) *OIDCProviderVerifier {
	return &OIDCProviderVerifier{
		client:    &http.Client{Timeout: 5 * time.Second},
		providers: providers,
		keys:      map[string]jwkSet{},
	}
}

func NewDefaultOIDCProviderVerifier(
	appleAudiences []string,
	googleAudiences []string,
) *OIDCProviderVerifier {
	return NewOIDCProviderVerifier(map[string]OIDCProviderSettings{
		"apple": {
			Issuer:    "https://appleid.apple.com",
			JWKSURL:   "https://appleid.apple.com/auth/keys",
			Audiences: appleAudiences,
		},
		"google": {
			Issuer:    "https://accounts.google.com",
			JWKSURL:   "https://www.googleapis.com/oauth2/v3/certs",
			Audiences: googleAudiences,
		},
	})
}

func (v *OIDCProviderVerifier) VerifyProviderIdentity(
	ctx context.Context,
	request UpgradeGuestRequest,
) (ProviderIdentity, error) {
	token := strings.TrimSpace(request.IdentityToken)
	if token == "" {
		return ProviderIdentity{}, errors.New("identity_token_required")
	}
	settings, ok := v.providers[request.Provider]
	if !ok {
		return ProviderIdentity{}, errors.New("unsupported_provider")
	}
	if len(settings.Audiences) == 0 {
		return ProviderIdentity{}, errors.New("provider_audience_not_configured")
	}
	header, claims, signingInput, signature, err := parseJWT(token)
	if err != nil {
		return ProviderIdentity{}, err
	}
	if err := validateOIDCClaims(claims, settings); err != nil {
		return ProviderIdentity{}, err
	}
	if err := v.verifySignature(ctx, settings.JWKSURL, header, signingInput, signature); err != nil {
		return ProviderIdentity{}, err
	}
	return ProviderIdentity{
		Subject:     claims.Subject,
		Email:       claims.Email,
		DisplayName: claims.Name,
	}, nil
}

func parseJWT(token string) (jwtHeader, jwtClaims, []byte, []byte, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return jwtHeader{}, jwtClaims{}, nil, nil, errors.New("invalid_identity_token")
	}
	var header jwtHeader
	if err := decodeJWTPart(parts[0], &header); err != nil {
		return jwtHeader{}, jwtClaims{}, nil, nil, errors.New("invalid_identity_header")
	}
	var claims jwtClaims
	if err := decodeJWTPart(parts[1], &claims); err != nil {
		return jwtHeader{}, jwtClaims{}, nil, nil, errors.New("invalid_identity_claims")
	}
	signature, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return jwtHeader{}, jwtClaims{}, nil, nil, errors.New("invalid_identity_signature")
	}
	return header, claims, []byte(parts[0] + "." + parts[1]), signature, nil
}

func decodeJWTPart(part string, target any) error {
	decoded, err := base64.RawURLEncoding.DecodeString(part)
	if err != nil {
		return err
	}
	return json.Unmarshal(decoded, target)
}

func validateOIDCClaims(claims jwtClaims, settings OIDCProviderSettings) error {
	if claims.Issuer != settings.Issuer {
		return errors.New("provider_issuer_mismatch")
	}
	if strings.TrimSpace(claims.Subject) == "" {
		return errors.New("provider_subject_required")
	}
	now := time.Now().Unix()
	if claims.Exp <= now {
		return errors.New("identity_token_expired")
	}
	if claims.Iat > now+300 {
		return errors.New("identity_token_from_future")
	}
	if !audienceAllowed(claimAudiences(claims.Aud), settings.Audiences) {
		return errors.New("provider_audience_mismatch")
	}
	return nil
}

func claimAudiences(raw json.RawMessage) []string {
	var single string
	if json.Unmarshal(raw, &single) == nil && single != "" {
		return []string{single}
	}
	var many []string
	if json.Unmarshal(raw, &many) == nil {
		return many
	}
	return nil
}

func audienceAllowed(claimed []string, allowed []string) bool {
	for _, claim := range claimed {
		for _, allow := range allowed {
			if claim == allow {
				return true
			}
		}
	}
	return false
}

func (v *OIDCProviderVerifier) verifySignature(
	ctx context.Context,
	jwksURL string,
	header jwtHeader,
	signingInput []byte,
	signature []byte,
) error {
	keys, err := v.loadKeys(ctx, jwksURL)
	if err != nil {
		return err
	}
	for _, key := range keys.Keys {
		if key.Kid != header.Kid || key.Alg != header.Alg {
			continue
		}
		if verifyJWKSignature(key, header.Alg, signingInput, signature) == nil {
			return nil
		}
	}
	return errors.New("identity_signature_untrusted")
}

func (v *OIDCProviderVerifier) loadKeys(ctx context.Context, jwksURL string) (jwkSet, error) {
	v.mu.Lock()
	cached, ok := v.keys[jwksURL]
	if ok && time.Since(cached.Fetched) < cached.CacheTTL {
		v.mu.Unlock()
		return cached, nil
	}
	v.mu.Unlock()

	request, err := http.NewRequestWithContext(ctx, http.MethodGet, jwksURL, nil)
	if err != nil {
		return jwkSet{}, err
	}
	response, err := v.client.Do(request)
	if err != nil {
		return jwkSet{}, err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return jwkSet{}, errors.New("provider_keys_unavailable")
	}
	var loaded jwkSet
	if err := json.NewDecoder(response.Body).Decode(&loaded); err != nil {
		return jwkSet{}, err
	}
	loaded.Fetched = time.Now()
	loaded.CacheTTL = time.Hour
	v.mu.Lock()
	v.keys[jwksURL] = loaded
	v.mu.Unlock()
	return loaded, nil
}
