package ports

import "context"

// LLMProvider abstracts a large language model API (Gemini, OpenAI, etc.)
type LLMProvider interface {
	// Generate sends a system prompt + user prompt and returns the model response.
	Generate(ctx context.Context, systemPrompt, userPrompt string) (string, error)
}
