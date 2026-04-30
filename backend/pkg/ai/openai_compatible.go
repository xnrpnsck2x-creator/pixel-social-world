package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type OpenAICompatibleConfig struct {
	BaseURL string
	Model   string
	APIKey  string
	Timeout time.Duration
}

type OpenAICompatibleReviewer struct {
	baseURL string
	model   string
	apiKey  string
	client  *http.Client
}

func NewOpenAICompatibleReviewer(config OpenAICompatibleConfig) OpenAICompatibleReviewer {
	if config.BaseURL == "" {
		config.BaseURL = "http://127.0.0.1:1234/v1"
	}
	if config.Model == "" {
		config.Model = "qwen/qwen3-coder-next"
	}
	if config.Timeout <= 0 {
		config.Timeout = 45 * time.Second
	}
	return OpenAICompatibleReviewer{
		baseURL: strings.TrimRight(config.BaseURL, "/"),
		model:   config.Model,
		apiKey:  config.APIKey,
		client:  &http.Client{Timeout: config.Timeout},
	}
}

func (r OpenAICompatibleReviewer) ReviewMinigame(
	ctx context.Context,
	request ReviewRequest,
) (ReviewResult, error) {
	body, err := json.Marshal(r.chatRequest(request))
	if err != nil {
		return ReviewResult{}, err
	}
	httpRequest, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		r.baseURL+"/chat/completions",
		bytes.NewReader(body),
	)
	if err != nil {
		return ReviewResult{}, err
	}
	httpRequest.Header.Set("Content-Type", "application/json")
	if r.apiKey != "" {
		httpRequest.Header.Set("Authorization", "Bearer "+r.apiKey)
	}
	response, err := r.client.Do(httpRequest)
	if err != nil {
		return ReviewResult{}, err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return ReviewResult{}, fmt.Errorf("llm_review_http_%d", response.StatusCode)
	}
	responseBytes, err := io.ReadAll(io.LimitReader(response.Body, 2*1024*1024))
	if err != nil {
		return ReviewResult{}, err
	}
	content, err := chatCompletionContent(responseBytes)
	if err != nil {
		return ReviewResult{}, err
	}
	return parseReviewJSON(content)
}

func (r OpenAICompatibleReviewer) chatRequest(request ReviewRequest) map[string]any {
	return map[string]any{
		"model":           r.model,
		"temperature":     0,
		"stream":          false,
		"response_format": reviewResponseFormat(),
		"messages": []map[string]string{
			{"role": "system", "content": reviewerSystemPrompt},
			{"role": "user", "content": reviewUserPayload(request)},
		},
	}
}

func reviewResponseFormat() map[string]any {
	return map[string]any{
		"type": "json_schema",
		"json_schema": map[string]any{
			"name":   "minigame_review",
			"strict": true,
			"schema": map[string]any{
				"type":                 "object",
				"additionalProperties": false,
				"required":             []string{"approved", "risk_level", "notes"},
				"properties": map[string]any{
					"approved":   map[string]any{"type": "boolean"},
					"risk_level": map[string]any{"type": "string", "enum": []string{"low", "medium", "high"}},
					"notes": map[string]any{
						"type": "array",
						"items": map[string]any{
							"type":                 "object",
							"additionalProperties": false,
							"required":             []string{"code", "severity", "message", "path"},
							"properties": map[string]any{
								"code":     map[string]any{"type": "string"},
								"severity": map[string]any{"type": "string", "enum": []string{"info", "warning", "blocker"}},
								"message":  map[string]any{"type": "string"},
								"path":     map[string]any{"type": "string"},
							},
						},
					},
				},
			},
		},
	}
}

func chatCompletionContent(responseBytes []byte) (string, error) {
	var envelope struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.Unmarshal(responseBytes, &envelope); err != nil {
		return "", err
	}
	if len(envelope.Choices) == 0 || strings.TrimSpace(envelope.Choices[0].Message.Content) == "" {
		return "", errors.New("llm_review_empty_response")
	}
	return envelope.Choices[0].Message.Content, nil
}

func parseReviewJSON(content string) (ReviewResult, error) {
	cleaned := extractJSONObject(content)
	var result ReviewResult
	if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
		return ReviewResult{}, err
	}
	if result.RiskLevel == "" {
		result.RiskLevel = "unknown"
	}
	if len(result.Notes) == 0 {
		result.Notes = append(result.Notes, ReviewNote{
			Code:     "llm_review_no_notes",
			Severity: "info",
			Message:  "LLM reviewer returned no detailed notes.",
		})
	}
	return result, nil
}

func extractJSONObject(content string) string {
	trimmed := strings.TrimSpace(content)
	if strings.HasPrefix(trimmed, "```") {
		trimmed = strings.TrimPrefix(trimmed, "```json")
		trimmed = strings.TrimPrefix(trimmed, "```")
		trimmed = strings.TrimSuffix(trimmed, "```")
		trimmed = strings.TrimSpace(trimmed)
	}
	start := strings.Index(trimmed, "{")
	end := strings.LastIndex(trimmed, "}")
	if start >= 0 && end > start {
		return trimmed[start : end+1]
	}
	return trimmed
}
