# Deploying the Boutique App on AWS EKS

A step-by-step guide to deploy this microservices application on Amazon EKS with
CI/CD (GitHub Actions), GitOps (ArgoCD), and monitoring (Prometheus + Grafana).

Follow the steps in order. Each section says **what** you are doing and **why**.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [What We Changed (and Why)](#2-what-we-changed-and-why)
3. [Provision the Infrastructure (Terraform)](#3-provision-the-infrastructure-terraform)
4. [Connect to the Cluster](#4-connect-to-the-cluster)
5. [Build & Push Images (CI/CD)](#5-build--push-images-cicd)
6. [Deploy the App Manifests](#6-deploy-the-app-manifests)
7. [Set Up ArgoCD (GitOps)](#7-set-up-argocd-gitops)
8. [Seed the Database](#8-seed-the-database)
9. [Test the Application](#9-test-the-application)
10. [Monitoring (Prometheus & Grafana)](#10-monitoring-prometheus--grafana)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisites

Install and configure these before you start:

| Tool       | Check it works            |
| ---------- | ------------------------- |
| AWS CLI    | `aws sts get-caller-identity` |
| Terraform  | `terraform version`       |
| kubectl    | `kubectl version --client`|
| Helm       | `helm version`            |
| Git        | `git --version`           |

You also need:

- An AWS account with permission to create VPC, EKS, ECR, and IAM resources.
- A GitHub account (to host this repo and run the CI pipeline).
- The AWS region used in this guide: **`ap-south-1`** (change it everywhere if you use another).

---

## 2. What We Changed (and Why)

This repo was tuned so the deployment actually works end-to-end. Key changes:

**Kubernetes manifests (`gitops/`)**

1. Replaced the `<AWS_ACCOUNT_ID>` placeholder in all 7 Deployment images with the
   real account ID + region (so Kubernetes can pull from your ECR).
2. Fixed `order-service` Service port `3002 → 3004` — it pointed at the wrong port,
   which broke gateway → order-service (cart/checkout) traffic.
3. Added a named `http` port and a `monitored: "true"` label to all 6 backend Services.
4. Widened the `ServiceMonitor` selector from `app: gateway` to `monitored: "true"`
   so Prometheus scrapes **all** backend services, not just the gateway.

**Terraform (`projects/Infrastructure/`)**

5. Added `backend.tf` for S3 remote state (bucket `tf-devops-ai-statefile`, `ap-south-1`).
6. Switched the kubernetes/helm providers to `exec` auth (`aws eks get-token`) so the
   EKS token can't expire mid-apply (was failing with a 401).
7. Bumped the node group `t3.medium → t3.large` and `desired_size 1 → 2`. A `t3.medium`
   caps at 17 pods and couldn't fit monitoring + app + ArgoCD ("Too many pods").

---

## 3. Provision the Infrastructure (Terraform)

**What:** Create the VPC wiring, EKS cluster, node group, ECR repos, and install
ArgoCD + monitoring via Helm.
**Why:** This is the foundation everything else runs on.

```bash
cd projects/Infrastructure

terraform init      # download providers, connect to S3 backend
terraform plan      # review what will be created
terraform apply     # type "yes" to confirm
```

> This takes ~15 minutes (EKS + node group are slow to create).

---

## 4. Connect to the Cluster

**What:** Point `kubectl`/`helm` at your new cluster.
**Why:** Terraform uses its own credentials; your local tools need their own kubeconfig.

```bash
aws eks update-kubeconfig --name eks-cluster --region ap-south-1
```

Verify the cluster is up:

```bash
kubectl get nodes          # expect 2 nodes, STATUS Ready
kubectl get pods -A        # core pods Running
kubectl get pods -n argocd # ArgoCD pods Running
```

---

## 5. Build & Push Images (CI/CD)

**What:** Let GitHub Actions build each service image and push it to ECR.
**Why:** Kubernetes pulls these images from ECR — they must exist first.

1. In your GitHub repo: **Settings → Secrets and variables → Actions** and add the
   secrets your `ci.yml` expects (AWS credentials, account ID, region).
2. Push to the branch that triggers the pipeline:

   ```bash
   git add .
   git commit -m "trigger CI"
   git push
   ```

3. Watch the run under the repo's **Actions** tab until all images are pushed to ECR.

---

## 6. Deploy the App Manifests

**What:** Apply all Kubernetes resources at once with Kustomize.
**Why:** One command creates the namespace, secrets, database, and every service.

```bash
kubectl apply -k gitops/
```

This applies ~12 resources: namespace, secret, Postgres (StatefulSet + Service),
6 backend Deployments, the frontend, the ServiceMonitor, the Grafana dashboard,
and the generated DB-dump ConfigMap.

Check the pods:

```bash
kubectl get pods -n boutique
```

> Some pods may show errors at first (old image tag, or the database isn't seeded yet).
> ArgoCD (next step) keeps them in sync, and the DB restore (step 8) fixes the rest.

---

## 7. Set Up ArgoCD (GitOps)

**What:** Connect ArgoCD to your Git repo so it deploys and self-heals from Git.
**Why:** After this, changes pushed to Git roll out automatically — no manual `kubectl`.

### 7.1 Open the ArgoCD UI

```bash
kubectl get svc -n argocd
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

> **Open `http://localhost:8080` — NOT https.**
> ArgoCD runs in insecure (plain HTTP) mode here. If the browser shows
> `connection reset by peer`, it's auto-upgrading to HTTPS. Fix it by turning off
> Chrome's "Always use secure connections" and clearing HSTS for `localhost`
> (`chrome://net-internals/#hsts`), or just use Firefox / an incognito tab.

### 7.2 Get the admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

Log in:

- **User:** `admin`
- **Password:** _(output of the command above)_

### 7.3 Connect your Git repo

In the UI: **Settings → Repositories → Connect repo using HTTPS**

- Project: `default` (or your project name)
- Repository URL: your repo's HTTPS URL
- Username: your GitHub username
- Password: a **GitHub PAT** (Personal Access Token) with `repo` read scope

### 7.4 Register the application

```bash
kubectl apply -f gitops/argo-cd.yml -n argocd
```

Then open the ArgoCD UI and **Sync** to apply the latest changes.

> **Auto-sync (optional):** to make ArgoCD deploy and self-heal automatically, set
> `syncPolicy.automated` (with `prune` + `selfHeal`) in `gitops/argo-cd.yml` and
> re-apply the command above.

---

## 8. Seed the Database

**What:** Run a Job that loads the database dump into Postgres.
**Why:** Backend services (except Postgres and frontend) crash until their databases exist.

> **Apply this only AFTER the Postgres pod is `1/1` Ready:**

```bash
kubectl get pods -n boutique -l app=postgres   # wait for READY 1/1
kubectl apply -f gitops/k8s/database/restore-job.yml
kubectl get pods -n boutique
```

If the restore Job ran too early, delete the **Job** (not just the pods) and re-apply:

```bash
kubectl delete job boutique-db-restore -n boutique
kubectl apply -f gitops/k8s/database/restore-job.yml
```

Once the restore completes, delete any crashed backend pods so they restart against
the seeded database:

```bash
kubectl delete pod -n boutique --field-selector=status.phase!=Running
kubectl get pods -n boutique   # all should become Running / Ready
```

---

## 9. Test the Application

**What:** Forward the gateway and frontend ports to your machine.
**Why:** Services are internal (ClusterIP); port-forwarding lets you reach them locally.

Run each in a separate terminal:

```bash
kubectl port-forward svc/gateway  -n boutique 3001:3001
kubectl port-forward svc/frontend -n boutique 3000:3000
```

Then open:

- Frontend: <http://localhost:3000>
- Gateway:  <http://localhost:3001>

To prove ArgoCD self-heals, delete a deployment and watch it come back:

```bash
kubectl get deployments -n boutique
kubectl delete deployment <name> -n boutique
# ArgoCD recreates it (auto if syncPolicy.automated is set, else Sync in the UI)
kubectl get pods -n boutique
```

---

## 10. Monitoring (Prometheus & Grafana)

**What:** Open the dashboards that show app and cluster metrics.
**Why:** Confirm metrics are flowing and watch service health.

```bash
kubectl get pods -n monitoring
kubectl get svc  -n monitoring

# Run each in a separate terminal:
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
kubectl port-forward svc/kube-prometheus-stack-grafana    -n monitoring 3002:80
```

Open:

- Prometheus: <http://localhost:9090>
- Grafana:    <http://localhost:3002>

Grafana login:

- **User:** `admin`
- **Password:**

  ```bash
  kubectl get secret -n monitoring kube-prometheus-stack-grafana \
    -o jsonpath="{.data.admin-password}" | base64 -d; echo
  ```

In Grafana → **Dashboards**, a pre-built dashboard for the services is already loaded.

---

## 11. Troubleshooting

| Symptom | Cause | Fix |
| ------- | ----- | --- |
| `terraform apply` fails with a 401 / "asked for credentials" | EKS token expired mid-apply | Already fixed via `exec` auth in `main.tf`. Re-run `terraform apply`. |
| Helm: `cannot re-use a name that is still in use` | Release exists but not in TF state | `terraform import 'module.argocd.helm_release.<name>' <namespace>/<release>` |
| Helm: `another operation ... in progress` | Stuck/`pending` release | `helm uninstall <release> -n <ns>` → `terraform state rm ...` → `terraform apply` |
| Monitoring pods stuck `Pending`, "Too many pods" | Node too small | Use `t3.large` + `desired_size: 2` (already set in `terraform.tfvars`). |
| ArgoCD `connection reset by peer` in browser | Browser forcing HTTPS on an HTTP server | Use `http://localhost:8080`; disable HTTPS-First / clear HSTS for `localhost`. |
| Backend pods crash-looping | Database not seeded | Run the restore Job (step 8), then delete the crashed pods. |
| `kubectl`/`helm` → `localhost:8080 connection refused` | No kubeconfig for the cluster | `aws eks update-kubeconfig --name eks-cluster --region ap-south-1` |

---

## Cleanup

When you're done, destroy everything to avoid charges:

```bash
cd projects/Infrastructure
terraform destroy
```
</content>
</invoke>
