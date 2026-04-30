package chat

import "gorm.io/gorm"

func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(&MessageRecord{}, &ReportRecord{}, &ModerationActionRecord{})
}
