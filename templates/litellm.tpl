# description: Claude Code through a LiteLLM proxy
# var: ANTHROPIC_BASE_URL | LiteLLM base URL | http://localhost:4000 | required
# secret: ANTHROPIC_AUTH_TOKEN | LiteLLM key (master or virtual key) | | required
# var: ANTHROPIC_MODEL | Model alias from your LiteLLM config (blank = Claude Code's default) |
export ANTHROPIC_BASE_URL={{ANTHROPIC_BASE_URL}}
export ANTHROPIC_AUTH_TOKEN={{ANTHROPIC_AUTH_TOKEN}}
?export ANTHROPIC_MODEL={{ANTHROPIC_MODEL}}
