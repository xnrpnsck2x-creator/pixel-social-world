package minigame

import (
	"errors"
	"regexp"
	"strings"

	"pixel-social-world/backend/pkg/creatorcontract"
)

var creatorIdentifierPattern = regexp.MustCompile(`^[a-z0-9][a-z0-9_.-]{2,63}$`)
var creatorVersionPattern = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$`)

func validatePackageSubmitRequest(request PackageSubmitRequest) error {
	if err := validateCreatorMetadataLimits(request.SubmitRequest); err != nil {
		return err
	}
	if request.ResolvedManifest == nil {
		if err := validateSubmitRequest(request.SubmitRequest); err != nil {
			return err
		}
	} else if err := validateDeclarativeSubmitRequest(request); err != nil {
		return err
	}
	return preflightPackageRequest(request)
}

func validateDeclarativeSubmitRequest(request PackageSubmitRequest) error {
	submission := request.SubmitRequest
	if submission.ModeID == "" {
		return errors.New("mode_id_required")
	}
	if submission.ModeID != "casual_activity" {
		return errors.New("declarative_mode_not_supported")
	}
	modeCap, ok := creatorModePlayerCaps[submission.ModeID]
	if !ok {
		return errors.New("unsupported_mode_id")
	}
	if submission.Name["en"] == "" || submission.Name["ja"] == "" ||
		(submission.Name["zh"] == "" && submission.Name["zh-Hans"] == "") {
		return errors.New("localized_name_required")
	}
	if submission.MinPlayers <= 0 || submission.MaxPlayers < submission.MinPlayers {
		return errors.New("invalid_player_range")
	}
	if submission.MaxPlayers > modeCap {
		return errors.New("max_players_exceeds_mode_cap")
	}
	if err := validateModeRuntimeContract(submission.ModeID, submission.RuntimeContract); err != nil {
		return err
	}
	if submission.EntryScene != "" || submission.MainScript != "" {
		return errors.New("declarative_runtime_paths_forbidden")
	}
	manifest := request.ResolvedManifest
	if manifest.SchemaVersion != creatorcontract.ManifestSchemaVersion ||
		manifest.LockDigest == "" ||
		manifest.GameID != submission.GameID ||
		manifest.ModeID != submission.ModeID {
		return errors.New("resolved_manifest_invalid")
	}
	if manifest.Interface.ID != "interface.declarative_runtime" ||
		manifest.Entry.Type != "declarative_v1" {
		return errors.New("declarative_interface_required")
	}
	return nil
}

func validateCreatorMetadataLimits(request SubmitRequest) error {
	if !creatorIdentifierPattern.MatchString(request.GameID) {
		return errors.New("game_id_invalid")
	}
	if !creatorVersionPattern.MatchString(request.Version) {
		return errors.New("version_invalid")
	}
	if len(request.Author) > 120 || len(request.ModeID) > 80 {
		return errors.New("creator_metadata_too_long")
	}
	for _, value := range request.Name {
		if len([]rune(strings.TrimSpace(value))) > 80 {
			return errors.New("localized_name_too_long")
		}
	}
	if len(request.Tags) > 12 {
		return errors.New("too_many_tags")
	}
	for _, tag := range request.Tags {
		if len([]rune(strings.TrimSpace(tag))) > 32 {
			return errors.New("tag_too_long")
		}
	}
	return nil
}
