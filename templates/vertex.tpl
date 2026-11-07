# description: Claude on Google Cloud (Vertex AI / Agent Platform), direct
# var: CLOUD_ML_REGION | Region: global, a multi-region (eu or us) or e.g. us-east5 | global | required
# var: ANTHROPIC_VERTEX_PROJECT_ID | GCP project ID (blank = gcloud's current project) |
# var: ANTHROPIC_MODEL | Model ID to pin, from Model Garden (blank = Claude Code's default) |
# var: ANTHROPIC_DEFAULT_HAIKU_MODEL | Haiku-class model for background tasks (blank = default) |
# Needs: Vertex AI API enabled, Claude enabled in Model Garden, role roles/aiplatform.user,
# and credentials:  gcloud auth application-default login
export CLAUDE_CODE_USE_VERTEX=1
export CLOUD_ML_REGION={{CLOUD_ML_REGION}}
?export ANTHROPIC_VERTEX_PROJECT_ID={{ANTHROPIC_VERTEX_PROJECT_ID}}
?export ANTHROPIC_MODEL={{ANTHROPIC_MODEL}}
?export ANTHROPIC_DEFAULT_HAIKU_MODEL={{ANTHROPIC_DEFAULT_HAIKU_MODEL}}
# With CLOUD_ML_REGION=global, models without global-endpoint support can be routed per model:
# export VERTEX_REGION_CLAUDE_HAIKU_4_5=us-east5
