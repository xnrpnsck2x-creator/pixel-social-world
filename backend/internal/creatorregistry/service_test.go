package creatorregistry

import (
	"strings"
	"testing"

	"pixel-social-world/backend/pkg/creatorcontract"
)

func TestLoadRegistryAndDiscoverMultilingualKeyword(t *testing.T) {
	service := testRegistry(t)
	if service.Revision() != "2026-07-25.2" || service.ETag() == "" {
		t.Fatalf("unexpected registry identity: %s %s", service.Revision(), service.ETag())
	}
	if err := service.VerifyLocalAssets("../../.."); err != nil {
		t.Fatalf("registered asset digest verification failed: %v", err)
	}

	response := service.Discover(DiscoveryRequest{
		Text:   "我想做一个河边钓鱼小游戏",
		Locale: "zh-Hans",
		ModeID: "casual_activity",
	})
	if len(response.Matches) == 0 || response.Matches[0].ID != "keyword.activity.fishing" {
		t.Fatalf("fishing keyword was not discovered: %#v", response)
	}
}

func TestSearchRegistryFiltersKindAndMode(t *testing.T) {
	service := testRegistry(t)
	page := service.Search(Query{
		Kind:   "capability",
		ModeID: "2d_fighting",
		Text:   "combo",
		Limit:  10,
	})
	if page.Count != 1 || page.Items[0].ID != "cap.combat.combo_rules" {
		t.Fatalf("unexpected registry search result: %#v", page)
	}
}

func TestResolveManifestProducesStableLockForPublicRuntime(t *testing.T) {
	service := testRegistry(t)
	manifest := creatorcontract.Manifest{
		SchemaVersion:    creatorcontract.ManifestSchemaVersion,
		RegistryRevision: service.Revision(),
		GameID:           "creator_tap",
		ModeID:           "casual_activity",
		Interface: creatorcontract.VersionedRef{
			ID: "interface.declarative_runtime", Version: "1.0.0", Required: true,
		},
		Keywords: []string{"keyword.loop.tap_timing"},
		Capabilities: []creatorcontract.VersionedRef{
			{ID: "cap.timer.local", Version: "1.0.0", Required: true},
			{ID: "cap.score.submit", Version: "1.0.0"},
			{ID: "cap.emote.request", Version: "1.0.0"},
		},
		Assets: []creatorcontract.AssetRef{
			{ID: "assetpack.ui.pixel.base", Version: "1.0.0"},
		},
		Entry: creatorcontract.EntryPoint{Type: "declarative_v1", Path: "content/game.json"},
	}

	first := service.Resolve(manifest)
	second := service.Resolve(manifest)
	if !first.OK || first.Resolved.LockDigest == "" {
		t.Fatalf("manifest did not resolve: %#v", first)
	}
	if first.Resolved.LockDigest != second.Resolved.LockDigest {
		t.Fatalf("lock digest is not deterministic: %s != %s", first.Resolved.LockDigest, second.Resolved.LockDigest)
	}
	resolved := map[string]bool{}
	for _, capability := range first.Resolved.Capabilities {
		resolved[capability.ID] = true
	}
	for _, id := range []string{"cap.timer.local", "cap.score.submit", "cap.emote.request"} {
		if !resolved[id] {
			t.Fatalf("resolver omitted capability %s: %#v", id, first.Resolved.Capabilities)
		}
	}
	if first.Resolved.Assets[0].SHA256 == "" {
		t.Fatalf("resolver did not lock the trusted asset digest: %#v", first.Resolved.Assets)
	}
}

func TestResolveManifestRejectsReservedRuntimeMode(t *testing.T) {
	service := testRegistry(t)
	response := service.Resolve(creatorcontract.Manifest{
		SchemaVersion:    creatorcontract.ManifestSchemaVersion,
		RegistryRevision: service.Revision(),
		GameID:           "creator_future_duel",
		ModeID:           "2d_fighting",
		Interface: creatorcontract.VersionedRef{
			ID: "interface.declarative_runtime", Version: "1.0.0",
		},
		Entry: creatorcontract.EntryPoint{Type: "declarative_v1", Path: "content/game.json"},
	})
	for _, issue := range response.Issues {
		if issue.Code == "mode_not_public_runtime" {
			return
		}
	}
	t.Fatalf("reserved runtime mode unexpectedly resolved: %#v", response)
}

