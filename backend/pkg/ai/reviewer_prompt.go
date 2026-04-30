package ai

import "encoding/json"

const reviewerSystemPrompt = `You are a safety reviewer for player-created Godot 4 GDScript minigames.
Return only one JSON object with this shape:
{"approved":true,"risk_level":"low","notes":[{"code":"...","severity":"info|warning|blocker","message":"...","path":""}]}

Reject packages that try to use OS, filesystem APIs, direct networking APIs inside scripts, root-node access, secrets, tokens, external URLs, native binaries, or hidden monetization.
Do not reject only because requires_network is true. requires_network is allowed metadata when the runtime_contract declares a platform-managed network_profile.
The platform scanner already blocks direct HTTPRequest, WebSocketPeer, StreamPeerTCP, UDP, and TCPServer usage in creator scripts.
Approve only when the package is self-contained, follows the IMinigame contract, and matches the declared mode and player limits.
Use severity "blocker" for any issue that should stop publishing.`

func reviewUserPayload(request ReviewRequest) string {
	payload := map[string]any{
		"game_id":          request.GameID,
		"version":          request.Version,
		"author":           request.Author,
		"mode_id":          request.ModeID,
		"tags":             request.Tags,
		"requires_network": request.RequiresNetwork,
		"runtime_contract": request.RuntimeContract,
		"scan_issues":      request.ScanIssues,
		"files":            compactReviewFiles(request.Files),
	}
	bytes, err := json.Marshal(payload)
	if err != nil {
		return "{}"
	}
	return string(bytes)
}

func compactReviewFiles(files []ReviewFile) []map[string]any {
	result := make([]map[string]any, 0, len(files))
	for _, file := range files {
		text := file.ContentText
		if len(text) > 6000 {
			text = text[:6000] + "\n...[truncated]"
		}
		result = append(result, map[string]any{
			"path":         file.Path,
			"size_bytes":   file.SizeBytes,
			"content_text": text,
		})
	}
	return result
}
