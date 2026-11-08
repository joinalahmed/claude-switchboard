# description: Any Anthropic-compatible gateway or proxy
# var: ANTHROPIC_BASE_URL | Gateway base URL | | required
# secret: ANTHROPIC_AUTH_TOKEN | Gateway token (sent as a Bearer token) | | required
# var: ANTHROPIC_MODEL | Model name the gateway expects (blank = Claude Code's default) |
# var: CLAUDE_CODE_MAX_CONTEXT_TOKENS | Context window of that model in tokens, e.g. 1048576 (blank = Claude Code's own idea; 200k for a name it doesn't know) |
# var: DISABLE_PROMPT_CACHING | 1 if the model behind the proxy rejects prompt caching, e.g. Gemini on Vertex AI (blank = keep caching) |
# var: ANTHROPIC_CUSTOM_HEADERS | Extra request headers, e.g. X-Team: infra (blank = none) |
# A base URL alone doesn't replace a subscription login; the token is what makes requests use the gateway.
export ANTHROPIC_BASE_URL={{ANTHROPIC_BASE_URL}}
export ANTHROPIC_AUTH_TOKEN={{ANTHROPIC_AUTH_TOKEN}}
?export ANTHROPIC_MODEL={{ANTHROPIC_MODEL}}
?export CLAUDE_CODE_MAX_CONTEXT_TOKENS={{CLAUDE_CODE_MAX_CONTEXT_TOKENS}}
?export DISABLE_PROMPT_CACHING={{DISABLE_PROMPT_CACHING}}
?export ANTHROPIC_CUSTOM_HEADERS={{ANTHROPIC_CUSTOM_HEADERS}}
