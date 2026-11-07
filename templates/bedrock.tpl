# description: Claude on Amazon Bedrock
# var: AWS_REGION | AWS region (blank = the region in your AWS config, else us-east-1) |
# var: AWS_PROFILE | AWS profile name (blank = the default profile / credential chain) |
# secret: AWS_BEARER_TOKEN_BEDROCK | Bedrock API key (blank = use your AWS profile or credentials)
# var: ANTHROPIC_MODEL | Bedrock model or inference profile ID (blank = Claude Code's default) |
# var: ANTHROPIC_DEFAULT_HAIKU_MODEL | Haiku-class model for background tasks (blank = default) |
export CLAUDE_CODE_USE_BEDROCK=1
?export AWS_REGION={{AWS_REGION}}
?export AWS_PROFILE={{AWS_PROFILE}}
?export AWS_BEARER_TOKEN_BEDROCK={{AWS_BEARER_TOKEN_BEDROCK}}
?export ANTHROPIC_MODEL={{ANTHROPIC_MODEL}}
?export ANTHROPIC_DEFAULT_HAIKU_MODEL={{ANTHROPIC_DEFAULT_HAIKU_MODEL}}
ccp_check() {
  if [ -z "${AWS_BEARER_TOKEN_BEDROCK:-}" ] && [ -z "${AWS_ACCESS_KEY_ID:-}" ] && [ ! -d "$HOME/.aws" ]; then
    warn "no AWS credentials found (no ~/.aws, access keys or Bedrock API key)"
  fi
}
