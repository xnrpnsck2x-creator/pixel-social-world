package creatorcontract

const ManifestSchemaVersion = 2

type VersionedRef struct {
	ID       string `json:"id"`
	Version  string `json:"version"`
	Required bool   `json:"required,omitempty"`
}

type AssetRef struct {
	ID      string `json:"id"`
	Version string `json:"version"`
	SHA256  string `json:"sha256,omitempty"`
}

type EntryPoint struct {
	Type string `json:"type"`
	Path string `json:"path"`
}

type Manifest struct {
	SchemaVersion    int            `json:"schema_version"`
	RegistryRevision string         `json:"registry_revision"`
	GameID           string         `json:"game_id"`
	ModeID           string         `json:"mode_id"`
	Interface        VersionedRef   `json:"interface"`
	Keywords         []string       `json:"keywords"`
	Capabilities     []VersionedRef `json:"capabilities"`
	Assets           []AssetRef     `json:"assets,omitempty"`
	Entry            EntryPoint     `json:"entry"`
}

type ResolvedManifest struct {
	Manifest
	GrantedPermissions []string `json:"granted_permissions"`
	LockDigest         string   `json:"lock_digest"`
}

type Issue struct {
	Code     string `json:"code"`
	Field    string `json:"field,omitempty"`
	Message  string `json:"message"`
	Severity string `json:"severity"`
}

func CloneResolvedManifest(source *ResolvedManifest) *ResolvedManifest {
	if source == nil {
		return nil
	}
	cloned := *source
	if source.Keywords != nil {
		cloned.Keywords = append([]string{}, source.Keywords...)
	}
	if source.Capabilities != nil {
		cloned.Capabilities = append([]VersionedRef{}, source.Capabilities...)
	}
	if source.Assets != nil {
		cloned.Assets = append([]AssetRef{}, source.Assets...)
	}
	if source.GrantedPermissions != nil {
		cloned.GrantedPermissions = append([]string{}, source.GrantedPermissions...)
	}
	return &cloned
}
