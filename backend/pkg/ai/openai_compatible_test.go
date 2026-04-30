package ai

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestOpenAICompatibleReviewerParsesJSONResult(t *testing.T) {
	var requestModel string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/chat/completions" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		requestModel = payload["model"].(string)
		_, _ = w.Write([]byte(`{
			"choices": [{
				"message": {
					"content": "{\"approved\":true,\"risk_level\":\"low\",\"notes\":[{\"code\":\"ok\",\"severity\":\"info\",\"message\":\"clean\"}]}"
				}
			}]
		}`))
	}))
	defer server.Close()

	reviewer := NewOpenAICompatibleReviewer(OpenAICompatibleConfig{
		BaseURL: server.URL + "/v1",
		Model:   "test-model",
		Timeout: time.Second,
	})
	result, err := reviewer.ReviewMinigame(context.Background(), ReviewRequest{GameID: "creator_test"})
	if err != nil {
		t.Fatalf("ReviewMinigame returned error: %v", err)
	}
	if requestModel != "test-model" {
		t.Fatalf("model was not sent: %s", requestModel)
	}
	if !result.Approved || result.RiskLevel != "low" || len(result.Notes) != 1 {
		t.Fatalf("unexpected result: %#v", result)
	}
}

func TestFallbackReviewerUsesLocalPolicyOnLLMFailure(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	primary := NewOpenAICompatibleReviewer(OpenAICompatibleConfig{
		BaseURL: server.URL + "/v1",
		Model:   "test-model",
		Timeout: time.Second,
	})
	reviewer := NewFallbackReviewer(primary, NewLocalPolicyReviewer())
	result, err := reviewer.ReviewMinigame(context.Background(), ReviewRequest{
		GameID: "creator_fallback",
		Files:  []ReviewFile{{Path: "game.gd", ContentText: "extends IMinigame"}},
	})
	if err != nil {
		t.Fatalf("ReviewMinigame returned error: %v", err)
	}
	if !result.Approved || len(result.Notes) == 0 || result.Notes[0].Code != "llm_review_fallback" {
		t.Fatalf("fallback note missing: %#v", result)
	}
}
