package minigame

func recordWithPublishedInstall(record Record, install PackageInstallSnapshot) Record {
	record.Status = "published"
	if record.Package == nil {
		return record
	}
	install.Status = "installed"
	record.Package.Install = &install
	record.Package.Report.Status = "published"
	record.Package.Report.Stages = appendUniqueStage(record.Package.Report.Stages, "published")
	return record
}

func recordWithInactiveInstall(
	record Record,
	install PackageInstallSnapshot,
	stage string,
) Record {
	if record.Status == "published" {
		record.Status = "approved"
	}
	if record.Package == nil {
		return record
	}
	install.Status = stage
	record.Package.Install = &install
	record.Package.Report.Status = record.Status
	record.Package.Report.Stages = appendUniqueStage(record.Package.Report.Stages, stage)
	return record
}

func installMatchesRecord(install PackageInstallSnapshot, record Record) bool {
	return record.GameID == install.GameID &&
		record.Version == install.Version &&
		record.Author == install.Author &&
		record.Package != nil &&
		record.Package.StorageKey == install.SourceStorageKey &&
		record.Package.SHA256 == install.SourceSHA256
}
