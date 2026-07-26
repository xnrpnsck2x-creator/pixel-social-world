package minigame

import (
	"context"
	"encoding/json"
	"errors"

	"pixel-social-world/backend/pkg/creatorcontract"
)

var ErrPackageNotPublished = errors.New("package_not_published")

type PublishedRuntimeSnapshot struct {
	SchemaVersion   int                              `json:"schema_version"`
	GameID          string                           `json:"game_id"`
	Version         string                           `json:"version"`
	Author          string                           `json:"author"`
	ModeID          string                           `json:"mode_id"`
	Name            map[string]string                `json:"name"`
	MinPlayers      int                              `json:"min_players"`
	MaxPlayers      int                              `json:"max_players"`
	RequiresNetwork bool                             `json:"requires_network"`
	RuntimeContract map[string]any                   `json:"runtime_contract"`
	Manifest        creatorcontract.ResolvedManifest `json:"manifest"`
	Definition      json.RawMessage                  `json:"definition"`
	SourceSHA256    string                           `json:"source_sha256"`
	PublishedAt     int64                            `json:"published_at"`
}

type PublishedCatalogItem struct {
	Status          string            `json:"status"`
	GameID          string            `json:"game_id"`
	Version         string            `json:"version"`
	Author          string            `json:"author"`
	ModeID          string            `json:"mode_id"`
	Name            map[string]string `json:"name"`
	MinPlayers      int               `json:"min_players"`
	MaxPlayers      int               `json:"max_players"`
	Tags            []string          `json:"tags"`
	RequiresNetwork bool              `json:"requires_network"`
	RuntimeContract map[string]any    `json:"runtime_contract"`
	SourceSHA256    string            `json:"source_sha256"`
	PublishedAt     int64             `json:"published_at"`
}

func PublicCatalogItem(install PackageInstallSnapshot) PublishedCatalogItem {
	return PublishedCatalogItem{
		Status:          install.Status,
		GameID:          install.GameID,
		Version:         install.Version,
		Author:          install.Author,
		ModeID:          install.ModeID,
		Name:            cloneStringMap(install.Name),
		MinPlayers:      install.MinPlayers,
		MaxPlayers:      install.MaxPlayers,
		Tags:            append([]string{}, install.Tags...),
		RequiresNetwork: install.RequiresNetwork,
		RuntimeContract: cloneAnyMap(install.RuntimeContract),
		SourceSHA256:    install.SourceSHA256,
		PublishedAt:     install.PublishedAt,
	}
}

func (s *MemoryService) PublishedRuntime(
	ctx context.Context,
	id string,
) (PublishedRuntimeSnapshot, error) {
	return loadPublishedRuntime(ctx, id, s.installStore, s.artifactStore)
}

func (s *GormSubmissionService) PublishedRuntime(
	ctx context.Context,
	id string,
) (PublishedRuntimeSnapshot, error) {
	return loadPublishedRuntime(ctx, id, s.installStore, s.artifactStore)
}

func loadPublishedRuntime(
	ctx context.Context,
	id string,
	installStore PackageInstallStore,
	artifactStore PackageArtifactStore,
) (PublishedRuntimeSnapshot, error) {
	if installStore == nil || artifactStore == nil {
		return PublishedRuntimeSnapshot{}, errors.New("runtime_store_unavailable")
	}
	install, ok, err := installStore.CurrentPackage(ctx, id)
	if err != nil {
		return PublishedRuntimeSnapshot{}, err
	}
	if !ok || install.Status != "installed" {
		return PublishedRuntimeSnapshot{}, ErrPackageNotPublished
	}
	request, err := artifactStore.LoadPackage(ctx, install.SourceStorageKey)
	if err != nil {
		return PublishedRuntimeSnapshot{}, err
	}
	if request.ResolvedManifest == nil ||
		request.ResolvedManifest.Interface.ID != "interface.declarative_runtime" ||
		request.ResolvedManifest.Entry.Type != "declarative_v1" {
		return PublishedRuntimeSnapshot{}, errors.New("published_runtime_unsupported")
	}
	if request.GameID != install.GameID || request.Version != install.Version {
		return PublishedRuntimeSnapshot{}, errors.New("published_runtime_identity_mismatch")
	}
	digest, _ := packageDigestAndBytes(request.Files)
	if digest != install.SourceSHA256 {
		return PublishedRuntimeSnapshot{}, errors.New("published_runtime_digest_mismatch")
	}
	entry := packageFileByPath(request.Files, request.ResolvedManifest.Entry.Path)
	if err := validateDeclarativeDefinition(request, entry); err != nil {
		return PublishedRuntimeSnapshot{}, err
	}
	content, ok, err := packageFileContentBytes(entry)
	if err != nil {
		return PublishedRuntimeSnapshot{}, err
	}
	if !ok {
		return PublishedRuntimeSnapshot{}, errors.New("published_runtime_definition_missing")
	}
	return PublishedRuntimeSnapshot{
		SchemaVersion:   1,
		GameID:          install.GameID,
		Version:         install.Version,
		Author:          install.Author,
		ModeID:          install.ModeID,
		Name:            cloneStringMap(install.Name),
		MinPlayers:      install.MinPlayers,
		MaxPlayers:      install.MaxPlayers,
		RequiresNetwork: install.RequiresNetwork,
		RuntimeContract: cloneAnyMap(install.RuntimeContract),
		Manifest:        *creatorcontract.CloneResolvedManifest(request.ResolvedManifest),
		Definition:      append(json.RawMessage{}, content...),
		SourceSHA256:    install.SourceSHA256,
		PublishedAt:     install.PublishedAt,
	}, nil
}
