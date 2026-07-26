package creatorregistry

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
)

func Load(path string) (*Service, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var config Config
	if err := json.Unmarshal(raw, &config); err != nil {
		return nil, err
	}
	return New(config)
}

func New(config Config) (*Service, error) {
	if config.SchemaVersion != 1 {
		return nil, errors.New("creator_registry_schema_unsupported")
	}
	config.Revision = strings.TrimSpace(config.Revision)
	if config.Revision == "" {
		return nil, errors.New("creator_registry_revision_required")
	}
	if config.DefaultLocale == "" {
		config.DefaultLocale = "en"
	}
	service := &Service{
		config:  config,
		entries: make(map[string]RegistryEntry, len(config.Entries)),
		modes:   make(map[string]Mode, len(config.Modes)),
	}
	for _, mode := range config.Modes {
		if err := validateMode(mode); err != nil {
			return nil, err
		}
		if _, exists := service.modes[mode.ID]; exists {
			return nil, errors.New("creator_registry_duplicate_mode:" + mode.ID)
		}
		service.modes[mode.ID] = cloneMode(mode)
	}
	for _, entry := range config.Entries {
		if err := validateEntry(entry); err != nil {
			return nil, err
		}
		if _, exists := service.entries[entry.ID]; exists {
			return nil, errors.New("creator_registry_duplicate_entry:" + entry.ID)
		}
		service.entries[entry.ID] = cloneEntry(entry)
	}
	if err := service.validateReferences(); err != nil {
		return nil, err
	}
	service.etag = `"` + digestJSON(config) + `"`
	return service, nil
}

func NewEmpty() *Service {
	service, _ := New(Config{
		SchemaVersion: 1,
		Revision:      "empty",
		DefaultLocale: "en",
		Modes:         []Mode{},
		Entries:       []RegistryEntry{},
	})
	return service
}

func (s *Service) VerifyLocalAssets(projectRoot string) error {
	for _, entry := range s.entries {
		if entry.Kind != "assetpack" || !strings.HasPrefix(entry.ResourceURI, "res://") {
			continue
		}
		if !validSHA256(entry.SHA256) {
			return errors.New("creator_registry_asset_digest_invalid:" + entry.ID)
		}
		relative := strings.TrimPrefix(entry.ResourceURI, "res://")
		assetPath, err := containedAssetPath(projectRoot, relative)
		if err != nil {
			return errors.New("creator_registry_asset_path_invalid:" + entry.ID)
		}
		raw, err := os.ReadFile(assetPath)
		if err != nil {
			return errors.New("creator_registry_asset_missing:" + entry.ID)
		}
		digest := sha256.Sum256(raw)
		if !strings.EqualFold(entry.SHA256, hex.EncodeToString(digest[:])) {
			return errors.New("creator_registry_asset_digest_mismatch:" + entry.ID)
		}
	}
	return nil
}

func containedAssetPath(projectRoot string, relative string) (string, error) {
	root, err := filepath.Abs(projectRoot)
	if err != nil {
		return "", err
	}
	candidate, err := filepath.Abs(filepath.Join(root, filepath.FromSlash(relative)))
	if err != nil {
		return "", err
	}
	withinRoot, err := filepath.Rel(root, candidate)
	if err != nil ||
		withinRoot == ".." ||
		strings.HasPrefix(withinRoot, ".."+string(filepath.Separator)) {
		return "", errors.New("asset_path_outside_project")
	}
	return candidate, nil
}

func ProjectRootForRegistryPath(registryPath string) string {
	return filepath.Dir(filepath.Dir(filepath.Clean(registryPath)))
}

func validSHA256(value string) bool {
	if len(value) != sha256.Size*2 {
		return false
	}
	_, err := hex.DecodeString(value)
	return err == nil
}

func validateMode(mode Mode) error {
	if strings.TrimSpace(mode.ID) == "" {
		return errors.New("creator_registry_mode_id_required")
	}
	if mode.MinPlayers <= 0 || mode.MaxPlayers < mode.MinPlayers {
		return errors.New("creator_registry_invalid_player_range:" + mode.ID)
	}
	return nil
}

func validateEntry(entry RegistryEntry) error {
	if strings.TrimSpace(entry.ID) == "" || strings.TrimSpace(entry.Kind) == "" {
		return errors.New("creator_registry_entry_identity_required")
	}
	if entry.Version == "" {
		return errors.New("creator_registry_entry_version_required:" + entry.ID)
	}
	switch entry.Kind {
	case "keyword", "capability", "assetpack", "interface":
	default:
		return errors.New("creator_registry_entry_kind_invalid:" + entry.ID)
	}
	return nil
}
