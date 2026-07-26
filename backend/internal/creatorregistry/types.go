package creatorregistry

import "pixel-social-world/backend/pkg/creatorcontract"

type Config struct {
	SchemaVersion int             `json:"schema_version"`
	Revision      string          `json:"revision"`
	DefaultLocale string          `json:"default_locale"`
	Modes         []Mode          `json:"modes"`
	Entries       []RegistryEntry `json:"entries"`
}

type Mode struct {
	ID                   string            `json:"id"`
	PublicRuntimeEnabled bool              `json:"public_runtime_enabled"`
	MinPlayers           int               `json:"min_players"`
	MaxPlayers           int               `json:"max_players"`
	RuntimeContract      map[string]string `json:"runtime_contract"`
	Capabilities         []string          `json:"capabilities"`
}

type RegistryEntry struct {
	ID              string              `json:"id"`
	Kind            string              `json:"kind"`
	Version         string              `json:"version"`
	Status          string              `json:"status"`
	Name            map[string]string   `json:"name"`
	Aliases         map[string][]string `json:"aliases,omitempty"`
	CompatibleModes []string            `json:"compatible_modes,omitempty"`
	Dependencies    []string            `json:"dependencies,omitempty"`
	Permissions     []string            `json:"permissions,omitempty"`
	ResourceURI     string              `json:"resource_uri,omitempty"`
	SHA256          string              `json:"sha256,omitempty"`
	MinClient       string              `json:"min_client_version,omitempty"`
	ReplacementID   string              `json:"replacement_id,omitempty"`
}

type Query struct {
	Kind   string
	ModeID string
	Locale string
	Text   string
	Cursor int
	Limit  int
}

type Page struct {
	Revision   string          `json:"revision"`
	Items      []RegistryEntry `json:"items"`
	Count      int             `json:"count"`
	NextCursor string          `json:"next_cursor,omitempty"`
}

type DiscoveryRequest struct {
	Text   string `json:"text"`
	Locale string `json:"locale"`
	ModeID string `json:"mode_id,omitempty"`
	Limit  int    `json:"limit,omitempty"`
}

type DiscoveryMatch struct {
	ID      string `json:"id"`
	Kind    string `json:"kind"`
	Version string `json:"version"`
	Name    string `json:"name"`
	Score   int    `json:"score"`
}

type DiscoveryResponse struct {
	Revision string           `json:"revision"`
	Matches  []DiscoveryMatch `json:"matches"`
}

type ResolveResponse struct {
	OK       bool                             `json:"ok"`
	Resolved creatorcontract.ResolvedManifest `json:"resolved_manifest"`
	Issues   []creatorcontract.Issue          `json:"issues"`
}
