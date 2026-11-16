// Runs Fishing Coach's Lua files outside the game with Fengari and a mocked WoW API.
//   npm install   (once)
//   npm test
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

const root = path.resolve(__dirname, "..");
process.chdir(root);

const toc = fs.readFileSync("FishingCoach.toc", "utf8")
  .split(/\r?\n/)
  .map((l) => l.trim())
  .filter((l) => l && !l.startsWith("#"))
  .map((l) => l.replace(/\\/g, "/"));

// Every texture the addon points at inside its own folder must exist
// (WoW silently shows a green square for a missing texture).
{
  const sources = ["FishingCoach.toc", ...toc].map((f) => fs.readFileSync(f, "utf8")).join("\n");
  const refs = new Set();
  for (const m of sources.matchAll(/Interface(?:\\\\|\\)AddOns(?:\\\\|\\)FishingCoach(?:\\\\|\\)([A-Za-z0-9_\\]+)/g)) {
    refs.add(m[1].replace(/\\+/g, "/"));
  }
  const missing = [...refs].filter((r) => ![".tga", ".blp", ".png"].some((ext) => fs.existsSync(r + ext)));
  console.log(`Texture check: ${refs.size} addon texture path(s) referenced, ${missing.length} missing`);
  if (refs.size === 0 || missing.length) {
    console.error("Missing textures: " + missing.join(", "));
    process.exit(1);
  }
}

// Policy guard: Fishing Coach only reads and displays. It must never send chat or
// addon messages, cast, use items/actions, change key bindings or touch the AH.
{
  const forbidden = new RegExp("\\b(" + [
    "SendAddonMessage", "SendChatMessage", "C_ChatInfo\\.Send\\w*", "RegisterAddonMessagePrefix",
    "CastSpell\\w*", "UseAction", "UseItemByName", "UseContainerItem",
    "SetBinding\\w*", "SetOverrideBinding\\w*", "SecureActionButtonTemplate",
    "C_AuctionHouse\\.(?:Post|Place|Start|Send)\\w*", "PlaceAuctionBid", "PostAuction",
  ].join("|") + ")\\b");
  const hits = [];
  for (const f of toc) {
    fs.readFileSync(f, "utf8").split(/\r?\n/).forEach((line, i) => {
      const code = line.replace(/--.*$/, "");
      if (forbidden.test(code)) hits.push(`${f}:${i + 1}: ${line.trim()}`);
    });
  }
  console.log(`Policy check: ${hits.length} forbidden call(s) (messages, casting, bindings, AH actions)`);
  if (hits.length) {
    console.error(hits.join("\n"));
    process.exit(1);
  }
}

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

// REPORT(text): write to the real console (the mock replaces print).
lua.lua_pushcfunction(L, (L2) => {
  console.log(to_jsstring(lauxlib.luaL_tolstring(L2, 1)));
  return 0;
});
lua.lua_setglobal(L, to_luastring("REPORT"));

function run(code, name) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring("@" + name)) !== lua.LUA_OK ||
      lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) {
    console.error("Error: " + to_jsstring(lua.lua_tostring(L, -1)));
    process.exit(2);
  }
}

run(fs.readFileSync("tests/wowmock.lua", "utf8"), "tests/wowmock.lua");
run("TOC_FILES = {" + toc.map((f) => JSON.stringify(f)).join(",") + "}", "toc");
run(fs.readFileSync("tests/scenarios.lua", "utf8"), "tests/scenarios.lua");

lua.lua_getglobal(L, to_luastring("TEST_FAILED"));
process.exit(lua.lua_tointeger(L, -1) > 0 ? 1 : 0);
