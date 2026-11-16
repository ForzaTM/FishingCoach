# CurseForge project settings (copy into the project form)

| Field | Value |
|---|---|
| Game | World of Warcraft |
| Project type | Addon |
| Name | ReelGold |
| Summary (short line under the name) | Fishing gold per hour tracker, best profitable fishing spots and tips for WoW: Forever. |
| Main category | Professions |
| Extra category | Auction & Economy |
| License | MIT License |
| Source | https://github.com/ForzaTM/ReelGold |
| Issues | https://github.com/ForzaTM/ReelGold/issues |
| Logo | `docs/curseforge/logo.png` (400x400) |
| Description | contents of `docs/curseforge/description.md` (Markdown) |
| Screenshots | `docs/curseforge/screenshots/*.png`, replace with real in-game ones when possible |

After the project is approved:
1. Copy the numeric Project ID from the "About Project" box.
2. Create an API token (author dashboard, API Tokens), then in the ReelGold folder run
   `gh secret set CF_API_KEY --repo ForzaTM/ReelGold` and paste it.
3. Add `## X-Curse-Project-ID: <id>` to `ReelGold.toc`, commit, tag and push the
   next version. The Release workflow uploads it to CurseForge.
