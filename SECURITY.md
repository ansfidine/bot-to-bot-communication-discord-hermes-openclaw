# Security Best Practices

## Token Management

### Rule 1: Never Share Tokens in Group Chats

If a token is posted in any group channel (Discord, Slack, etc.), consider it **immediately compromised**.

**Response protocol:**
1. Revoke the token at the provider (GitHub, Discord, etc.)
2. Generate a new token
3. Share the new token via **DM only** or a password manager
4. Document the incident

### Rule 2: Use Placeholder Values in Code

All configuration files in this repo use placeholder values:
```yaml
token: "YOUR_DISCORD_BOT_TOKEN_HERE"  # NEVER put real tokens here
```

### Rule 3: Environment Files

```bash
# Create .env with restricted permissions
echo "DISCORD_TOKEN=your_real_token" > ~/.openclaw/.env
chmod 600 ~/.openclaw/.env

# Add to .gitignore
echo ".env" >> .gitignore
echo "*.env" >> .gitignore
```

### Rule 4: macOS Keychain

```bash
# Store a token in Keychain
security add-generic-password -a "openclaw" -s "discord-token" -w "your_token"

# Retrieve a token from Keychain
security find-generic-password -a "openclaw" -s "discord-token" -w
```

### Rule 5: Fine-Grained GitHub Tokens

- Use **fine-grained PATs** with minimum permissions
- Set **expiration dates** (30 days max for daily use)
- Scope tokens to **specific repositories** only
- Use **deploy keys** for automated systems

## Bot-to-Bot Security

### allowBots: "mentions" Only

Never use `allowBots: "all"` — this can cause:
- Infinite response loops between bots
- Unintended data leakage between agent contexts
- Resource exhaustion from uncontrolled message volume

### Channel Isolation

Keep bot communication in **designated channels only**:
```yaml
discord:
  channels:
    - "bot-communication-channel-id"
```

### Message Content Awareness

Both bots can see all messages in shared channels. Never include:
- API keys or tokens
- Database credentials
- Internal system details
- Personal information

If sensitive info must be discussed, use **DM channels** instead.

## Incident Response

### Token Exposed in Chat

1. **Immediate:** Revoke the token
2. **Within 5 min:** Generate replacement token
3. **Within 10 min:** Update all services with new token
4. **Document:** What was exposed, how long, who saw it

### Bot Sending Sensitive Data

1. **Immediate:** Delete the message if possible
2. **Notify:** Alert the channel admin
3. **Fix:** Update agent guardrails to prevent recurrence
4. **Document:** What was exposed and why

## .gitignore Template

```
.env
.env.*
*.token
*.key
*.secret
credentials.json
auth.json
config.local.yaml
```
