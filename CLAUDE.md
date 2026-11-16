# ReelGold: project context

Context for anyone (human or AI) making future updates. Read this first, then
`README.md` for user-facing docs. Keep this file current when decisions change.

## What it is
A free World of Warcraft addon for **WoW: Forever**. It tracks fishing gold per
time unit, ranks the most profitable fishing spots, and shows fishing tips.
- Repo: https://github.com/ForzaTM/ReelGold (public, default branch `main`)
- Releases: v1.0.0 (manual release, see history), v1.0.1 (first automatic release)
- Owner works on Windows 11, repo at `E:\ClaudeWork\ReelGold`. Tools available:
  git, gh (logged in as ForzaTM), node/npm, Python 3.14, Windows PowerShell 5.1 + pwsh 7.

## The game: WoW: Forever (verified Nov 2026)
- Blizzard's "Classic+": announced BlizzCon 2026-09-12, launched 2026-11-04.
  Vanilla 1-60 setting, overhauled zones, ~1000 new quests. New zones: Riverglades,
  Mount Hyjal, Shen'dralas, Zephras Isle. New race Skyborne. Dalaran in Alterac.
- Client **1.60.1**, TOC **`## Interface: 16001`** (from community addon devs,
  not an official Blizzard number). Check in game: `/dump select(4, GetBuildInfo())`.
- Runs on the **modern Mainline (12.x / Midnight) client API**, not Classic API.
  Midnight "secret values" restrictions also apply: use `issecretvalue` guards.
- Use a single unsuffixed TOC. `_Forever.toc` was announced as an alias of
  `_Camelot.toc`, but devs reported the client didn't recognize it.
