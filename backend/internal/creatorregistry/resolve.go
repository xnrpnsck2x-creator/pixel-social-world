package creatorregistry

import (
	"encoding/json"
	"path"
	"sort"
	"strings"

	"pixel-social-world/backend/pkg/creatorcontract"
)

func (s *Service) Resolve(input creatorcontract.Manifest) ResolveResponse {
	manifest := cloneManifest(input)
	issues := make([]creatorcontract.Issue, 0)
	if manifest.SchemaVersion != creatorcontract.ManifestSchemaVersion {
		issues = appendIssue(issues, "schema_version_unsupported", "schema_version", "manifest schema version must be 2")
	}
	if manifest.RegistryRevision == "" {
		manifest.RegistryRevision = s.config.Revision
	} else if manifest.RegistryRevision != s.config.Revision {
		issues = appendIssue(issues, "registry_revision_mismatch", "registry_revision", "manifest must be resolved against the current registry revision")
	}
	if strings.TrimSpace(manifest.GameID) == "" {
		issues = appendIssue(issues, "game_id_required", "game_id", "game_id is required")
	}
	mode, modeOK := s.modes[manifest.ModeID]
	if !modeOK {
		issues = appendIssue(issues, "mode_not_found", "mode_id", "mode_id is not registered")
	} else if !mode.PublicRuntimeEnabled {
		issues = appendIssue(issues, "mode_not_public_runtime", "mode_id", "mode_id is not enabled for automatic runtime publishing")
	}
	if !s.validateVersionedRef(manifest.Interface, "interface", manifest.ModeID, &issues) {
		manifest.Interface = creatorcontract.VersionedRef{}
	} else if manifest.Interface.ID != "interface.declarative_runtime" {
		issues = appendIssue(
			issues,
			"automatic_interface_unsupported",
			"interface",
			"automatic integration requires interface.declarative_runtime",
		)
	}
	manifest.Keywords = uniqueSortedStrings(manifest.Keywords)
	for _, keywordID := range manifest.Keywords {
		entry, ok := s.entries[keywordID]
		if !ok || entry.Kind != "keyword" {
			issues = appendIssue(issues, "keyword_not_found", "keywords", "keyword is not registered: "+keywordID)
			continue
		}
		if modeOK && !supportsMode(entry.CompatibleModes, mode.ID) {
			issues = appendIssue(issues, "keyword_mode_incompatible", "keywords", "keyword is not compatible with mode: "+keywordID)
		}
	}

	capabilities := make(map[string]creatorcontract.VersionedRef)
	for _, capability := range manifest.Capabilities {
		s.resolveCapability(capability, manifest.ModeID, capabilities, &issues, map[string]bool{})
	}
	manifest.Capabilities = make([]creatorcontract.VersionedRef, 0, len(capabilities))
	permissions := make([]string, 0)
	for _, capability := range capabilities {
		manifest.Capabilities = append(manifest.Capabilities, capability)
		entry := s.entries[capability.ID]
		permissions = append(permissions, entry.Permissions...)
	}
	sort.Slice(manifest.Capabilities, func(i, j int) bool {
		return manifest.Capabilities[i].ID < manifest.Capabilities[j].ID
	})
	permissions = uniqueSortedStrings(permissions)

	if modeOK {
		allowed := make(map[string]bool, len(mode.Capabilities))
		for _, id := range mode.Capabilities {
			allowed[id] = true
		}
		for _, capability := range manifest.Capabilities {
			if !allowed[capability.ID] {
				issues = appendIssue(issues, "capability_not_allowed_by_mode", "capabilities", "capability is not allowed by mode: "+capability.ID)
			}
		}
	}

	manifest.Assets = s.resolveAssets(manifest.Assets, manifest.ModeID, &issues)
	if manifest.Entry.Type != "declarative_v1" {
		issues = appendIssue(issues, "entry_type_unsupported", "entry.type", "automatic mobile integration requires declarative_v1")
	}
	entryPath, entryPathOK := normalizeRelativeEntryPath(manifest.Entry.Path)
	if !entryPathOK {
		issues = appendIssue(issues, "entry_path_invalid", "entry.path", "entry path must be a relative JSON path")
	} else {
		manifest.Entry.Path = entryPath
	}

	resolved := creatorcontract.ResolvedManifest{
		Manifest:           manifest,
		GrantedPermissions: permissions,
	}
	if len(issues) == 0 {
		resolved.LockDigest = digestResolvedManifest(resolved)
	}
	return ResolveResponse{OK: len(issues) == 0, Resolved: resolved, Issues: issues}
}

func (s *Service) validateVersionedRef(
	ref creatorcontract.VersionedRef,
	kind string,
	modeID string,
	issues *[]creatorcontract.Issue,
) bool {
	entry, ok := s.entries[ref.ID]
	if !ok || entry.Kind != kind {
		*issues = appendIssue(*issues, kind+"_not_found", kind, kind+" is not registered: "+ref.ID)
		return false
	}
	if ref.Version != entry.Version {
		*issues = appendIssue(*issues, kind+"_version_mismatch", kind, kind+" version is not available: "+ref.ID)
		return false
	}
	if !supportsMode(entry.CompatibleModes, modeID) {
		*issues = appendIssue(*issues, kind+"_mode_incompatible", kind, kind+" is not compatible with mode: "+ref.ID)
		return false
	}
	if entry.Status == "revoked" || entry.Status == "deprecated" {
		*issues = appendIssue(*issues, kind+"_unavailable", kind, kind+" is not available: "+ref.ID)
		return false
	}
	return true
}

