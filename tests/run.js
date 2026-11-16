// Runs ReelGold's Lua files outside the game with Fengari and a mocked WoW API.
//   npm install   (once)
//   npm test
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

const root = path.resolve(__dirname, "..");
process.chdir(root);

const toc = fs.readFileSync("ReelGold.toc", "utf8")
  .split(/\r?\n/)
  .map((l) => l.trim())
  .filter((l) => l && !l.startsWith("#"))
  .map((l) => l.replace(/\\/g, "/"));

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
