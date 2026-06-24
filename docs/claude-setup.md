# Claude Code Setup

This project uses [Claude Code](https://claude.ai/claude-code) — Anthropic's AI coding assistant — as a hands-on tool throughout the DevOps workflow. This document covers how Claude is configured in this project: the `CLAUDE.md` instruction file and the MCP servers that extend its capabilities.

---

## What is Claude Code?

Claude Code is a CLI-based AI assistant that works directly in your terminal and IDE. It can read files, run commands, write code, interact with AWS, manage Kubernetes, and reason about infrastructure — all within your project context.

In this project, Claude Code is used to:
- Assist with Terraform and Kubernetes configuration
- Query EKS clusters and troubleshoot pods
- Interact with AWS services (ECR, EKS, Bedrock, pricing)
- Help write and deploy the AIOps assistant (Kira)

---

## CLAUDE.md — Project Instructions

`CLAUDE.md` is a file at the root of the project that Claude reads automatically at the start of every session. It sets rules and expectations for how Claude should behave within this specific project.

**Current `CLAUDE.md` for this project:**

```
You are operating in safe execution mode.

Before executing any command:
- Before taking any action, briefly explain what you're about to do in 1-2 simple sentences
- Use plain language, avoid jargon
- Say WHY, not just WHAT
- Then proceed with the action

Always prefer clear reasoning before action.
```

### What this does

This instructs Claude to explain its reasoning before taking any action — so you always know what's about to happen and why, rather than commands running silently. This is particularly useful when working with live AWS infrastructure where unintended actions can have real consequences.

### How to customise CLAUDE.md

You can add any project-specific rules. Common examples:

```markdown
# Always use the boutique namespace unless told otherwise
# Never run terraform apply without showing the plan first
# Prefer kubectl over raw AWS CLI for cluster operations
# Branch naming convention: feature/<name>, fix/<name>
```

CLAUDE.md supports nested files too — you can place a `CLAUDE.md` inside any subdirectory and Claude will read it when working in that directory.

---

## MCP Servers

MCP (Model Context Protocol) servers extend Claude's capabilities beyond the built-in tools. They run as background processes and expose additional tools that Claude can call — for AWS operations, Terraform, pricing lookups, and more.

### awslabs.eks-mcp-server

**What it does:** Gives Claude direct access to your EKS clusters and Kubernetes resources without needing `kubectl` installed or configured separately.

**Key capabilities:**
- List and inspect pods, deployments, services, and events across namespaces
- Apply Kubernetes YAML manifests to a cluster
- Stream pod logs and CloudWatch metrics
- Describe EKS cluster config, node groups, and VPC networking
- Troubleshoot using the EKS troubleshooting guide
- Generate application manifests for a given container image

**Example use in this project:**

> "Why is the order-service pod crashing?"

Claude will use this server to check pod events, read logs, and inspect the deployment spec — without you running any kubectl commands manually.

**Setup requirement:** Your AWS credentials must have EKS read permissions. The IAM policy `AmazonEKSClusterPolicy` on your user or role is sufficient for read-only operations.

---

### terraform (HashiCorp official)

**What it does:** Gives Claude access to the Terraform Registry so it can look up provider resource schemas, data sources, and modules. This is HashiCorp's official `terraform-mcp-server`, which replaced the now-yanked `awslabs.terraform-mcp-server`.

It runs as a **Docker container** (`hashicorp/terraform-mcp-server`) rather than via `uvx`.

**Key capabilities:**
- Search AWS and AWSCC provider resource and data-source documentation
- Retrieve full resource schemas and example usage from the Terraform Registry
- Search and inspect public Terraform Registry modules
- Look up provider versions and module details

**Example use in this project:**

> "What Terraform resource do I need to create an EKS node group?"

Claude will search the AWS/AWSCC provider docs in the Registry and return the correct resource schema and example usage.

**Important — what it does NOT do:** Unlike the old AWS Labs server, the HashiCorp server does **not** execute the Terraform CLI (`init`/`plan`/`apply`/`validate`/`destroy`) and does **not** run Checkov security scans. It is a documentation/Registry lookup tool only. To run plans or applies, ask Claude to run the `terraform` CLI directly via its built-in shell (subject to the safe-execution rules in `CLAUDE.md`), and use a dedicated tool such as Checkov for security scanning.

---

### awslabs.aws-pricing-mcp-server

**What it does:** Gives Claude access to live AWS pricing data so it can estimate costs for services before you provision them.

**Key capabilities:**
- Look up pricing for any AWS service (EC2, EKS, Bedrock, Lambda, RDS, etc.)
- Filter by region, instance type, and other attributes
- Generate structured cost analysis reports
- Estimate Bedrock inference costs including Knowledge Base OCU minimums
- Retrieve bulk pricing data for historical analysis

**Example use in this project:**

> "How much will this EKS setup cost per month?"

Claude will query the pricing API for the node instance type, data transfer, and EKS cluster fee, then return a cost breakdown.

> "What does it cost to run the Bedrock Agent daily?"

Claude will look up the Qwen model pricing and factor in the Lambda invocations from the action groups.

---

### aws-documentation

**What it does:** Gives Claude the ability to search and read the official AWS service documentation directly, so answers about AWS services are grounded in current docs rather than training data alone.

**Key capabilities:**
- Search the AWS documentation for any service (EKS, Bedrock, IAM, VPC, etc.)
- Read full documentation pages and return relevant sections
- Get recommendations for related documentation pages

**Example use in this project:**

> "What IAM permissions does the EKS cluster autoscaler need?"

Claude will search the AWS docs and return the exact policy actions, citing the relevant documentation page.

---

### A note on `awslabs.core-mcp-server`

The original setup used `awslabs.core-mcp-server` as an orchestration/proxy layer. **That package has been yanked from PyPI** (AWS Labs retired it in favour of registering each MCP server individually) and no longer installs. Modern Claude Code clients support multi-server configurations natively, so every server above is registered directly. If you still have `awslabs.core-mcp-server` in your config, remove it — it will fail to connect.

---

## Setup Steps

### Step 1 — Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

Verify:

```bash
claude --version
```

Then authenticate:

```bash
claude
```

This opens a browser to log in with your Anthropic account. Once authenticated, you can run `claude` from any directory to start a session.

---

### Step 2 — Configure AWS Credentials

The AWS MCP servers need valid credentials to access your account. If you haven't set this up:

```bash
aws configure
```

You'll be prompted for:
- **AWS Access Key ID** — from your IAM user or role
- **AWS Secret Access Key**
- **Default region** — use the same region as your EKS cluster (e.g. `us-east-1`)
- **Output format** — `json`

Verify it's working:

```bash
aws sts get-caller-identity
```

You should see your account ID, user ID, and ARN returned. If this fails, the AWS MCP servers will not connect.

> If you're using AWS SSO or named profiles, set `AWS_PROFILE` in `~/.claude/settings.json` to match your profile name.

---

### Step 3 — Install uv and Docker

`uv` is the Python package runner that launches the AWS Labs MCP servers (eks, pricing, aws-documentation) automatically. **Docker** is required separately for the HashiCorp `terraform` server, which runs as a container.

Install `uv`:

```bash
# macOS
brew install uv

# Linux (or any externally-managed Python, e.g. PEP 668 systems)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

> On Debian/Ubuntu, `pip install uv` may fail with an "externally-managed-environment" error. Use the `curl` installer above instead. If your shell runs inside a snap (e.g. the VS Code snap), the installer may place `uvx` in a revision-specific path — install to a stable location with `UV_INSTALL_DIR="$HOME/.local/bin" UV_NO_MODIFY_PATH=1` and reference `uvx` by its absolute path in the config below.

Verify:

```bash
uvx --version
docker --version
```

---

### Step 4 — Configure MCP Servers

Create or edit `~/.claude/settings.json` with the following:

```json
{
  "mcpServers": {
    "eks": {
      "command": "uvx",
      "args": ["awslabs.eks-mcp-server@latest"],
      "env": {
        "AWS_REGION": "us-east-1",
        "AWS_PROFILE": "default",
        "FASTMCP_LOG_LEVEL": "ERROR"
      }
    },
    "aws-pricing": {
      "command": "uvx",
      "args": ["awslabs.aws-pricing-mcp-server@latest"],
      "env": {
        "AWS_REGION": "us-east-1",
        "FASTMCP_LOG_LEVEL": "ERROR"
      }
    },
    "aws-documentation": {
      "command": "uvx",
      "args": ["awslabs.aws-documentation-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR"
      }
    },
    "terraform": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "hashicorp/terraform-mcp-server"]
    }
  }
}
```

> Replace `us-east-1` with your AWS region. Replace `default` with your AWS profile name if using named profiles or SSO.
>
> If `uvx` is not on your `PATH` (common inside snap-confined shells), replace `"command": "uvx"` with the absolute path, e.g. `"command": "/home/<you>/.local/bin/uvx"`.
>
> The `terraform` server needs no AWS credentials — it only reads the public Terraform Registry. The old `awslabs.core-mcp-server` and `awslabs.terraform-mcp-server` entries have been removed because those packages were yanked from PyPI.

---

### Step 5 — Install the Terraform Skill

Skills are domain-specific knowledge packs that give Claude deeper context for specific tools. Install the Terraform skill:

```bash
claude skills install terraform-skill
```

This gives Claude richer context for Terraform module patterns, security scanning with Checkov, testing strategies, and CI/CD workflows — beyond what's in its base training.

Verify it installed:

```bash
claude skills list
```

You should see `terraform-skill` listed.

---

### Step 6 — Add CLAUDE.md to the Project

Create a `CLAUDE.md` file at the root of the repository (already present in this project). Claude reads this automatically at the start of every session.

The one used in this project puts Claude in safe execution mode — it must explain what it's doing and why before taking any action. This is especially important when working with live AWS infrastructure.

You can customise it with project-specific rules:

```markdown
# Always use the boutique namespace unless told otherwise
# Never run terraform apply without showing the plan first
# Branch naming: feature/<name>, fix/<name>
```

---

## Verifying the Setup

Start a Claude Code session:

```bash
claude
```

Check which MCP servers are connected:

```
/mcp
```

You should see all four servers (`eks`, `aws-pricing`, `aws-documentation`, `terraform`) listed as `connected`. If any show as `failed`:

| Problem | Fix |
|---------|-----|
| AWS server shows `failed` | Run `aws sts get-caller-identity` to verify credentials |
| Wrong region errors | Update `AWS_REGION` in `~/.claude/settings.json` |
| `uvx: command not found` | Install `uv` (see Step 3) and/or use the absolute path to `uvx` in the config |
| `terraform` server `failed` | Ensure Docker is running (`docker ps`); first run pulls `hashicorp/terraform-mcp-server` |
| Server times out on first use | Normal — `uvx` downloads the server on first run, retry after ~30s |
| `All versions ... were yanked` error | You're referencing a retired package (`core`/`terraform` AWS Labs servers); use the config in Step 4 |

---

## How Claude Uses These Tools in This Project

| Task | MCP Server Used |
|------|----------------|
| Check pod logs / health | `eks` |
| Apply k8s manifests | `eks` |
| Cluster and node group info | `eks` |
| Search Terraform provider/module docs | `terraform` (HashiCorp) |
| Run terraform plan/apply | Built-in shell (`terraform` CLI) — not an MCP server |
| Search AWS service documentation | `aws-documentation` |
| Estimate infrastructure cost | `aws-pricing` |
| Bedrock agent cost analysis | `aws-pricing` |
