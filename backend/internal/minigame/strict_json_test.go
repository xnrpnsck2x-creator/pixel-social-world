package minigame

import (
	"testing"

	"pixel-social-world/backend/pkg/creatorcontract"
)

func TestStrictJSONRejectsUnknownCreatorManifestFields(t *testing.T) {
	var manifest creatorcontract.ResolvedManifest
	err := decodeStrictJSON(
		[]byte(`{"schema_version":2,"unexpected_permissions":["filesystem"]}`),
		&manifest,
	)
	if err == nil {
		t.Fatal("creator manifest accepted an unknown field")
	}
}
