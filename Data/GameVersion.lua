-- Fishing Coach: game version metadata.
-- When WoW: Forever gets a new patch, run tools/bump-interface (see README)
-- which updates TESTED_INTERFACE here and the ## Interface line in the TOC.
local _, ns = ...

ns.GameVersion = {
    -- Interface number of the client this data set was verified against.
    TESTED_INTERFACE = 16001,
    -- Human readable client version for the same build.
    TESTED_CLIENT = "1.60.1",
    -- Bump DATA_VERSION whenever Fish/Locations/Tips data changes, so the
    -- addon can tell users their spot estimates were refreshed.
    DATA_VERSION = 2,
    DATA_DATE = "2026-11-16",
    -- Where players get updates (shown in Settings; addons can't open links).
    UPDATE_URL = "https://github.com/ForzaTM/FishingCoach/releases",
}
