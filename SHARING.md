# Sharing PR Review Light with Colleagues 👥

This guide helps you distribute PR Review Light to your teammates.

## Quick Share Methods

### Method 1: Share Source Code (Recommended)
```bash
# Create a clean copy for sharing
git init
git add .
git commit -m "Initial PR Review Light implementation"

# Share via GitHub, email, or file sharing
zip -r PRReviewLight-source.zip . -x "*.build*" "*/.DS_Store*"
```

**Your colleagues run:**
```bash
cd PRReviewLight
./install.sh
```

### Method 2: Share Built App Bundle
```bash
# Build the app bundle
./install.sh

# Share the app bundle (they drag to Applications)
zip -r PRReviewLight-app.zip PRReviewLight.app
```

### Method 3: Direct Installation Help
Help colleagues install by walking them through:

1. **Get the code**: Share the PRReviewLight folder
2. **Run installer**: `cd PRReviewLight && ./install.sh`
3. **Set up token**: Launch app → Settings → Enter GitHub token
4. **Done**: Orange warning triangle appears when reviews needed!

## Setup Instructions for Colleagues

### Prerequisites
- macOS 13.0 or later
- Xcode Command Line Tools: `xcode-select --install`

### GitHub Token Setup
1. Go to [GitHub Personal Access Tokens](https://github.com/settings/tokens)
2. Generate new token (classic) with:
   - ✅ `repo` - Full control of private repositories
   - ✅ `read:user` - Read access to profile info
3. Copy the token (starts with `ghp_`)

### Installation
```bash
# Extract and install
cd PRReviewLight
./install.sh

# Launch from Applications or:
open /Applications/PRReviewLight.app
```

### Configuration
1. App appears in menu bar (checkmark when no reviews)
2. Click menu bar icon → **Settings**
3. Paste GitHub token → **Save** → **Test Connection**
4. Should show "✅ Connected as [username]"

## Features Overview

### Menu Bar Icons
- ✅ **Green checkmark**: No pending reviews
- ⚠️ **Orange warning triangle (pulsing)**: Reviews needed!

### Functionality
- **Auto-check**: Every 5 minutes for new review requests
- **Instant check**: When token is saved
- **Snooze**: Hide specific PRs for 1 hour
- **Direct access**: Click PR to open in browser
- **Secure**: Tokens encrypted in macOS keychain

## Troubleshooting

### "No reviews showing"
- Check GitHub token has correct permissions
- Verify token works with Test Connection
- Make sure you actually have pending review requests

### "Can't paste token"
- Use Cmd+V to paste in the token field
- Or right-click → Paste
- Field shows dots for security

### "App won't start"
- Make sure macOS 13.0+
- Install Command Line Tools: `xcode-select --install`
- Check Console.app for error messages

## Customization

Colleagues can modify the code if needed:
- `PRReviewLight.swift` - Main app logic
- `SettingsWindow.swift` - Settings UI
- `GitHubService.swift` - GitHub API calls
- Change polling interval (default: 5 minutes)
- Adjust notification behavior

## Security Notes

- ✅ Tokens stored in macOS keychain (encrypted)
- ✅ No network logging of sensitive data
- ✅ Only connects to GitHub API
- ✅ Open source - review the code yourself

## Support

Common solutions:
1. **Restart app**: Quit from menu → relaunch
2. **Reset settings**: Delete keychain entry and reconfigure
3. **Check logs**: Look at Console.app for error messages
4. **Verify API**: Test token at https://api.github.com/user

Perfect for dev teams who want to stay on top of code reviews! 🚀