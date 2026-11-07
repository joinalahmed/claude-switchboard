# description: Any Anthropic-compatible gateway or proxy
# var: ANTHROPIC_BASE_URL | Gateway base URL | | required
# secret: ANTHROPIC_AUTH_TOKEN | Gateway token (sent as a Bearer token) | | required
# var: ANTHROPIC_MODEL | Model name the gateway expects (blank = Claude Code's default) |
# var: ANTHROPIC_CUSTOM_HEADERS | Extra request headers, e.g. X-Team: infra (blank = none) |
# A base URL alone doesn't replace a subscription login; the token is what makes requests use the gateway.
export ANTHROPIC_BASE_URL={{ANTHROPIC_BASE_URL}}
export ANTHROPIC_AUTH_TOKEN={{ANTHROPIC_AUTH_TOKEN}}
?export ANTHROPIC_MODEL={{ANTHROPIC_MODEL}}
?export ANTHROPIC_CUSTOM_HEADERS={{ANTHROPIC_CUSTOM_HEADERS}}
