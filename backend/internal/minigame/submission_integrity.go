package minigame

import (
	"errors"
	"reflect"
)

func validateSubmissionReplacement(current Record, next Record) error {
	if current.GameID == "" {
		return nil
	}
	if current.GameID != next.GameID {
		return errors.New("creator_game_id_mismatch")
	}
	if current.Author != next.Author {
		return errors.New("creator_game_owned_by_another_author")
	}
	if current.Version != next.Version {
		return nil
	}
	if !reflect.DeepEqual(current.SubmitRequest, next.SubmitRequest) {
		return errors.New("creator_version_immutable")
	}
	if current.Package == nil && next.Package != nil {
		return nil
	}
	if current.Package == nil && next.Package == nil {
		return nil
	}
	if current.Package == nil || next.Package == nil ||
		current.Package.SHA256 != next.Package.SHA256 {
		return errors.New("creator_version_immutable")
	}
	return nil
}

func (s *MemoryService) validateSubmittedRecord(record Record) error {
	s.mu.RLock()
	defer s.mu.RUnlock()
	current, ok := s.records[record.GameID]
	if ok {
		if err := validateSubmissionReplacement(current, record); err != nil {
			return err
		}
	}
	versions := s.versionRecords[record.GameID]
	existing, ok := versions[submissionVersionKey(record.Version)]
	if !ok {
		return nil
	}
	return validateSubmissionReplacement(existing.Record, record)
}

func sameSubmissionTarget(current Record, next Record) bool {
	if current.GameID != next.GameID ||
		current.Author != next.Author ||
		current.Version != next.Version {
		return false
	}
	if current.Package == nil || next.Package == nil {
		return current.Package == nil && next.Package == nil
	}
	return current.Package.StorageKey == next.Package.StorageKey &&
		current.Package.SHA256 == next.Package.SHA256
}

func samePackageReviewTarget(current Record, next Record) bool {
	if !sameSubmissionTarget(current, next) ||
		current.Package == nil ||
		next.Package == nil {
		return false
	}
	nextJobID := packageReviewJobID(next.Package)
	if nextJobID == "" {
		return true
	}
	return packageReviewJobID(current.Package) == nextJobID
}

func packageReviewJobID(snapshot *PackageSnapshot) string {
	if snapshot == nil || snapshot.ReviewJob == nil {
		return ""
	}
	return snapshot.ReviewJob.ID
}

func validateReviewTransition(record Record, target string) error {
	if record.Status == target {
		return nil
	}
	switch target {
	case "review_queued":
		if record.Status != "pending_review" && record.Status != "needs_review" {
			return errors.New("invalid_review_status_transition")
		}
	case "needs_review":
		if record.Status != "pending_review" && record.Status != "review_queued" {
			return errors.New("invalid_review_status_transition")
		}
	case "approved":
		if record.Status == "submitted" || record.Status == "scanning" {
			return errors.New("package_review_not_ready")
		}
		if record.Status != "needs_review" {
			return errors.New("invalid_review_status_transition")
		}
		return validatePackageApprovalReady(record)
	case "rejected":
		switch record.Status {
		case "pending_review", "review_queued", "needs_review", "approved":
		default:
			return errors.New("invalid_review_status_transition")
		}
	default:
		return errors.New("unsupported_review_status")
	}
	return nil
}

func validatePackageApprovalReady(record Record) error {
	if record.Package == nil ||
		record.Package.ReviewJob == nil ||
		record.Package.ReviewJob.Status != "completed" {
		return errors.New("package_review_not_ready")
	}
	if len(record.Package.Report.Issues) > 0 {
		return errors.New("package_scan_issues_block_approval")
	}
	if record.Package.AIReview == nil {
		return errors.New("package_ai_review_required")
	}
	if !record.Package.AIReview.Approved {
		return errors.New("package_ai_review_blocks_approval")
	}
	return nil
}

func applyManualReviewStatus(record Record, status string) Record {
	record.Status = status
	if record.Package == nil {
		return record
	}
	record.Package.Report.Status = status
	record.Package.Report.Stages = appendUniqueStage(record.Package.Report.Stages, status)
	return record
}