- Install folder: `World of Warcraft\_forever_\Interface\AddOns\` (beta was `_forever_beta_`).
  Saved variables live in `_forever_\WTF\...`.
- Fishing in Forever: every zone has a skill requirement; at that skill all catches
  succeed. Expert trainer Old Man Heming (Booty Bay); Artisan quest Nat Pagle
  (Dustwallow). Stranglethorn Fishing Extravaganza Sundays 14-16, first 50 win.
  Legacy perk Luremaster; Fishing Rack (140) / Fishing Hut (300) camping items.
  Source: warcraft.wiki.gg/wiki/Forever_fishing_techniques

## Hard rules (Blizzard policy + owner's requirements)
- **Read and display only.** No casting, looting, clicking, key binding overrides,
  secure action buttons, AH scanning/posting, chat/addon messages or network traffic.
  Automation violates the Terms of Use. This is the main safety argument; keep it.
- UI Add-On Development Policy (2009): free, code not obfuscated, no harm to realm
  performance, no ads, no in-game donation requests, teen-rated content, follow
  ToU/EULA, Blizzard may disable features. Questions: WoWUI@blizzard.com.
- Icons and item names must be real: always read them from the client by item ID
  (`ns.C.GetItemIcon`, `ns.C.GetItemInfo`). The only bundled image is our own logo
  `Media/Icon.tga` (`ns.Icons.logo`), used for branding spots only; skill/fishing
  meaning keeps Blizzard's `Trade_Fishing`.
- The owner wants clarifying questions when something is ambiguous, and
  confirmation before outward-facing actions (pushing tags/releases, publishing).

## Architecture
```
ReelGold.toc          load order; Interface number; @project-version@ token
Data/GameVersion.lua  TESTED_INTERFACE / TESTED_CLIENT / DATA_VERSION / DATA_DATE
Data/Fish.lua         itemID -> use hint; ns.Icons (UI texture paths)
Data/Locations.lua    seed spots: mapID, minSkill, catchesPerHour, junkCopper, loot shares
Data/Tips.lua         general tips
Core/Compat.lua       EVERY WoW API call goes through ns.C (the one place to fix after patches)
Core/Util.lua         money/duration formatting, debounce, print
Core/Pricing.lua      manual override > Auctionator > TSM > vendor; 5% AH cut option
Core/Tracker.lua      session + per-zone stats from fishing loot only
Core/Recommend.lua    spot ranking + context tips
UI/Widgets.lua        tiny widget factory on long-lived Blizzard templates
UI/MainFrame.lua      470x520 window: Session / For me / Spots / Tips / Settings tabs (paged rows, no scroll frames)
UI/HUD.lua            222x62 movable tracker with close (X) button; X sets hud.shown=false
UI/MinimapButton.lua  library-free minimap button + Addon Compartment functions
UI/OptionsPanel.lua   Options -> AddOns page (Settings.RegisterCanvasLayoutCategory), registered on PLAYER_LOGIN
Core/Init.lua         saved vars, MIGRATIONS, events, slash commands (loaded last)
Media/Icon.tga        128x128 32-bit TGA logo (built from docs/art/icon.svg by `npm run icon`)
```
Saved variables: `ReelGoldDB` (account: settings, priceOverrides, zoneStats keyed by
uiMapID) and `ReelGoldCharDB` (character: current session).
Slash: `/rgold` or `/reelgold` with `show|session|best|spots|tips|settings|options|prices|hud|reset|minimap|version`.

## Key behaviours and why
- **Loot:** `LOOT_READY` and `LOOT_OPENED` both fire; a `handled` flag dedupes per
  loot window, reset on `LOOT_CLOSED`. Only `IsFishingLoot()` windows count.
  Coins come from the `GetMoney()` delta between ready and closed.
- **Active time:** the gap between catches counts only if <= idle timeout
  (default 300 s); the first catch after a break adds a 15 s estimate. Rates
  (per minute / hour / custom N minutes) = value / active seconds x unit.
- **Price updates:** `Pricing.HookSources()` registers `Auctionator.API.v1.RegisterForDBUpdate`
  (fires after full scans AND processed AH searches; verified in Auctionator 347 source)
  at login and on `ADDON_LOADED` Auctionator; `AUCTION_HOUSE_CLOSED` refreshes as TSM fallback.
  Chat message max once per AH visit. Title bar: Refresh prices button + `Pricing.ShortStatus()`.
  Auctionator 347's TOC lists interface 16001 too (independent confirmation).
- **Spots:** estimate = sum(share x price) + junk, x catchesPerHour. Day/night
  entries (18:00-06:00 = night, game time) and seasons (Apr-Sep summer) filter
  loot. After `minLearnCatches` (40) in a zone, YOUR data replaces the estimate,
  and zones not in the seed data (new Forever zones) are ranked automatically.
  A zone with your own data is always `canFish` (fix in 1.0.1).
- **For me tab** (`R.ForSkill`): top 3 `canFish` spots; next goal = locked spot paying more than
  your best, closest `minSkill` first; `R.BoostFor(gap)` suggests a lure for gaps <= 100.
- **Micro maps** roll up to their parent zone in `C.GetPlayerMap`; dungeon maps don't.
- **Version notice:** if the client interface is newer than TESTED_INTERFACE, a one-time chat notice.

## Data caveats (not verified in game yet)
- Fish item IDs were verified against Wowhead Classic (27 items). Forever may change some.
- Seed `mapID`s are Classic uiMapIDs (Azshara 1447, Feralas 1444, ...). If Forever
  uses different IDs, names fall back to English and learned data still works.
- `minSkill`, loot shares and catchesPerHour are vanilla-based estimates.
- Whole addon has NOT been loaded in the real client yet; only the mocks below.

## Workflows
```bash
npm test                       # 22 Lua scenario tests (Fengari + tests/wowmock.lua)
npm run test:installer         # 9 installer tests with fake WoW folders (PowerShell 5.1)
python tools/release.py bump --interface 16002 --client 1.60.2   # new client patch
python tools/release.py data --note "what changed"               # after editing Data/*.lua
python tools/release.py package --version X.Y.Z                  # dist/ addon zip + windows installer zip
```
Release: update `CHANGELOG.md` (move Unreleased into `## X.Y.Z (date)`), run both
test suites, commit, `git tag vX.Y.Z`, `git push origin main vX.Y.Z`. The
Release workflow then runs tests, the BigWigs packager (GitHub Release + CurseForge
once configured) and attaches the Windows installer. Check both release zips after.
CurseForge auto-upload is not set up: needs `## X-Curse-Project-ID:` in the TOC and
a `CF_API_KEY` repo secret.

