# Object Storage Dev 2 Workspace Setup

This note is a quick checklist to configure Terraform Cloud workspace `object-storage-dev-2` for this repo.

## 1) Confirm workspace target in code

`terraform/object-storage/versions.tf` should point to:

- organization: `vaflt-org`
- workspace: `object-storage-dev-2`

## 2) Create workspace in Terraform Cloud

In Terraform Cloud:

1. Go to org `vaflt-org`
2. Create workspace named `object-storage-dev-2`
3. Set execution mode to `Remote`

## 3) Add Terraform variables in workspace

Add these in Workspace -> Variables -> Terraform Variables:

- `project_id` = `project-3b283cd1-e2df-4449-b43`
- `bucket_name` = `gcp-lz-dev2-uttam-001` (must be globally unique)

Optional:

- `bucket_location` = `US`
- `environment` = `dev`

## 4) Configure GCP runtime auth in workspace

Use the same working bootstrap identity:

- Service account: `tf-deployer@project-3b283cd1-e2df-4449-b43.iam.gserviceaccount.com`
- Workload identity provider: `projects/282888385260/locations/global/workloadIdentityPools/github-pool/providers/github-provider`

## 5) Confirm GitHub secret

In GitHub repo secrets, confirm:

- `TF_API_TOKEN` is set

## 6) Run workflow manually

From GitHub Actions:

1. Open `Terraform Object Storage`
2. Click `Run workflow`
3. Select your target branch/ref
4. Run and verify plan/apply

## 7) Common failures

- Workspace not found: workspace name in code does not match Terraform Cloud.
- Missing variable: add `project_id` and `bucket_name`.
- Credentials error in remote run: workspace GCP auth is not configured.
- Bucket already exists: change `bucket_name` to a new globally unique value.
