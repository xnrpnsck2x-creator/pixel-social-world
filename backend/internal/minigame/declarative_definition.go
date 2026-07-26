package minigame

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
)

const maxDeclarativeDefinitionBytes = 256 * 1024
const maxDeclarativeDefinitionDepth = 12
const maxDeclarativeDefinitionNodes = 2048

type declarativeDefinitionHeader struct {
	SchemaVersion int    `json:"schema_version"`
	GameID        string `json:"game_id"`
	ModeID        string `json:"mode_id"`
	Type          string `json:"type"`
}

func validateDeclarativeDefinition(
	request PackageSubmitRequest,
	file PackageFile,
) error {
	content, ok, err := packageFileContentBytes(file)
	if err != nil {
		return err
	}
	if !ok || len(content) == 0 {
		return errors.New("declarative_entry_content_required")
	}
	if len(content) > maxDeclarativeDefinitionBytes {
		return errors.New("declarative_entry_too_large")
	}

	decoder := json.NewDecoder(bytes.NewReader(content))
	decoder.UseNumber()
	var document any
	if err := decoder.Decode(&document); err != nil {
		return errors.New("declarative_entry_invalid_json")
	}
	var trailing any
	if err := decoder.Decode(&trailing); !errors.Is(err, io.EOF) {
		return errors.New("declarative_entry_multiple_documents")
	}
	root, ok := document.(map[string]any)
	if !ok {
		return errors.New("declarative_entry_object_required")
	}
	nodes, depth := declarativeShape(root, 1)
	if nodes > maxDeclarativeDefinitionNodes {
		return errors.New("declarative_entry_too_complex")
	}
	if depth > maxDeclarativeDefinitionDepth {
		return errors.New("declarative_entry_too_deep")
	}

	var header declarativeDefinitionHeader
	if err := json.Unmarshal(content, &header); err != nil {
		return errors.New("declarative_entry_invalid_header")
	}
	if header.SchemaVersion != 1 {
		return errors.New("declarative_entry_schema_unsupported")
	}
	if header.GameID != request.GameID {
		return errors.New("declarative_entry_game_id_mismatch")
	}
	if header.ModeID != request.ModeID {
		return errors.New("declarative_entry_mode_id_mismatch")
	}
	if header.ModeID != "casual_activity" || header.Type != "tap_timing" {
		return errors.New("declarative_entry_runtime_unsupported")
	}
	return nil
}

func declarativeShape(value any, depth int) (int, int) {
	nodes := 1
	maxDepth := depth
	switch typed := value.(type) {
	case map[string]any:
		for _, child := range typed {
			childNodes, childDepth := declarativeShape(child, depth+1)
			nodes += childNodes
			if childDepth > maxDepth {
				maxDepth = childDepth
			}
		}
	case []any:
		for _, child := range typed {
			childNodes, childDepth := declarativeShape(child, depth+1)
			nodes += childNodes
			if childDepth > maxDepth {
				maxDepth = childDepth
			}
		}
	}
	return nodes, maxDepth
}

func declarativeEntryIssue(request PackageSubmitRequest, file PackageFile) string {
	if err := validateDeclarativeDefinition(request, file); err != nil {
		return fmt.Sprintf("%s:%s", err.Error(), file.Path)
	}
	return ""
}
