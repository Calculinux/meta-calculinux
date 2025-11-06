# Discord Notification Setup

This repository supports automatic Discord notifications when new Calculinux builds are published. Follow these steps to configure Discord webhooks.

## Prerequisites

1. A Discord server where you want to receive notifications
2. Administrative permissions to create webhooks on that server

## Setting Up Discord Webhook

### Step 1: Create a Discord Webhook

1. Open Discord and navigate to your server
2. Go to **Server Settings** > **Integrations** > **Webhooks**
3. Click **Create Webhook**
4. Configure the webhook:
   - **Name**: `Calculinux Build Bot` (or any name you prefer)
   - **Channel**: Select the channel where you want build notifications
   - **Avatar**: Optionally upload a Calculinux logo
5. Click **Copy Webhook URL** and save it securely

### Step 2: Add the Webhook URL to GitHub Repository Secrets

1. Navigate to your GitHub repository
2. Go to **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. Set:
   - **Name**: `DISCORD_WEBHOOK_URL`
   - **Secret**: Paste the Discord webhook URL you copied
5. Click **Add secret**

## Notification Behavior

The Discord bot will send notifications for:

### ✅ Notifications Sent For:
- **Stable Releases** (tags like `v1.0.0`) - Green embed
- **Release Candidates** (tags like `v1.0.0-rc1`) - Gray embed  
- **Beta Releases** (tags like `v1.0.0-beta1`) - Orange embed
- **Alpha Releases** (tags like `v1.0.0-alpha1`) - Yellow embed

### ❌ No Notifications For:
- Main branch builds (continuous stable)
- Develop branch builds (development)
- Pull request builds
- Failed builds
- Builds from other branches

## Notification Content

Each notification includes:

- **Build Type**: Release, Beta, Alpha, or RC
- **Version**: Tag name (e.g., v1.0.0, v1.0.0-alpha1)
- **Target Device**: Currently `luckfox-lyra`
- **Download Links**:
  - Full disk image (`.wic.gz`)
  - Update bundle (`.raucb`)
  - Package feed URL
- **Direct link** to the GitHub release page

## Example Notifications

### Stable Release
```
🚀 New Calculinux Stable Release Available!
A new Calculinux build has been published for luckfox-lyra

📋 Version: v1.0.0
🏷️ Build Type: Stable Release  
💻 Target Device: luckfox-lyra
📥 Downloads:
📱 Full Image: calculinux-image-luckfox-lyra.rootfs-v1.0.0.wic.gz
🔄 Update Bundle: calculinux-bundle-luckfox-lyra-v1.0.0.raucb
📦 Package Feed: Browse packages
```

### Alpha Release
```
🚀 New Calculinux Alpha Release Available!
A new Calculinux build has been published for luckfox-lyra

📋 Version: v1.0.0-alpha1
🏷️ Build Type: Alpha Release
💻 Target Device: luckfox-lyra
📥 Downloads: [...]
```

**Note**: Continuous builds (main/develop branches) do not trigger Discord notifications to avoid spam. Only tagged releases are announced.

## Troubleshooting

### No Notifications Received

1. **Check webhook URL**: Ensure `DISCORD_WEBHOOK_URL` secret is correctly set
2. **Verify channel permissions**: Make sure the webhook has permission to post
3. **Check build logs**: Look for Discord notification step in GitHub Actions
4. **Test webhook**: Send a test message using a tool like `curl`

### Test Webhook Manually

```bash
curl -H "Content-Type: application/json" \
  -d '{"content": "Test message from Calculinux build system"}' \
  YOUR_WEBHOOK_URL_HERE
```

### Build Failed But No Error Notification

This is expected behavior. The Discord notification only triggers on successful builds to avoid spam during development.

## Security Notes

- **Keep webhook URLs private**: Anyone with the URL can send messages to your channel
- **Use repository secrets**: Never commit webhook URLs to version control
- **Limit webhook permissions**: Create webhooks in dedicated channels if possible
- **Monitor webhook usage**: Discord has rate limits for webhook usage

## Customization

To modify notification behavior, edit the "Send Discord notification" step in `.github/workflows/build.yml`:

- **Change colors**: Modify the `COLOR` values (decimal color codes)
- **Add fields**: Add more fields to the embed JSON
- **Change triggers**: Modify the `if` condition on the notification step
- **Customize messages**: Update the embed title, description, or field content

## Support

If you encounter issues:

1. Check the [GitHub Actions logs](../../actions) for detailed error messages
2. Verify your Discord webhook URL is correct
3. Test the webhook manually using the curl command above
4. Join our [Discord community](https://discord.gg/7quBbSPxcP) for help