When Blizzard renames an API: fix `Core/Compat.lua` AND the matching fake in
`tests/wowmock.lua`, then `npm test`. When saved-variable layout changes: bump
`DB_DEFAULTS.schema` and add a `MIGRATIONS[n]` function in `Core/Init.lua`.

## Installer (tools/installer)
`Install-ReelGold.cmd` -> `install.ps1` (PowerShell 5.1 compatible: no `??`, no ternary).
Search order: registry (Blizzard + Uninstall keys), Battle.net `product.db` path
strings, common folders on fixed drives, optional deep scan (depth 3, asks first).
Flavors `_forever_` > `_forever_beta_` > `_forever_ptr_`. Only ever deletes a
`ReelGold` folder that contains `ReelGold.toc`. Options: `-ListOnly -Path -Uninstall
-DeepScan -Yes` (+ `-SearchRoot -NoDefaultSearch` for tests). On the owner's PC it
finds `D:\Games\World of Warcraft\_forever_`.
Repo mode copies only TOC-listed files + LICENSE; bundle mode copies `.\ReelGold\`.

## Gotchas already hit
- Textures: WoW reliably loads TGA/BLP (power-of-two sizes), referenced without extension.
  `tests/run.js` fails if a referenced `Interface\AddOns\ReelGold\...` texture is missing.
  The installer copies `Media/` in repo mode (it is not listed in the TOC).
  New files (TOC entries or textures) need a full client restart, not `/reload`.
- Workflow `GITHUB_TOKEN` is read-only by default: release.yml needs
  `permissions: contents: write` (v1.0.0 release failed with 403, then created manually).
  A tag run uses the workflow file *from the tagged commit*.
- BigWigs packager leaves `.release/` in the CI checkout: `release.py` skips all
  hidden top-level folders (v1.0.1 installer asset was rebuilt and replaced).
- Packager stamps the version as the tag (`v1.0.1`); `release.py` stamps `1.0.1`.
- Fengari is Lua 5.3 (WoW is 5.1): stay in the common subset; the mock adds
  `math.atan2`, `unpack`, etc. Syntax is also checked as 5.1 with luaparse.
- Mock frames: any CamelCase method is a no-op; lowercase fields are nil. Keep
  addon fields lowercase and methods CamelCase so this stays true.
- Windows PowerShell 5.1 turns native stderr into exceptions under
  `$ErrorActionPreference='Stop'`: the installer test runner sets `Continue`.
- `.gitattributes`: LF everywhere except `*.cmd` / `*.ps1` (CRLF).
- Packaging ignores: `.pkgmeta` AND `PACKAGE_IGNORE` in `tools/release.py`; update both.
- Commits use the owner's GitHub no-reply identity (repo-local git config); don't
  put personal email addresses in files.

## CurseForge page assets
`docs/curseforge/`: `description.md` (page text, Markdown), `project-settings.md`
(form values + post-approval steps), `logo.svg` / `logo.png` (original 400x400
design, no Blizzard art), `screenshots/*.png` (1280x720). Screenshots are a
labelled MOCKUP rendered by `python tools/curseforge/make_screenshots.py`
(headless Edge/Chrome, icons from the Wowhead CDN); replace them with real
in-game screenshots when available. They don't show the For me tab or the HUD close button yet. Re-render the logo with headless Edge
(`--screenshot --window-size=400,400` on an HTML page embedding logo.svg).
`docs/` is excluded from addon zips (`.pkgmeta` + `PACKAGE_IGNORE`).

## Open ideas / next steps
- First real in-game test (`/rgold`, `/reload` after changes); fix what breaks.
- Verify Forever uiMapIDs, zone skill requirements and fish in new zones; update Data/.
- Owner creates the CurseForge project (see docs/curseforge/project-settings.md), sets the
  `CF_API_KEY` secret on their own (never handle the key), then add `## X-Curse-Project-ID:` and release.
- Offered, not built: a browser UI preview driven by the mock (record SetPoint/SetSize/text
  and render it), as a layout check without the game.
- Local reference pages (outside the repo, not maintained): `E:\ClaudeWork\ReelGold-ui-preview.html`
  (hand-made mockup) and `E:\ClaudeWork\ReelGold-icon-gallery.html` (icons used).
