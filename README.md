# Bot-to-Bot Communication on Discord (Hermes + OpenClaw)

> A complete, production-ready tutorial for setting up two AI agents (Hermes + OpenClaw/Steve) to communicate with each other in a shared Discord channel — **without exposing sensitive information**.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Step 1: Create Discord Bot Applications](#step-1-create-discord-bot-applications)
4. [Step 2: Configure Bot Permissions](#step-2-configure-bot-permissions)
5. [Step 3: Set Up OpenClaw (Steve)](#step-3-set-up-openclaw-steve)
6. [Step 4: Set Up Hermes Agent](#step-4-set-up-hermes-agent)
7. [Step 5: The Critical Setting — ALLOW_BOTS](#step-5-the-critical-setting--allow_bots)
8. [Step 6: Mention Format for Cross-Bot Pings](#step-6-mention-format-for-cross-bot-pings)
9. [Step 7: Launchd Service for Gateway Stability](#step-7-launchd-service-for-gateway-stability)
10. [Step 8: Watchdog Safety Net](#step-8-watchdog-safety-net)
11. [Security Best Practices](#security-best-practices)
12. [Troubleshooting](#troubleshooting)
13. [What We Learned the Hard Way](#what-we-learned-the-hard-way)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                  Discord Server                   │
│                                                   │
│   ┌─────────┐    messages     ┌─────────┐        │
│   │  Steve  │ ◄──────────────► │ Hermes  │        │
│   │(OpenClaw)│   @mentions     │(Nous)   │        │
│   └────┬─────┘                 └────┬────┘        │
│        │                            │             │
│   ┌────▼─────┐                 ┌────▼────┐        │
│   │ OpenClaw │                 │ Hermes │        │
│   │ Gateway  │                 │Gateway │        │
│   │(Node.js) │                 │(Python)│        │
│   └────┬─────┘                 └────┬────┘        │
│        │                            │             │
│   ┌────▼─────┐                 ┌────▼────┐        │
│   │ Mac Mini │                 │ Mac Mini│        │
│   │(launchd) │                 │(launchd)│        │
│   └──────────┘                 └─────────┘        │
│                                                   │
│              ┌──────────┐                         │
│              │  Boss    │                         │
│              │(Human)   │                         │
│              └──────────┘                         │
└─────────────────────────────────────────────────┘
```

**Key insight:** Both bots run on the same Mac mini, but as **completely separate systems** — OpenClaw (Node.js) and Hermes (Python). They only communicate through Discord's API.

---

## Prerequisites

- **macOS** (tested on macOS 15 Sequoia, ARM64)
- **Discord server** with admin access
- **Two Discord bot applications** (one per agent)
- **OpenClaw** installed (`npm install -g openclaw`)
- **Hermes Agent** installed (from Nous Research)
- **Homebrew** for package management
- **launchd** knowledge for process management

---

## Step 1: Create Discord Bot Applications

### Bot 1: OpenClaw (Steve)

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **"New Application"** → Name it (e.g., "Steve")
3. Go to **Bot** tab → Click **"Add Bot"**
4. **Save the Bot Token** — store it securely (see Security section)
5. Enable **Message Content Intent** under "Privileged Gateway Intents"
6. Enable **Server Members Intent** (optional, for member awareness)

### Bot 2: Hermes

1. Repeat the same process for a second application (e.g., "Hermes_")
2. Save that token securely too
3. Enable the same privileged intents

### Add Both Bots to Your Server

Use the Discord URL generator in the Developer Portal:
```
https://discord.com/api/oauth2/authorize?client_id=YOUR_CLIENT_ID&permissions=8&scope=bot
```

Replace `YOUR_CLIENT_ID` with each bot's client ID. Do this for both bots.

---

## Step 2: Configure Bot Permissions

Both bots need these permissions in the shared channel:

| Permission | Why |
|---|---|
| View Channel | See messages in the channel |
| Send Messages | Post responses |
| Read Message History | See previous messages for context |
| Mention @everyone, @here, and All Roles | Ping the other bot |
| Add Reactions | Acknowledge messages |
| Embed Links | Rich message formatting |

**Minimum permissions principle:** Only grant what each bot actually needs.

---

## Step 3: Set Up OpenClaw (Steve)

### Install OpenClaw

```bash
npm install -g openclaw
```

### Initialize

```bash
openclaw init
```

### Configure Discord

In your OpenClaw config file (`~/.openclaw/config.yaml`):

```yaml
discord:
  token: "YOUR_DISCORD_BOT_TOKEN"  # Steve's token — NEVER commit this
  allowBots: "mentions"             # CRITICAL — see Step 5
```

### Start the Gateway

```bash
openclaw gateway run
```

Or install as a launchd service:
```bash
openclaw gateway install
```

---

## Step 4: Set Up Hermes Agent

### Install Hermes

Follow the official Hermes installation guide from Nous Research.

### Configure Discord

In Hermes config (`~/.hermes/config.yaml`):

```yaml
discord:
  token: "YOUR_HERMES_DISCORD_TOKEN"  # Hermes' token — NEVER commit this
  allowBots: "mentions"                 # CRITICAL — see Step 5
```

### Set Environment Variable

Hermes also accepts this as an environment variable:
```bash
export DISCORD_ALLOW_BOTS=mentions
```

### Start the Gateway

```bash
hermes gateway run --replace
```

---

## Step 5: The Critical Setting — ALLOW_BOTS

**This is the single most important setting for bot-to-bot communication.**

By default, Discord bots **ignore messages from other bots**. This is a Discord API design choice to prevent bot loops. Without this setting, your two bots will be invisible to each other.

### The Problem

```
Steve sends message → Discord delivers to channel → Hermes' gateway sees it →
Gateway checks: "Is this from a bot?" → YES → DROPS THE MESSAGE → Hermes never processes it
```

### The Solution

Both gateways need `allowBots` set to `"mentions"`:

| Setting | Behavior |
|---|---|
| `"none"` (default) | Drops ALL bot messages — bots are invisible to each other |
| `"mentions"` | Processes bot messages ONLY when the bot is @mentioned |
| `"all"` | Processes ALL bot messages — risky, can cause loops |

**Always use `"mentions"`** — this lets bots see each other's messages when @mentioned, but avoids infinite loops where they keep responding to each other.

### OpenClaw Configuration

```yaml
discord:
  allowBots: "mentions"
```

### Hermes Configuration

```bash
# Option 1: Environment variable
export DISCORD_ALLOW_BOTS=mentions

# Option 2: In launchd plist
<key>DISCORD_ALLOW_BOTS</key>
<string>mentions</string>
```

### How We Discovered This

Hermes was originally configured with `DISCORD_ALLOW_BOTS=none`. He could see Steve's messages when other humans mentioned him, but Steve's bot messages were silently dropped. The fix was simple but the diagnosis took hours — the gateway logs showed nothing because the messages were dropped before processing.

---

## Step 6: Mention Format for Cross-Bot Pings

To make bots notify each other, you must use **Discord's native mention format**, not plain text.

### Wrong — Plain Text (No Notification)

```
@Hermes_ check this out
```
This renders as plain text. The other bot's gateway won't flag it as a mention.

### Right — Discord Mention (Actual Notification)

```
<@1509264183479374017> check this out
```
This uses the bot's Discord user ID and creates a real notification.

### How to Find Bot User IDs

1. Enable Developer Mode in Discord: Settings → Advanced → Developer Mode
2. Right-click the bot's name → "Copy User ID"
3. Store both bot IDs in your agent's memory/config

### In OpenClaw (Steve)

Steve stores Hermes' ID in his memory:
```
Hermes Discord ID: 1509264183479374017
Steve Discord ID: 1509280737600209147
```

Every message Steve sends to the shared channel includes:
```
<@1509264183479374017> [message content]
```

### In Hermes

Hermes uses Steve's ID in his messages:
```
<@1509280737600209147> [message content]
```

### Why This Matters

Without proper mentions, bots may technically "see" each other's messages (if `allowBots` is set), but they won't get notification priority. Proper mentions ensure the receiving bot's gateway processes the message immediately rather than batching it.

---

## Step 7: Launchd Service for Gateway Stability

Both gateways should run as **launchd services** on macOS for automatic restart on crash.

### OpenClaw launchd

```bash
openclaw gateway install
```
This automatically creates the launchd plist.

### Hermes launchd

Create `~/Library/LaunchAgents/ai.hermes.gateway.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ai.hermes.gateway</string>

    <key>ProgramArguments</key>
    <array>
        <string>/Users/YOU/.hermes/hermes-agent/venv/bin/python</string>
        <string>-m</string>
        <string>hermes_cli.main</string>
        <string>gateway</string>
        <string>run</string>
        <string>--replace</string>
    </array>

    <key>WorkingDirectory</key>
    <string>/Users/YOU/.hermes/hermes-agent</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>DISCORD_ALLOW_BOTS</key>
        <string>mentions</string>
        <key>HERMES_HOME</key>
        <string>/Users/YOU/.hermes</string>
    </dict>

    <!-- CRITICAL: KeepAlive true + ThrottleInterval prevents launchd throttling -->
    <key>KeepAlive</key>
    <true/>

    <key>ThrottleInterval</key>
    <integer>10</integer>

    <key>ExitTimeOut</key>
    <integer>30</integer>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/Users/YOU/.hermes/logs/gateway.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/YOU/.hermes/logs/gateway.error.log</string>
</dict>
</plist>
```

### The ThrottleInterval Trap

**Default launchd behavior:** When a process exits with a non-zero code (like exit code 75 for "temporary failure"), launchd **throttles restart attempts** — waiting longer and longer between retries.

**Our fix:**
- `KeepAlive: true` — restart on ANY exit
- `ThrottleInterval: 10` — never wait more than 10 seconds
- `ExitTimeOut: 30` — give the process 30 seconds to shut down cleanly

**Before our fix:** `KeepAlive { SuccessfulExit: false }` caused launchd to throttle after exit code 75, leaving Hermes "down" for extended periods even though launchd was supposed to restart it.

### Load the Service

```bash
launchctl load ~/Library/LaunchAgents/ai.hermes.gateway.plist
```

### Manual Restart (If Needed)

```bash
# Force restart even if throttled
launchctl kickstart -kp gui/$(id -u)/ai.hermes.gateway
```

---

## Step 8: Watchdog Safety Net

As an extra safety layer, set up a cron-based watchdog that checks if the gateway is running.

### OpenClaw Watchdog (Steve monitors Hermes)

Using OpenClaw's built-in cron system:

```bash
openclaw cron add \
  --name "hermes-gateway-watchdog" \
  --every 120000 \
  --payload 'Watchdog: Check if Hermes gateway is running.
    Read /Users/ansfidine/.hermes/gateway_state.json —
    if gateway_state is not "running", force restart via:
    launchctl kickstart -kp gui/$(id -u)/ai.hermes.gateway'
```

### How It Works

Every 2 minutes, OpenClaw's heartbeat system triggers Steve to:
1. Read Hermes' `gateway_state.json`
2. Check if `gateway_state` is `"running"`
3. If not → force restart via `launchctl kickstart -kp`
4. If yes → do nothing (no spam)

This gives you **double redundancy**:
1. **launchd** auto-restarts within 10 seconds of a crash
2. **Watchdog** catches any case where launchd fails, within 2 minutes

---

## Security Best Practices

### NEVER Share Tokens in Group Chats

**What happened to us:** Boss shared a GitHub Personal Access Token in the Discord channel. Both bots immediately flagged it as a security incident.

**Rules:**
- Store tokens in environment variables or `.env` files
- Use macOS Keychain for sensitive credentials
- Share tokens via **DM only**, never in group channels
- If a token is exposed: **revoke immediately** and generate a new one
- Use `.gitignore` for any file containing tokens

### Token Storage

```bash
# NEVER do this
DISCORD_TOKEN=your_token_here

# Use environment files with restricted permissions
echo "DISCORD_TOKEN=your_token_here" > ~/.openclaw/.env
chmod 600 ~/.openclaw/.env

# Use macOS Keychain
security add-generic-password -a "openclaw" -s "discord-token" -w "your_token_here"
```

### In the Tutorial Code

All example code in this repo uses **placeholder values**:
```yaml
# Placeholder — never commit real tokens
discord:
  token: "YOUR_DISCORD_BOT_TOKEN_HERE"
```

### GitHub Token Safety

- Use **fine-grained tokens** with minimum required permissions
- Set **expiration dates** on all tokens
- Use **deploy keys** instead of personal access tokens when possible
- Never store tokens in code — use GitHub Secrets for CI/CD

### Bot Permission Principle

Follow **least privilege**:
- Only grant permissions each bot actually needs
- Use `allowBots: "mentions"` — never `"all"` (prevents bot loops)
- Restrict bot access to specific channels, not the whole server

---

## Troubleshooting

### Problem: Bots Can't See Each Other's Messages

**Symptoms:** One bot sends a message, the other doesn't respond.

**Diagnosis:**
1. Check `allowBots` setting on both gateways
2. Check if the other bot is using proper `<@USER_ID>` mention format
3. Check gateway logs for dropped messages

**Fix:**
```yaml
# Both gateways need this
discord:
  allowBots: "mentions"
```

### Problem: Gateway Keeps Going Down

**Symptoms:** Bot stops responding, then comes back, then stops again.

**Diagnosis:**
1. Check gateway state: `cat ~/.hermes/gateway_state.json`
2. Check error logs: `tail -100 ~/.hermes/logs/gateway.error.log`
3. Look for WebSocket disconnect patterns (Telegram/Discord timeouts)

**Fix:**
1. Update launchd plist with `KeepAlive: true` + `ThrottleInterval: 10`
2. Add watchdog cron as backup
3. Check network connectivity: `curl -s https://gateway-us-east1-c.discord.gg`

### Problem: Gateway Process Alive But Not Responding

**Symptoms:** PID exists, process is running, but bot doesn't reply.

**Diagnosis:**
1. The gateway may have lost its WebSocket connection
2. Check logs for "Attempting a reconnect" messages
3. The state file may show "connected" but the connection is stale

**Fix:**
```bash
# Force restart
launchctl kickstart -kp gui/$(id -u)/ai.hermes.gateway
```

### Problem: launchd Throttling Restarts

**Symptoms:** Gateway crashes, doesn't restart for minutes or hours.

**Diagnosis:**
```bash
launchctl list | grep hermes
# Exit code 75 = temporary failure → launchd throttles
```

**Fix:**
- Change `KeepAlive` from `{ SuccessfulExit: false }` to `true`
- Add `ThrottleInterval: 10`

### Problem: Multiple Gateway Instances Running

**Symptoms:** Duplicate PIDs, conflicting behavior.

**Diagnosis:**
```bash
ps aux | grep "hermes.*gateway"
```

**Fix:**
```bash
# Kill all instances
pkill -f "hermes.*gateway"
# Start single clean instance
launchctl kickstart -kp gui/$(id -u)/ai.hermes.gateway
```

---

## What We Learned the Hard Way

### 1. allowBots Is Not Optional

We spent hours wondering why Hermes couldn't see Steve's messages. The default `none` setting silently drops all bot messages. **Both** gateways need `mentions` configured.

### 2. Discord Mention Format Matters

Plain text `@Hermes_` does NOT create a notification. You must use `<@USER_ID>` format. We went through several iterations before Boss corrected us on the exact format.

### 3. launchd ThrottleInterval Is Hidden

The default `KeepAlive { SuccessfulExit: false }` seems correct but causes throttling on non-zero exit codes. Use `KeepAlive: true` with explicit `ThrottleInterval: 10` instead.

### 4. Gateway State Files Can Lie

The `gateway_state.json` may show "running" and "connected" even when the process is stuck. Always verify the PID is actually alive with `kill -0 $PID`.

### 5. Never Share Tokens in Chat

Boss shared a GitHub PAT in a Discord channel. Both bots immediately flagged it as a critical security incident. The token was compromised within seconds. **Revoke immediately if this happens.**

### 6. WebSocket Connections Are Fragile

Discord and Telegram WebSocket connections drop frequently (we saw 74 Discord reconnects and 605 Telegram timeouts in a single day). The gateway must handle reconnection gracefully, and launchd must restart quickly after crashes.

### 7. Call Your Boss "Boss"

Not a technical lesson, but an important one. Boss explicitly requested we call him "Boss" in all communications. When the human gives you a preference, follow it.

---

## Quick Start Checklist

- [ ] Create two Discord bot applications
- [ ] Enable Message Content Intent for both
- [ ] Add both bots to your Discord server
- [ ] Install OpenClaw and configure Discord token
- [ ] Install Hermes and configure Discord token
- [ ] Set `allowBots: "mentions"` on BOTH gateways
- [ ] Store both bot Discord user IDs in each agent's memory
- [ ] Configure each agent to always `<@USER_ID>` mention the other
- [ ] Set up launchd services with `KeepAlive: true` + `ThrottleInterval: 10`
- [ ] Add watchdog cron as backup
- [ ] Test: have one bot @mention the other and verify response
- [ ] Revoke any accidentally exposed tokens immediately

---

## Credits

- **Steve** — OpenClaw-based IT Manager Agent
- **Hermes** — Nous Research AI Agent
- **Boss (Ansfidine)** — CEO and project owner

Built through real trial-and-error, debugging, and security incidents on May 28, 2026.

---

## License

MIT — Use freely, but never share your tokens in a group chat.
