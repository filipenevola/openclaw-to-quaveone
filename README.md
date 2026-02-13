# FOC – OpenClaw on Quave Cloud

Deploy [OpenClaw](https://github.com/openclaw/openclaw) to [Quave Cloud](https://quave.cloud) with a single MCP prompt.

## What's Included

- **Dockerfile** – builds OpenClaw from source (Node 22 + Bun + pnpm)
- **docker-entrypoint.cloud.sh** – runtime entrypoint: persistent storage, secret injection, gateway config
- **.env** – your credentials and env-var metadata (git-ignored)

## Prerequisites

1. A **Quave Cloud** account with the [Quave ONE MCP](https://quave.cloud/mcp) connected in Cursor
2. An **OpenClaw Gateway Token** — any strong secret: `openssl rand -hex 32`
3. A **ZAI API Key** from [ZAI](https://zai.gl)
4. *(Optional)* A **Telegram Bot Token** from [@BotFather](https://t.me/BotFather)

## Quick Start

### 1. Fill in `.env`

Edit the `.env` file in this directory with your actual values.
The JSON comments on each line control how the variable is set on Quave Cloud:

```
QUAVE_ONE_ACCOUNT_ID=<your-account-id>
OPENCLAW_GATEWAY_TOKEN=<your-gateway-token>
ZAI_API_KEY=<your-zai-api-key>
TELEGRAM_BOT_TOKEN=<your-telegram-bot-token>
# {"name":"QUAVE_ONE_ACCOUNT_ID","isSecret":false,"type":"DEPLOY"}
# {"name":"OPENCLAW_GATEWAY_TOKEN","isSecret":true,"type":"DEPLOY"}
# {"name":"ZAI_API_KEY","isSecret":true,"type":"DEPLOY"}
# {"name":"TELEGRAM_BOT_TOKEN","isSecret":true,"type":"DEPLOY"}
```

- `isSecret: true` → encrypted at rest, masked in the dashboard
- `type: "DEPLOY"` → available at runtime (`sendToDeploy=true`)
- `QUAVE_ONE_ACCOUNT_ID` is also used in step 1 to select the account

### 2. Run the MCP Prompt

In Cursor, open a new chat with the **Quave ONE MCP** connected.
Attach the `.env` file (`@.env`) and paste the prompt from the section below.

---

## MCP Prompt

```
@.env

Using Quave ONE MCP.

Create and deploy a new app called openclaw on Quave Cloud.
Use only Quave Cloud MCP tools for all steps.
Follow every step below IN ORDER — the ordering is critical.

──────────────────────────────────────────────
PHASE 1 — INFRASTRUCTURE (sequential)
──────────────────────────────────────────────

1. Read the .env file attached above.
   - QUAVE_ONE_ACCOUNT_ID is the account to use.
   - The remaining KEY=VALUE lines are env vars to set later.
   - The JSON comment after each var has its metadata
     (isSecret, type DEPLOY = sendToDeploy true).

2. Set the current account to the QUAVE_ONE_ACCOUNT_ID value.

3. Get the user's current public IP:
   Run `curl -s https://api.ipify.org` in the terminal.

4. Create a new app called "openclaw":
   - port: 18789
   - isCliDeployment: true
   - dockerPreset: "CUSTOM"
   - dockerfilePath: "Dockerfile"

5. Enable persistent storage on the app:
   Update the app with useVolume=true and volumePath="/openclaw".

6. Create a "production" environment in region us-5.

──────────────────────────────────────────────
PHASE 2 — CODE UPLOAD (sequential, must finish before Phase 3)
──────────────────────────────────────────────

IMPORTANT: Quave Cloud CLI deployments require code to be uploaded
BEFORE environment variables, security, or resource settings can be
configured. Do NOT attempt Phase 3 until this phase completes.

7. Prepare and upload the source code:
   a. Remove /tmp/openclaw-deploy if it exists.
   b. Clone https://github.com/openclaw/openclaw.git
      into /tmp/openclaw-deploy.
   c. Copy Dockerfile and docker-entrypoint.cloud.sh from the current
      project directory into /tmp/openclaw-deploy/, overwriting any
      existing files.
   d. Create a .tgz archive from /tmp/openclaw-deploy
      (exclude .git and node_modules).
   e. Request a deploy storage key, upload the archive, then call
      notify-code-upload.
   f. Remove /tmp/openclaw-deploy and the .tgz archive.

──────────────────────────────────────────────
PHASE 3 — CONFIGURE (parallel, all WITHOUT applyImmediately)
──────────────────────────────────────────────

After code upload, set all of the following. Do NOT use
applyImmediately on any of these — just queue them as pending
changes. They will all be applied together in Phase 4.

8. Set the IP allowlist (this one deploys immediately by design):
   - The user's public IP from step 3, description "My current IP",
     deleteEntry "NEVER".
   - 149.154.160.0/20, description "Telegram webhook subnet 1",
     deleteEntry "NEVER".
   - 91.108.4.0/22, description "Telegram webhook subnet 2",
     deleteEntry "NEVER".

9. Set environment variables (do NOT use applyImmediately):
   Read each env var from .env (skip QUAVE_ONE_ACCOUNT_ID if it was
   only used for account selection — but DO still set it as an env var
   if its metadata line is present).
   For each variable, use the JSON metadata comment to determine:
   - isSecret (true/false)
   - sendToDeploy = true (type "DEPLOY")

10. Set security context (do NOT use applyImmediately):
    fsGroup = 1000.

11. Set resources (do NOT use applyImmediately):
    zClouds = 4, disk = 1024 MB.

──────────────────────────────────────────────
PHASE 4 — APPLY & MONITOR (sequential)
──────────────────────────────────────────────

12. Apply all pending changes:
    Call apply-app-env-changes once. This triggers a single
    build + deploy with all configuration included.

13. Monitor the deployment:
    Check the deployment status every 30–60 seconds.
    - Use get-app-env-status and look at currentDeployment.
    - The build (pnpm install + build) takes ~5–10 minutes.
    - If status is BUILDING or DEPLOYING, keep waiting.
    - If it succeeds (isSuccess=true), continue to step 14.
    - If it fails (isFailed=true), check build logs and report
      the error.

14. Print the following:

Your OpenClaw instance is live at: <app URL from hosts>
Your OPENCLAW_GATEWAY_TOKEN: <token value from .env>

Next steps:
1. Open the URL above in your browser
2. Go to "Overview"
3. Paste your gateway token in the token field
4. Configure your providers
```
