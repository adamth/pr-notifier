# PR Review Light ⚠️

A macOS menu bar application that monitors your GitHub pull request review requests and displays a visual indicator when you have pending reviews.

**Never miss a code review again!** 🚀

## Features

- ⚠️ **Eye-Catching Alert**: Animated orange warning triangle when reviews needed
- ✅ **Peace of Mind**: Green checkmark when you're all caught up
- 📋 **PR List**: Click the menu bar icon to see all pending reviews
- 🔗 **Quick Access**: Click any PR to open it directly in your browser
- 💤 **Snooze**: Temporarily dismiss review notifications for 1 hour
- 🔄 **Auto-refresh**: Checks for new reviews every minute
- ⚡ **Real-time Updates**: Light automatically turns off when reviews are completed

## Setup

### 1. GitHub Personal Access Token

You'll need a GitHub Personal Access Token with appropriate permissions:

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate a new token with these scopes:
   - `repo` (Full control of private repositories)
   - `read:user` (Read access to profile info)

### 2. Set Environment Variable

Set your GitHub token as an environment variable:

```bash
export GITHUB_TOKEN="your_personal_access_token_here"
```

To make this permanent, add it to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.):

```bash
echo 'export GITHUB_TOKEN="your_personal_access_token_here"' >> ~/.zshrc
source ~/.zshrc
```

### 3. Install and Run

```bash
cd PRReviewLight
./install.sh
```

The app will be installed to `/Applications/PRReviewLight.app` and you can launch it from there, or it will start automatically.

## Usage

### Menu Bar Icon
- 🟠 **Orange Code Symbol**: Consistent icon that shows your review status
  - **With Red Badge (Pulsing)**: Shows pending review count - time to review!
  - **Grayed Out**: No pending reviews - you're all caught up!

### Menu Options
- **PR Titles**: Click to open in browser
- **Snooze**: Hold Option key and click a PR to snooze for 1 hour
- **Check Now**: Manually refresh pending reviews
- **Settings**: View token configuration info
- **Quit**: Exit the application

### Automatic Behavior
- Checks GitHub every minute for new review requests
- Light turns off automatically when reviews are completed
- Snoozed reviews are temporarily hidden from the indicator
- App remembers snooze state until reviews are completed or 1 hour passes

## Troubleshooting

### No Reviews Showing
1. Verify your `GITHUB_TOKEN` environment variable is set
2. Check that your token has the correct scopes (`repo`, `read:user`)
3. Ensure you actually have pending review requests on GitHub

### Permission Errors
- Make sure your GitHub token has access to the repositories where you're requested as a reviewer
- For private repositories, ensure the `repo` scope is enabled

### Network Issues
- The app will show error dialogs if it can't connect to GitHub
- Check your internet connection and GitHub API status

## Distribution

### Creating Signed DMG (Recommended)

For distribution to colleagues without security warnings:

1. **Get Apple Developer Certificate** (one-time setup):
   ```bash
   ./setup-signing.sh  # Check current status and get instructions
   ```

2. **Create signed DMG**:
   ```bash
   ./create-dmg.sh     # Creates PRReviewLight-v1.0.dmg
   ```

### Unsigned Distribution (Default)

The build script creates an unsigned DMG that works on all machines with a simple security override:

```bash
./create-dmg.sh     # Creates PRReviewLight-v1.0.dmg
```

### For Colleagues - Installing the App

When you receive `PRReviewLight-v1.0.dmg`:

1. **Download and mount**: Double-click the DMG file
2. **Install**: Drag "PR Review Light.app" to the Applications folder
3. **First launch**: Right-click the app → "Open" → "Open" (bypasses security warning)
   - You'll see "Cannot verify developer" - click "Open" anyway
   - This is only needed once per machine
4. **Setup**: Configure your GitHub token in the app's Settings

**Alternative security bypass methods**:
- Terminal: `xattr -dr com.apple.quarantine "/Applications/PR Review Light.app"`
- System Preferences → Security & Privacy → "Allow anyway" (appears after first launch attempt)

## Development

The app consists of two main components:
- `PRReviewLight.swift`: Main application with menu bar interface
- `GitHubService.swift`: GitHub API integration for fetching review requests

### Build Scripts
- `build.sh`: Basic Swift build
- `create-dmg.sh`: Creates professional DMG installer with code signing
- `setup-signing.sh`: Helps configure Apple Developer certificates

Built with Swift Package Manager and requires macOS 13.0 or later.