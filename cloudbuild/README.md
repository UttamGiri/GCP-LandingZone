# Cloud Build Pipelines

This folder contains Cloud Build pipeline definitions used by the landing zone CI/CD setup.

## Files

- `cloudbuild-plan.yaml`
  - Runs `terraform init`, `terraform validate`, and `terraform plan`
  - Intended for pull request checks (no infrastructure changes)

- `cloudbuild-apply.yaml`
  - Runs `terraform init`, `terraform plan`, and `terraform apply`
  - Intended for merges to `main` (deploys infrastructure changes)

## How this is wired

Stage 4 (`stages/4-cicd/main.tf`) creates Cloud Build triggers that point to these files:

- PR trigger -> `cloudbuild-plan.yaml`
- Main branch trigger -> `cloudbuild-apply.yaml`

## Notes

- Set stage with substitution `_STAGE` (for example `0-org-setup`, `1-security`, `2-networking`, `3-project-factory`, `4-cicd`).
- Use separate service accounts/permissions for plan vs apply.
- Protect `main` branch and require review before apply trigger can run.