func TestResolveManifestRejectsStaleRevisionAndModeEscape(t *testing.T) {
	service := testRegistry(t)
	response := service.Resolve(creatorcontract.Manifest{
		SchemaVersion:    creatorcontract.ManifestSchemaVersion,
		RegistryRevision: "stale",
		GameID:           "creator_escape",
		ModeID:           "casual_activity",
		Interface: creatorcontract.VersionedRef{
			ID: "interface.declarative_runtime", Version: "1.0.0",
		},
		Capabilities: []creatorcontract.VersionedRef{
			{ID: "cap.survival.elimination", Version: "1.0.0"},
		},
		Entry: creatorcontract.EntryPoint{Type: "gdscript", Path: "../game.gd"},
	})
	if response.OK || len(response.Issues) < 3 || response.Resolved.LockDigest != "" {
		t.Fatalf("unsafe manifest unexpectedly resolved: %#v", response)
	}
}

func TestResolveManifestCanonicalizesEntryPath(t *testing.T) {
	service := testRegistry(t)
	response := service.Resolve(creatorcontract.Manifest{
		SchemaVersion:    creatorcontract.ManifestSchemaVersion,
		RegistryRevision: service.Revision(),
		GameID:           "canonical_entry",
		ModeID:           "casual_activity",
		Interface: creatorcontract.VersionedRef{
			ID: "interface.declarative_runtime", Version: "1.0.0",
		},
		Entry: creatorcontract.EntryPoint{
			Type: "declarative_v1",
			Path: `.\\content\\nested\\..\\game.json`,
		},
	})
	if !response.OK {
		t.Fatalf("canonical entry manifest did not resolve: %#v", response.Issues)
	}
	if response.Resolved.Entry.Path != "content/game.json" {
		t.Fatalf("entry path was not canonicalized: %q", response.Resolved.Entry.Path)
	}
}

func TestResolveManifestCapabilityOrderAndRequiredUpgradeDoNotChangeLock(t *testing.T) {
	service := testRegistry(t)
	base := creatorcontract.Manifest{
		SchemaVersion:    creatorcontract.ManifestSchemaVersion,
		RegistryRevision: service.Revision(),
		GameID:           "stable_capability_order",
		ModeID:           "casual_activity",
		Interface: creatorcontract.VersionedRef{
			ID: "interface.declarative_runtime", Version: "1.0.0",
		},
		Entry: creatorcontract.EntryPoint{Type: "declarative_v1", Path: "content/game.json"},
	}
	optionalFirst := cloneManifest(base)
	optionalFirst.Capabilities = []creatorcontract.VersionedRef{
		{ID: "cap.timer.local", Version: "1.0.0"},
		{ID: "cap.score.submit", Version: "1.0.0", Required: true},
		{ID: "cap.timer.local", Version: "1.0.0", Required: true},
	}
	requiredFirst := cloneManifest(base)
	requiredFirst.Capabilities = []creatorcontract.VersionedRef{
		{ID: "cap.timer.local", Version: "1.0.0", Required: true},
		{ID: "cap.score.submit", Version: "1.0.0", Required: true},
		{ID: "cap.timer.local", Version: "1.0.0"},
	}

	first := service.Resolve(optionalFirst)
	second := service.Resolve(requiredFirst)
	if !first.OK || !second.OK {
		t.Fatalf("capability permutations did not resolve: %#v %#v", first.Issues, second.Issues)
	}
	if first.Resolved.LockDigest != second.Resolved.LockDigest {
		t.Fatalf("capability order changed lock digest: %s != %s", first.Resolved.LockDigest, second.Resolved.LockDigest)
	}
	for _, capability := range first.Resolved.Capabilities {
		if capability.ID == "cap.timer.local" && !capability.Required {
			t.Fatal("required capability was downgraded by optional input")
		}
	}
}

func TestVerifyLocalAssetsRejectsPathOutsideProject(t *testing.T) {
	service, err := New(Config{
		SchemaVersion: 1,
		Revision:      "test",
		Entries: []RegistryEntry{
			{
				ID:          "assetpack.escape",
				Kind:        "assetpack",
				Version:     "1.0.0",
				Status:      "active",
				ResourceURI: "res://../outside.png",
				SHA256:      strings.Repeat("0", 64),
			},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	err = service.VerifyLocalAssets(t.TempDir())
	if err == nil || !strings.Contains(err.Error(), "creator_registry_asset_path_invalid") {
		t.Fatalf("outside-project asset path was not rejected: %v", err)
	}
}

func testRegistry(t *testing.T) *Service {
	t.Helper()
	service, err := Load("../../../configs/creator_registry.json")
	if err != nil {
		t.Fatalf("load creator registry: %v", err)
	}
	return service
}
