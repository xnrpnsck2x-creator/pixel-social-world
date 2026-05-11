class_name PanelTextTheme
extends RefCounted

const PRIMARY := Color(0.24, 0.16, 0.09, 1.0)
const MUTED := Color(0.42, 0.32, 0.22, 1.0)

static func apply_primary(labels: Array) -> void:
	_apply(labels, PRIMARY)

static func apply_muted(labels: Array) -> void:
	_apply(labels, MUTED)

static func apply_pair(primary_labels: Array, muted_labels: Array) -> void:
	apply_primary(primary_labels)
	apply_muted(muted_labels)

static func row_color(font_size: int, primary_min_size: int = 12) -> Color:
	return PRIMARY if font_size >= primary_min_size else MUTED

static func _apply(labels: Array, color: Color) -> void:
	for label in labels:
		if label is Label:
			(label as Label).modulate = color
