# PR Review Light

A macOS menu bar app that monitors GitHub PR review requests and shows a visual indicator when you have pending reviews.

## Setup

1. **Build**: Run `./build.sh` to create the app
2. **GitHub Token**: Generate a personal access token with `repo` and `read:user` scopes
3. **Configure**: Launch the app and enter your token in Settings

## Features

- Menu bar icon with badge showing pending review count
- Click to see PR list and open in browser
- Auto-refreshes every minute
- Snooze functionality (Option+click PR)

Built with Swift Package Manager for macOS 13.0+.