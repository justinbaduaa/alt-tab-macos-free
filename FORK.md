# AltTab Free — fork notes

A personal fork of [lwouis/alt-tab-macos](https://github.com/lwouis/alt-tab-macos)
that keeps every feature unlocked. AltTab is **GPL-3.0**, including its Pro code,
so modifying and rebuilding it is within the rights the license grants.

> This is for **personal use**. Don't redistribute it publicly under the "AltTab"
> name (trademark). If AltTab earns a spot in your workflow, consider supporting
> the developer — the Pro code being open source is why this fork is a few lines.

## What's patched

Four small, self-contained changes on top of upstream:

| File | Change |
|------|--------|
| `src/pro/license/LicenseManager.swift` | `computeState()` always returns `.pro` — single source of truth, so all gates/nags/badges resolve to Pro. No server call (none happens without a license key). |
| `src/vendors/SparkleDelegate.swift` | `feedURLString` points at this fork's own appcast (`releases/latest/download/appcast.xml`) — auto-updates come from this repo's CI instead of the upstream paywalled release. |
| `Info.plist` (`SUPublicEDKey`) | Replaced with the fork's own Sparkle EdDSA public key, matching the private key CI signs update archives with. |
| `config/base.xcconfig` | `PRODUCT_BUNDLE_IDENTIFIER` → `com.lwouis.alt-tab-macos.free` — distinct identity so it coexists with an official AltTab and gets its own permission entries. |
| `Info.plist` | `CFBundleName` / `CFBundleDisplayName` → "AltTab Free". |

## Build & install locally

```bash
./update.sh            # latest upstream, rebuilt + installed to /Applications
./update.sh 8.4.0      # force a version string
```

`update.sh` merges `upstream/master`, rebuilds (Release), stamps the version
(upstream leaves it blank, which crashes on launch), code-signs, and swaps the
app into `/Applications/AltTab Free.app`.

### Permissions

AltTab needs **Accessibility** (for the ⌥Tab hotkey) and, for window thumbnails,
**Screen Recording**. Signing each build with the *same* identity keeps these
grants across updates — set `ALTTAB_SIGN_ID` in `update.sh` to a code-signing
identity from `security find-identity -v -p codesigning`. With ad-hoc signing
(`ALTTAB_SIGN_ID=""`) you re-grant after each update.

## CI / releases / auto-update

`.github/workflows/build-dmg.yml` is the release pipeline. Every push to
`master` (except markdown-only changes):

1. builds the patched app on a macOS runner
2. signs it with the fork's **self-signed certificate** (`AltTab Free Dev`) —
   a stable identity, so Accessibility/Screen Recording grants survive updates
3. packages a `.dmg` (first-time manual install) and a `.zip` (Sparkle update)
4. signs the zip with the fork's **Sparkle EdDSA key** and generates `appcast.xml`
5. publishes all three as a GitHub Release tagged `v<version>.<commit-count>`

Installed apps poll `releases/latest/download/appcast.xml` (weekly, or via a
manual check in settings), so each release reaches users automatically —
no reinstall needed.

Signing material lives in the repo's Actions secrets (`MACOS_CERT_P12_BASE64`,
`MACOS_CERT_P12_PASSWORD`, `SPARKLE_ED_PRIVATE_KEY`), with local backups in
`~/.config/alt-tab-free/`. **Don't lose or rotate the Sparkle key casually** —
installed apps only accept updates signed by it, so a rotation forces every
user to reinstall manually. Same for the cert: a new cert means users
re-grant permissions once after the next update.

Gatekeeper still warns on the **first** manual install (self-signed ≠
notarized; zero-warning distribution needs a paid Apple Developer ID), but
Sparkle updates skip quarantine entirely, so updates are warning-free.

The upstream `ci_cd.yml` pipeline is disabled on this fork (it needs signing
secrets we don't have); we don't edit it, to avoid merge conflicts on update.

## Staying current

Upstream rarely touches the patched lines, so `./update.sh` merges cleanly.
If a conflict appears, resolve those few lines, `git commit`, and re-run.
