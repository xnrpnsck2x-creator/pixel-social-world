package gateway

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func creatorDraftPayload(playerID string) map[string]any {
	return map[string]any{
		"game_id":          "creator_owner_duel",
		"version":          "0.1.0",
		"author":           playerID,
		"mode_id":          "2d_fighting",
		"name":             map[string]any{"en": "Owner Duel", "ja": "Owner Duel", "zh": "Owner Duel"},
		"min_players":      1,
		"max_players":      4,
		"tags":             []string{"fighting", "fixture"},
		"requires_network": true,
		"runtime_contract": map[string]any{
			"camera":          "side_view",
			"input_profile":   "fighting_action",
			"network_profile": "authoritative_realtime",
		},
		"entry_scene":        "res://creator/creator_owner_duel/main.tscn",
		"main_script":        "res://creator/creator_owner_duel/game.gd",
		"asset_budget_bytes": 5242880,
	}
}

func creatorPackagePayload(playerID string, gameID string, script string) map[string]any {
	payload := creatorDraftPayload(playerID)
	payload["game_id"] = gameID
	payload["version"] = "0.1.0"
	payload["tags"] = []string{"fighting", "package"}
	payload["entry_scene"] = "res://creator/" + gameID + "/main.tscn"
	payload["main_script"] = "res://creator/" + gameID + "/game.gd"
	meta, _ := json.Marshal(payload)
	payload["files"] = []map[string]any{
		{"path": "meta.json", "content_text": string(meta)},
		{"path": "main.tscn", "content_text": "[gd_scene format=3]\n[node name=\"Game\" type=\"Node\"]"},
		{"path": "game.gd", "content_text": script},
		{"path": "README.md", "content_text": "Creator package fixture."},
	}
	return payload
}

func safePackageScript() string {
	return "class_name GatewayPackageFixture\nextends IMinigame\n\nfunc get_game_id() -> String:\n\treturn \"creator_package\"\n"
}

func creatorZipPayload(t *testing.T, prefix string, files []map[string]any) []byte {
	t.Helper()
	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	for _, file := range files {
		entry, err := writer.Create(prefix + file["path"].(string))
		if err != nil {
			t.Fatalf("create zip entry: %v", err)
		}
		if _, err := entry.Write([]byte(file["content_text"].(string))); err != nil {
			t.Fatalf("write zip entry: %v", err)
		}
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("close zip: %v", err)
	}
	return buffer.Bytes()
}

func testPostMultipartPackage(
	t *testing.T,
	server *Server,
	path string,
	accessToken string,
	author string,
	archive []byte,
	wantStatus int,
) map[string]any {
	t.Helper()
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	if err := writer.WriteField("author", author); err != nil {
		t.Fatalf("write author field: %v", err)
	}
	part, err := writer.CreateFormFile("package", "creator.zip")
	if err != nil {
		t.Fatalf("create package form file: %v", err)
	}
	if _, err := part.Write(archive); err != nil {
		t.Fatalf("write package form file: %v", err)
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("close multipart writer: %v", err)
	}
	request := httptest.NewRequest(http.MethodPost, path, &body)
	request.Header.Set("Content-Type", writer.FormDataContentType())
	if accessToken != "" {
		request.Header.Set("Authorization", "Bearer "+accessToken)
	}
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != wantStatus {
		t.Fatalf("expected %d for %s, got %d: %s", wantStatus, path, recorder.Code, recorder.Body.String())
	}
	var decoded map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	return decoded
}

func testGetJSON(
	t *testing.T,
	server *Server,
	path string,
	accessToken string,
	wantStatus int,
) map[string]any {
	t.Helper()
	request := httptest.NewRequest(http.MethodGet, path, nil)
	if accessToken != "" {
		request.Header.Set("Authorization", "Bearer "+accessToken)
	}
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != wantStatus {
		t.Fatalf("expected %d for %s, got %d: %s", wantStatus, path, recorder.Code, recorder.Body.String())
	}
	var decoded map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	return decoded
}

func waitCreatorStatus(
	t *testing.T,
	server *Server,
	path string,
	accessToken string,
	wantStatus string,
) map[string]any {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	var status map[string]any
	for time.Now().Before(deadline) {
		status = testGetJSON(t, server, path, accessToken, http.StatusOK)
		if status["status"] == wantStatus {
			return status
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s status, last response: %#v", wantStatus, status)
	return status
}
