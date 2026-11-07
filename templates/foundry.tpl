# description: Claude on Microsoft Foundry (Azure)
# var: ANTHROPIC_FOUNDRY_RESOURCE | Foundry resource name | | required
# secret: ANTHROPIC_FOUNDRY_API_KEY | Foundry API key (blank = Entra ID, e.g. after az login)
# var: ANTHROPIC_DEFAULT_OPUS_MODEL | Opus deployment name (blank = Claude Code's default) |
# var: ANTHROPIC_DEFAULT_SONNET_MODEL | Sonnet deployment name (blank = default) |
# var: ANTHROPIC_DEFAULT_HAIKU_MODEL | Haiku deployment name (blank = default) |
# Deployment names must match the deployments you created in the Foundry portal.
export CLAUDE_CODE_USE_FOUNDRY=1
export ANTHROPIC_FOUNDRY_RESOURCE={{ANTHROPIC_FOUNDRY_RESOURCE}}
?export ANTHROPIC_FOUNDRY_API_KEY={{ANTHROPIC_FOUNDRY_API_KEY}}
?export ANTHROPIC_DEFAULT_OPUS_MODEL={{ANTHROPIC_DEFAULT_OPUS_MODEL}}
?export ANTHROPIC_DEFAULT_SONNET_MODEL={{ANTHROPIC_DEFAULT_SONNET_MODEL}}
?export ANTHROPIC_DEFAULT_HAIKU_MODEL={{ANTHROPIC_DEFAULT_HAIKU_MODEL}}
