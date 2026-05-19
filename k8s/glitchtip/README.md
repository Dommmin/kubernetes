# GlitchTip on Kubernetes

GlitchTip is the self-hosted, Sentry-SDK-compatible error tracking platform.
Run it as a **separate Helm release in its own namespace** (`glitchtip`),
not inside the `app` namespace — that way an outage in the main namespace
doesn't break your error reporting.

## What's in this directory

| File | Purpose |
|------|---------|
| `values.example.yaml` | Helm values template for chart **8.2.0** — copy to `values.yaml` (gitignored), set domain + SMTP |
| `secret.yaml.example` | Secret template — copy to `secret.yaml` (gitignored): `SECRET_KEY`, `POSTGRES_PASSWORD`, `DATABASE_URL` |
| `postgresql.yaml` | Standalone PostgreSQL StatefulSet — chart 8.2.0's bundled Postgres needs the CloudNativePG operator, so we run our own |

## Why a standalone Postgres?

The GlitchTip Helm chart (8.x) dropped its bundled Postgres subchart. Its
`postgresql.enabled: true` path now emits a `postgresql.cnpg.io/v1` Cluster
resource — i.e. it expects the **CloudNativePG operator** installed
cluster-wide. To avoid that dependency, `postgresql.yaml` here is a plain
single-instance Postgres StatefulSet, and the chart is pointed at it via
`glitchtip.database.existingSecret` (a secret holding `DATABASE_URL`).

Valkey (Redis-compatible) **is** still bundled by the chart
(`valkey.enabled: true`) — it auto-wires `REDIS_URL`, nothing to configure.

## Quick start

```bash
# 1. Create the two gitignored files from templates
cp k8s/glitchtip/values.example.yaml k8s/glitchtip/values.yaml
cp k8s/glitchtip/secret.yaml.example k8s/glitchtip/secret.yaml

# 2. Generate secrets
openssl rand -hex 25              # → SECRET_KEY
openssl rand -base64 24 | tr -d '/+='   # → POSTGRES_PASSWORD

# 3. Edit secret.yaml — set SECRET_KEY, POSTGRES_PASSWORD, and DATABASE_URL
#    (the password inside DATABASE_URL must match POSTGRES_PASSWORD).
# 4. Edit values.yaml — set glitchtip.domain, the ingress host(s), and the
#    EMAIL_URL / DEFAULT_FROM_EMAIL under web.extraEnvVars.

# 5. Deploy: namespace → secret → Postgres → chart
kubectl create namespace glitchtip --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/glitchtip/secret.yaml
kubectl apply -f k8s/glitchtip/postgresql.yaml
kubectl -n glitchtip rollout status statefulset/glitchtip-postgresql --timeout=3m

helm repo add glitchtip https://gitlab.com/api/v4/projects/16325141/packages/helm/stable --force-update
helm repo update glitchtip
helm upgrade --install glitchtip glitchtip/glitchtip \
  --namespace glitchtip \
  -f k8s/glitchtip/values.yaml
```

`bootstrap.sh` (Step 12) runs all of the above automatically when both
`values.yaml` and `secret.yaml` exist.

## After install

1. Open `https://<glitchtip.domain>` and create an organization.
2. Create two projects: `cms-api` (PHP/Laravel) and `cms-frontend` (Next.js).
3. From **Settings → Client Keys (DSN)** copy each DSN.
4. Wire DSNs into the CMS:
   - Laravel: set `GLITCHTIP_DSN` in `server/.env.production` (and in the
     `PROD_ENV` GitHub Variable so CI/CD picks it up).
   - Next.js: set `NEXT_PUBLIC_GLITCHTIP_DSN` in `ENV_CLIENT_PROD`
     (it's baked at build time).
5. Trigger a deploy — from the next rollout, exceptions are reported.

Smoke test:

```bash
# Defaults shown: APP_NAME=app, KUBE_NAMESPACE=app.
kubectl -n app exec deployment/app-server -- \
  php artisan tinker --execute='throw new \Exception("glitchtip test event");'
```

The event should appear under **Issues** in GlitchTip within ~30 seconds.
