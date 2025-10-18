# DEPLOY.md

## Overview

This app is a stateless Dancer2 service deployed to **Google Cloud Run**. We use:

* **Two tiny shell scripts** in `bin/`:

  * `bin/build_container` — builds and pushes a Docker image to **Artifact Registry**
  * `bin/deploy_container` — deploys that image to **Cloud Run**
* **Two GitHub Actions workflows**:

  * `.github/workflows/build.yml` — builds & pushes, then calls…
  * `.github/workflows/deploy.yml` — reusable workflow that deploys **by image digest** (immutable)

We **do not** use Cloud Build. Images are built on the GitHub runner and pushed directly.

Default region: **europe-west1** (supports Cloud Run custom domain mappings).
Service name: **feeds**.
Artifact Registry repository: **containers**.

---

## Prerequisites

* Google Cloud project (e.g. `dave-web-apps`)
* APIs enabled: `run.googleapis.com`, `artifactregistry.googleapis.com`, `iam.googleapis.com`, `iamcredentials.googleapis.com`
* **Artifact Registry** repo `containers` in the chosen region
* **Workload Identity Federation (WIF)** set up for GitHub Actions:

  * A deployer **Service Account** (e.g. `github-deployer@PROJECT_ID.iam.gserviceaccount.com`)
  * WIF pool/provider bound to your GitHub repo (`davorg/feeds`)
* Minimal IAM for the deployer SA:

  * `roles/run.admin`
  * `roles/artifactregistry.writer`
  * `roles/iam.serviceAccountUser` on the **runtime** service account (usually `${PROJECT_NUMBER}-compute@developer.gserviceaccount.com`)

**Repo Secrets** (GitHub → Settings → Secrets and variables → Actions → Secrets):

* `GCP_PROJECT_ID` (e.g. `dave-web-apps`)
* `GCP_WORKLOAD_ID_PROVIDER` (full resource name)
* `GCP_SERVICE_ACCOUNT` (email of deployer SA)

> We intentionally keep the **project ID** as a secret or variable; the workflows don’t depend on passing it between jobs.

---

## Local Development

### Run locally with Docker

```bash
docker build -t feeds:dev .
docker run -e PORT=8080 -p 8080:8080 feeds:dev
# http://localhost:8080
```

### One-off manual deploy (useful for sanity checks)

```bash
export PROJECT_ID=dave-web-apps
export REGION=europe-west1

# Build & push
bin/build_container      # writes image_ref.txt

# Deploy
bin/deploy_container     # reads image_ref.txt or use IMAGE_REF=... bin/deploy_container
```

Both scripts check required env vars and will print the full image reference and final service URL.

---

## CI/CD Workflows

### 1) Build workflow (`.github/workflows/build.yml`)

* Auth via WIF
* Set `TAG=${{ github.sha }}` (deterministic)
* Run `bin/build_container` (build & push)
* Resolve **digest** for the pushed image and pass it to the deploy workflow

### 2) Deploy workflow (`.github/workflows/deploy.yml`)

* Reconstruct an **immutable** image reference from:

  ```
  ${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/${IMAGE_NAME}@${DIGEST}
  ```
* Write it to `image_ref.txt`
* Run `bin/deploy_container` to update the Cloud Run service

> We pass the **digest** between workflows (not the full image ref) to avoid GitHub’s “secret-like outputs” suppression and to guarantee immutability.

---

## Environment Variables (used by scripts)

**Required**

* `PROJECT_ID` — GCP project ID
* `REGION` — GCP region (default for this repo: `europe-west1`)

**Optional (with defaults)**

* `AR_REPO` — Artifact Registry repo (default `containers`)
* `IMAGE_NAME` — image name (default = repo dir name; we set `feeds` in workflows)
* `TAG` — tag for build (default = short git sha; in CI we use full `${{ github.sha }}`)
* `SERVICE_NAME` — Cloud Run service name (default derived from image name; we use `feeds`)
* `ALLOW_UNAUTH` — `true`/`false` (default `true`)
* `MEMORY` — default `256Mi`
* `CPU` — default `1`
* `CONCURRENCY` — default `80`
* `MIN_INSTANCES` — default `0`
* `MAX_INSTANCES` — unset (omit flag)
* `ENV_VARS` — comma-separated `KEY=VALUE` pairs (optional)
* `RUNTIME_SERVICE_ACCOUNT` — override the runtime SA (optional)

---

## Custom Domain

The service runs at a `run.app` URL by default. To use **feeds.davecross.co.uk**:

1. Deploy in a **domain-mapping supported region** (we use `europe-west1`).
2. Cloud Run → **Custom domains** → Map `feeds.davecross.co.uk` to service `feeds`.
3. Create the **CNAME** the wizard shows (usually `feeds → ghs.googlehosted.com.`).
4. Wait for the managed certificate to provision. Check status:

   ```bash
   gcloud beta run domain-mappings describe \
     --domain=feeds.davecross.co.uk \
     --region=europe-west1 \
     --format="value(status.conditions[?type=Ready].status,status.conditions[?type=Ready].message)"
   ```

> If you must keep London (`europe-west2`), use an HTTPS Load Balancer with a Serverless NEG instead of Cloud Run’s built-in mapping.

---

## Rollbacks

Because we deploy by **digest**, rolling back is deterministic:

* Find a prior digest:

  ```bash
  gcloud artifacts docker images list \
    europe-west1-docker.pkg.dev/$PROJECT_ID/containers/feeds \
    --format='table(IMAGE,DIGEST,TAGS,UPDATE_TIME)'
  ```
* Re-deploy using that digest:

  ```bash
  IMAGE_REF="europe-west1-docker.pkg.dev/$PROJECT_ID/containers/feeds@sha256:…"
  IMAGE_REF="$IMAGE_REF" bin/deploy_container
  ```

---

## Clean-up

* Delete old services once you’re sure you won’t roll back:

  ```bash
  gcloud run services delete feeds --region=europe-west2
  ```
* Delete unused Artifact Registry repos/images to save storage.

---

## Troubleshooting

* **Auth in Actions**: Ensure `auth@v2` step runs with WIF and we export
  `GOOGLE_APPLICATION_CREDENTIALS` + `CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE`
  in the build/deploy steps.
* **“Skip output since it may contain secret”**: We pass the **digest** only to avoid this.
* **“iam.serviceAccountUser” error on deploy**: Grant deployer SA that role on the runtime SA.
* **Domain mapping stuck “Waiting for certificate provisioning”**:

  * CNAME must point to `ghs.googlehosted.com.`
  * Domain must be verified in your Google account (Search Console)
  * Give it time; cert issuance can take a while.
* **Region unsupported for custom domains**: Use `europe-west1` or put a global HTTPS LB in front.

---

## Conventions

* Region: `europe-west1`
* Service: `feeds`
* Repo: `containers`
* Build tag: full commit SHA
* Deploy: **by digest** (immutable)

---

If anything here drifts from reality, update this file in the same PR as any workflow/script change so new contributors always have a single source of truth.

