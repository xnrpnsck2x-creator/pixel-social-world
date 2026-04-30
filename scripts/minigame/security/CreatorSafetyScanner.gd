class_name CreatorSafetyScanner
extends RefCounted

const FORBIDDEN_PATTERNS := [
	"OS.",
	"FileAccess",
	"DirAccess",
	"HTTPRequest",
	"WebSocketPeer",
	"StreamPeerTCP",
	"TCPServer",
	"UDPServer",
	"PacketPeerUDP",
	"ProjectSettings",
	"ResourceSaver",
	"JavaScriptBridge",
	"DisplayServer",
	"get_tree().root",
	"get_node(\"/root",
	"get_node('/root"
]

static func scan_source(source: String) -> Array[String]:
	var errors: Array[String] = []
	for pattern in FORBIDDEN_PATTERNS:
		if source.contains(pattern):
			errors.append("Forbidden API pattern: %s" % pattern)
	return errors

static func scan_script_path(path: String) -> Array[String]:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ["Unable to read script: %s" % path]
	return scan_source(file.get_as_text())
