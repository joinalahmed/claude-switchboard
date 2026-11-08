# description: Claude Code through a LiteLLM proxy
# var: ANTHROPIC_BASE_URL | LiteLLM base URL | http://localhost:4000 | required
# secret: ANTHROPIC_AUTH_TOKEN | LiteLLM key (master or virtual key) | | required
# var: ANTHROPIC_MODEL | Model alias from your LiteLLM config (blank = Claude Code's default) |
# var: CLAUDE_CODE_MAX_CONTEXT_TOKENS | Context window of that model in tokens, e.g. 1048576 (blank = Claude Code's own idea; 200k for a name it doesn't know) |
# var: DISABLE_PROMPT_CACHING | 1 if the model behind the proxy rejects prompt caching, e.g. Gemini on Vertex AI (blank = keep caching) |
export ANTHROPIC_BASE_URL={{ANTHROPIC_BASE_URL}}
export ANTHROPIC_AUTH_TOKEN={{ANTHROPIC_AUTH_TOKEN}}
?export ANTHROPIC_MODEL={{ANTHROPIC_MODEL}}
?export CLAUDE_CODE_MAX_CONTEXT_TOKENS={{CLAUDE_CODE_MAX_CONTEXT_TOKENS}}
?export DISABLE_PROMPT_CACHING={{DISABLE_PROMPT_CACHING}}
