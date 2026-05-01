package ops

import (
	"context"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

type RetentionCleanupResult struct {
	Name          string `json:"name"`
	Storage       string `json:"storage"`
	RetentionDays int    `json:"retention_days"`
	CutoffUnix    int64  `json:"cutoff_unix,omitempty"`
	Matched       int64  `json:"matched"`
	Deleted       int64  `json:"deleted"`
	DryRun        bool   `json:"dry_run"`
	Skipped       bool   `json:"skipped"`
	Message       string `json:"message,omitempty"`
}

func RunPostgresRetentionCleanup(
	ctx context.Context,
	database *gorm.DB,
	policy RetentionPolicy,
	now time.Time,
	dryRun bool,
) ([]RetentionCleanupResult, error) {
	results := []RetentionCleanupResult{}
	for _, task := range BuildRetentionCleanupPlan(policy) {
		result := RetentionCleanupResult{
			Name:          task.Name,
			Storage:       task.Storage,
			RetentionDays: task.RetentionDays,
			DryRun:        dryRun,
		}
		if task.Storage != "postgres" {
			result.Skipped = true
			result.Message = "non-postgres retention is enforced by the owning storage layer"
			results = append(results, result)
			continue
		}
		if task.RetentionDays <= 0 {
			result.Skipped = true
			result.Message = "retention disabled"
			results = append(results, result)
			continue
		}
		if database == nil {
			return results, fmt.Errorf("postgres retention cleanup requires a database for %s", task.Name)
		}
		if !safeSQLIdent(task.Table) || !safeSQLIdent(task.Column) {
			return results, fmt.Errorf("unsafe retention cleanup target: %s.%s", task.Table, task.Column)
		}
		cutoff := now.UTC().AddDate(0, 0, -task.RetentionDays).Unix()
		result.CutoffUnix = cutoff
		query := fmt.Sprintf("SELECT COUNT(*) FROM %s WHERE %s < ?", task.Table, task.Column)
		if err := database.WithContext(ctx).Raw(query, cutoff).Scan(&result.Matched).Error; err != nil {
			return results, fmt.Errorf("count %s: %w", task.Name, err)
		}
		if !dryRun && result.Matched > 0 {
			deleteSQL := fmt.Sprintf("DELETE FROM %s WHERE %s < ?", task.Table, task.Column)
			exec := database.WithContext(ctx).Exec(deleteSQL, cutoff)
			if exec.Error != nil {
				return results, fmt.Errorf("delete %s: %w", task.Name, exec.Error)
			}
			result.Deleted = exec.RowsAffected
		}
		results = append(results, result)
	}
	return results, nil
}

func safeSQLIdent(value string) bool {
	if value == "" || strings.HasPrefix(value, "_") {
		return false
	}
	for _, char := range value {
		if char >= 'a' && char <= 'z' {
			continue
		}
		if char >= '0' && char <= '9' {
			continue
		}
		if char == '_' {
			continue
		}
		return false
	}
	return true
}
