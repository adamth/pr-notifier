# PR Review Light - Installation Instructions

## For Colleagues Receiving the DMG

### Quick Install (3 steps):

1. **Mount the DMG**: Double-click `PRReviewLight-v1.0.dmg`

2. **Install the app**: Drag "PR Review Light.app" to the Applications folder

3. **First launch**: Right-click the app in Applications → "Open" → "Open"
   - You'll see "Cannot verify developer"
   - Click "Open" anyway (this is normal for unsigned apps)
   - Only needed once per machine

4. **Setup**: Click the menu bar icon → Settings → Add your GitHub token

---

## Why the Security Warning?

This app is unsigned (to avoid $99/year Apple Developer fee). macOS shows warnings for unsigned apps as a security measure. The app is safe - you're just bypassing the signature check.

## Alternative Security Bypass

If right-click → Open doesn't work:

**Option 1**: Terminal command
```bash
xattr -dr com.apple.quarantine "/Applications/PR Review Light.app"
```

**Option 2**: System Preferences
1. Try to launch the app normally (it will fail)
2. Go to System Preferences → Security & Privacy
3. Click "Allow anyway" next to the blocked app message
4. Launch the app again

---

## GitHub Token Setup

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with scopes: `repo` and `read:user`
3. Copy the token
4. In PR Review Light: Click menu bar icon → Settings → Paste token → Save

That's it! The app will now monitor your GitHub review requests and show alerts in the menu bar.