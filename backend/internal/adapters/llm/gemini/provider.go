package gemini

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// Provider implements ports.LLMProvider using Google Gemini REST API.
// Uses direct HTTP to avoid heavy SDK dependency.
type Provider struct {
	apiKey     string
	model      string
	httpClient *http.Client
}

func NewProvider(apiKey string) *Provider {
	return &Provider{
		apiKey:     apiKey,
		model:      "gemini-2.5-flash",
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}
}

// geminiRequest / geminiResponse model the Gemini generateContent REST API.
type geminiRequest struct {
	SystemInstruction *geminiContent `json:"systemInstruction,omitempty"`
	Contents          []geminiContent `json:"contents"`
	GenerationConfig  *genConfig      `json:"generationConfig,omitempty"`
}

type geminiContent struct {
	Parts []geminiPart `json:"parts"`
}

type geminiPart struct {
	Text string `json:"text"`
}

type genConfig struct {
	Temperature     float64 `json:"temperature"`
	MaxOutputTokens int     `json:"maxOutputTokens"`
}

type geminiResponse struct {
	Candidates []struct {
		Content struct {
			Parts []struct {
				Text string `json:"text"`
			} `json:"parts"`
		} `json:"content"`
	} `json:"candidates"`
	Error *struct {
		Message string `json:"message"`
		Code    int    `json:"code"`
	} `json:"error,omitempty"`
}

func (p *Provider) Generate(ctx context.Context, systemPrompt, userPrompt string) (string, error) {
	// P2: API key travels in the x-goog-api-key header, never in the URL
	// query string (URLs land in proxy/access logs and traces).
	url := fmt.Sprintf(
		"https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent",
		p.model,
	)

	reqBody := geminiRequest{
		Contents: []geminiContent{
			{Parts: []geminiPart{{Text: userPrompt}}},
		},
		GenerationConfig: &genConfig{
			Temperature:     0.7,
			MaxOutputTokens: 2048,
		},
	}

	if systemPrompt != "" {
		reqBody.SystemInstruction = &geminiContent{
			Parts: []geminiPart{{Text: systemPrompt}},
		}
	}

	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("gemini: marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
	if err != nil {
		return "", fmt.Errorf("gemini: create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-goog-api-key", p.apiKey)

	resp, err := p.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("gemini: request failed: %w", err)
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("gemini: read response: %w", err)
	}

	var gemResp geminiResponse
	if err := json.Unmarshal(respBytes, &gemResp); err != nil {
		return "", fmt.Errorf("gemini: unmarshal response: %w", err)
	}

	if gemResp.Error != nil {
		return "", fmt.Errorf("gemini: API error %d: %s", gemResp.Error.Code, gemResp.Error.Message)
	}

	if len(gemResp.Candidates) == 0 || len(gemResp.Candidates[0].Content.Parts) == 0 {
		return "", fmt.Errorf("gemini: empty response")
	}

	return gemResp.Candidates[0].Content.Parts[0].Text, nil
}
