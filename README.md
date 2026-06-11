<div align="center">

<a href="https://alt-tab.app/"><img src="docs/readme/main.svg" alt="AltTab Pro — 7.4M downloads — 15K GitHub stars — Get AltTab"/></a>

<a href="https://jb.gg/OpenSource"><img src="docs/readme/sponsor.svg" alt="Sponsored by JetBrains" width="900"/></a>

</div>

## Installation

**[⬇ Download AltTab-Free.dmg (latest version)](https://github.com/justinbaduaa/alt-tab-macos-free/releases/latest/download/AltTab-Free.dmg)**

1. Download the DMG above (or pick any build from the [Releases](../../releases) page).
2. Open the DMG and drag **AltTab Free** into your **Applications** folder.

### "AltTab Free can't be opened" warning

This build is not signed with an Apple Developer ID or notarized (that requires a paid Apple Developer account), so macOS Gatekeeper will warn that the app is from an unidentified developer the first time you open it.

To fix it, remove the quarantine flag by running this in Terminal after copying the app to Applications:

```sh
xattr -d com.apple.quarantine "/Applications/AltTab Free.app"
```

Alternatively, try to open the app once, then go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**.

This is only needed once: after the first install, the app updates itself in-app (checks weekly), and those updates don't trigger the warning.
