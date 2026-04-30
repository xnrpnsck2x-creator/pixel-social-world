package minigame

import "gorm.io/gorm"

func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(
		&SubmissionRecord{},
		&SubmissionVersionRecord{},
		&PackageReviewJobRecord{},
		&ReviewAuditRecord{},
	)
}
