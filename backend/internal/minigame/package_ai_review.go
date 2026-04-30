package minigame

import (
	"context"
	"time"

	"pixel-social-world/backend/pkg/ai"
)

type PackageAIReviewer interface {
	ReviewPackage(
		ctx context.Context,
		request PackageSubmitRequest,
		report PackageScanReport,
	) (PackageAIReviewReport, error)
}

type PackageAIReviewReport struct {
	Status     string                `json:"status"`
	Approved   bool                  `json:"approved"`
	Reviewer   string                `json:"reviewer"`
	RiskLevel  string                `json:"risk_level,omitempty"`
	ReviewedAt int64                 `json:"reviewed_at"`
	Notes      []PackageAIReviewNote `json:"notes"`
}

type PackageAIReviewNote struct {
	Code     string `json:"code"`
	Severity string `json:"severity"`
	Message  string `json:"message"`
	Path     string `json:"path,omitempty"`
}

type PackageAIReviewAdapter struct {
	reviewer ai.Reviewer
	name     string
}

func NewDefaultPackageAIReviewer() PackageAIReviewer {
	return NewPackageAIReviewAdapter("local_policy_v1", ai.NewLocalPolicyReviewer())
}

func NewPackageAIReviewAdapter(name string, reviewer ai.Reviewer) PackageAIReviewer {
	if reviewer == nil {
		reviewer = ai.NewLocalPolicyReviewer()
	}
	if name == "" {
		name = "local_policy_v1"
	}
	return PackageAIReviewAdapter{reviewer: reviewer, name: name}
}

func (r PackageAIReviewAdapter) ReviewPackage(
	ctx context.Context,
	request PackageSubmitRequest,
	report PackageScanReport,
) (PackageAIReviewReport, error) {
	result, err := r.reviewer.ReviewMinigame(ctx, ai.ReviewRequest{
		GameID:          request.GameID,
		Version:         request.Version,
		Author:          request.Author,
		ModeID:          request.ModeID,
		Tags:            append([]string{}, request.Tags...),
		RequiresNetwork: request.RequiresNetwork,
		RuntimeContract: cloneAnyMap(request.RuntimeContract),
		Files:           reviewFilesFromPackage(request.Files),
		ScanIssues:      append([]string{}, report.Issues...),
	})
	if err != nil {
		return PackageAIReviewReport{}, err
	}
	status := "approved"
	if !result.Approved {
		status = "rejected"
	}
	return PackageAIReviewReport{
		Status:     status,
		Approved:   result.Approved,
		Reviewer:   r.name,
		RiskLevel:  result.RiskLevel,
		ReviewedAt: time.Now().Unix(),
		Notes:      reviewNotesFromAI(result.Notes),
	}, nil
}

func reviewFilesFromPackage(files []PackageFile) []ai.ReviewFile {
	result := make([]ai.ReviewFile, 0, len(files))
	for _, file := range files {
		result = append(result, ai.ReviewFile{
			Path:        file.Path,
			SizeBytes:   file.SizeBytes,
			ContentText: file.ContentText,
		})
	}
	return result
}

func reviewNotesFromAI(notes []ai.ReviewNote) []PackageAIReviewNote {
	result := make([]PackageAIReviewNote, 0, len(notes))
	for _, note := range notes {
		result = append(result, PackageAIReviewNote{
			Code:     note.Code,
			Severity: note.Severity,
			Message:  note.Message,
			Path:     note.Path,
		})
	}
	return result
}

func applyAIReviewResult(record Record, review PackageAIReviewReport) Record {
	if record.Package == nil {
		return record
	}
	record.Package.AIReview = &review
	record.Package.Report.Stages = appendUniqueStage(record.Package.Report.Stages, "ai_review")
	if review.Approved {
		return record
	}
	record.Status = "rejected"
	record.Package.Report.Status = "rejected"
	record.Package.Report.Issues = append(record.Package.Report.Issues, "ai_review_rejected")
	record.Package.Report.Stages = appendUniqueStage(record.Package.Report.Stages, "rejected")
	return record
}

func appendUniqueStage(stages []string, stage string) []string {
	for _, existing := range stages {
		if existing == stage {
			return stages
		}
	}
	return append(stages, stage)
}