func (s *Service) resolveCapability(
	ref creatorcontract.VersionedRef,
	modeID string,
	resolved map[string]creatorcontract.VersionedRef,
	issues *[]creatorcontract.Issue,
	visiting map[string]bool,
) {
	if visiting[ref.ID] {
		*issues = appendIssue(*issues, "capability_dependency_cycle", "capabilities", "capability dependency cycle: "+ref.ID)
		return
	}
	if existing, ok := resolved[ref.ID]; ok {
		if existing.Version != ref.Version {
			*issues = appendIssue(*issues, "capability_version_conflict", "capabilities", "conflicting capability versions: "+ref.ID)
		} else if ref.Required && !existing.Required {
			existing.Required = true
			resolved[ref.ID] = existing
		}
		return
	}
	entry, ok := s.entries[ref.ID]
	if !ok || entry.Kind != "capability" {
		*issues = appendIssue(*issues, "capability_not_found", "capabilities", "capability is not registered: "+ref.ID)
		return
	}
	if ref.Version != entry.Version {
		*issues = appendIssue(*issues, "capability_version_mismatch", "capabilities", "capability version is not available: "+ref.ID)
		return
	}
	if !supportsMode(entry.CompatibleModes, modeID) {
		*issues = appendIssue(*issues, "capability_mode_incompatible", "capabilities", "capability is not compatible with mode: "+ref.ID)
		return
	}
	if entry.Status == "revoked" || entry.Status == "deprecated" {
		*issues = appendIssue(*issues, "capability_unavailable", "capabilities", "capability is not available: "+ref.ID)
		return
	}
	visiting[ref.ID] = true
	for _, dependencyID := range entry.Dependencies {
		dependency := s.entries[dependencyID]
		s.resolveCapability(
			creatorcontract.VersionedRef{ID: dependencyID, Version: dependency.Version, Required: true},
			modeID,
			resolved,
			issues,
			visiting,
		)
	}
	delete(visiting, ref.ID)
	resolved[ref.ID] = creatorcontract.VersionedRef{ID: ref.ID, Version: ref.Version, Required: ref.Required}
}

func (s *Service) resolveAssets(
	assets []creatorcontract.AssetRef,
	modeID string,
	issues *[]creatorcontract.Issue,
) []creatorcontract.AssetRef {
	resolved := make(map[string]creatorcontract.AssetRef)
	for _, asset := range assets {
		entry, ok := s.entries[asset.ID]
		if !ok || entry.Kind != "assetpack" {
			*issues = appendIssue(*issues, "assetpack_not_found", "assets", "asset pack is not registered: "+asset.ID)
			continue
		}
		if asset.Version != entry.Version {
			*issues = appendIssue(*issues, "assetpack_version_mismatch", "assets", "asset pack version is not available: "+asset.ID)
			continue
		}
		if !supportsMode(entry.CompatibleModes, modeID) {
			*issues = appendIssue(*issues, "assetpack_mode_incompatible", "assets", "asset pack is not compatible with mode: "+asset.ID)
			continue
		}
		if entry.Status == "revoked" || entry.Status == "deprecated" {
			*issues = appendIssue(*issues, "assetpack_unavailable", "assets", "asset pack is not available: "+asset.ID)
			continue
		}
		if entry.SHA256 == "" {
			*issues = appendIssue(*issues, "assetpack_digest_missing", "assets", "asset pack has no trusted digest: "+asset.ID)
			continue
		}
		if asset.SHA256 != "" && !strings.EqualFold(asset.SHA256, entry.SHA256) {
			*issues = appendIssue(*issues, "assetpack_digest_mismatch", "assets", "asset pack digest mismatch: "+asset.ID)
			continue
		}
		resolved[asset.ID] = creatorcontract.AssetRef{ID: asset.ID, Version: entry.Version, SHA256: entry.SHA256}
	}
	result := make([]creatorcontract.AssetRef, 0, len(resolved))
	for _, asset := range resolved {
		result = append(result, asset)
	}
	sort.Slice(result, func(i, j int) bool { return result[i].ID < result[j].ID })
	return result
}

func normalizeRelativeEntryPath(value string) (string, bool) {
	value = strings.TrimSpace(strings.ReplaceAll(value, "\\", "/"))
	if value == "" || strings.HasPrefix(value, "/") || strings.HasPrefix(value, "res://") {
		return "", false
	}
	cleaned := path.Clean(value)
	if cleaned == "." || cleaned == ".." || strings.HasPrefix(cleaned, "../") ||
		!strings.EqualFold(path.Ext(cleaned), ".json") {
		return "", false
	}
	return cleaned, true
}

func appendIssue(issues []creatorcontract.Issue, code string, field string, message string) []creatorcontract.Issue {
	return append(issues, creatorcontract.Issue{
		Code: code, Field: field, Message: message, Severity: "error",
	})
}

func digestResolvedManifest(manifest creatorcontract.ResolvedManifest) string {
	manifest.LockDigest = ""
	encoded, _ := json.Marshal(manifest)
	return digestJSON(json.RawMessage(encoded))
}

func cloneManifest(source creatorcontract.Manifest) creatorcontract.Manifest {
	source.Keywords = append([]string{}, source.Keywords...)
	source.Capabilities = append([]creatorcontract.VersionedRef{}, source.Capabilities...)
	source.Assets = append([]creatorcontract.AssetRef{}, source.Assets...)
	return source
}

func uniqueSortedStrings(values []string) []string {
	seen := make(map[string]bool, len(values))
	result := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value != "" && !seen[value] {
			seen[value] = true
			result = append(result, value)
		}
	}
	sort.Strings(result)
	return result
}
