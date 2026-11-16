"""Renders CurseForge preview screenshots of the Fishing Coach UI.

The scenes are a hand-made HTML mockup that follows the layout in UI/*.lua
(sizes, positions, texts) with example data and real WoW icons from the
Wowhead CDN. They are NOT in-game screenshots: replace them with real ones
when possible. Needs Microsoft Edge (or Chrome) for headless rendering.

    python tools/curseforge/make_screenshots.py
"""
import os
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "curseforge" / "screenshots"
BROWSERS = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
]

I = lambda n: "https://wow.zamimg.com/images/wow/icons/large/%s.jpg" % n


def ic(n, s=14):
    return '<img class="i" src="%s" style="width:%dpx;height:%dpx">' % (I(n), s, s)


def money(g=0, s=0, c=None):
    out = []
    if g:
        out.append('%d<span class="cg"></span>' % g)
    if s or g:
        out.append('%d<span class="cs"></span>' % s)
    if c is not None and not g:
        out.append('%d<span class="cc"></span>' % c)
    return " ".join(out)


def tabs(active):
    t = [("Session", "inv_misc_coin_01"), ("Spots", "inv_misc_map_01"), ("Tips", "inv_misc_book_09"), ("Settings", "inv_misc_gear_01")]
    return '<div class="tabs">' + "".join('<div class="btn tab%s">%s %s</div>' % ("" if n == active else " dim", ic(i, 16), n) for n, i in t) + '</div>'


def frame(active, body):
    return ('<div class="win"><div class="title">%s <span>Fishing <b>Coach</b></span><div class="x">&#x2715;</div></div>%s<div class="body">%s</div></div>'
            % (ic("trade_fishing", 26), tabs(active), body))


loot = [("inv_misc_fish_11", "Stonescale Eel", 41, (0, 62), (25, 42)), ("inv_misc_monsterhead_02", "Large Raw Mightfish", 19, (0, 34), (6, 46)),
        ("inv_misc_fish_19", "Raw Summer Bass", 17, (0, 28), (4, 76)), ("inv_misc_fish_12", "Lightning Eel", 9, (0, 45), (4, 5)),
        ("inv_misc_shell_03", "Big-mouth Clam", 3, (0, 18), (0, 54)), ("inv_misc_gem_pearl_04", "Golden Pearl", 1, (1, 80), (1, 80))]
rows = "".join('<div class="row"><img class="ii%s" src="%s"><span class="nm%s">%s</span><span class="ct">x%d <i>@ %s</i></span><span class="tot">%s</span></div>'
               % (" green" if n == "Golden Pearl" else "", I(i), " g" if n == "Golden Pearl" else "", n, c, money(*u), money(*t)) for i, n, c, u, t in loot)

session = frame("Session", """
<div class="hdr">%s Azshara &nbsp; %s Skill 300/300 <em>+25</em></div>
<div class="sub">%s <em>Lure active</em> (7m 12s)</div>
<div class="ratebox"><img class="big" src="%s"><div><div class="rate">%s</div><div class="sub">Gold per hour &nbsp;<i>(active fishing time only)</i></div></div>
<div class="btn unit">Per hour</div></div>
<div class="stats"><div><b>Active fishing time</b><span>1h 04m</span></div><div><b>Catches</b><span>131</span></div>
<div><b>Catches per hour</b><span>123</span></div><div><b>Coins looted</b><span>%s</span></div><div><b>Total value</b><span>%s</span></div></div>
<div class="lt"><b>Catch log</b><div class="pager"><div class="btn sm dim">&lt;</div><span>1 / 1</span><div class="btn sm dim">&gt;</div></div></div>
%s
<div class="foot"><div class="btn">Reset session</div><div class="btn">Toggle HUD</div></div>""" % (
    ic("inv_misc_map_01"), ic("trade_fishing"), ic("inv_misc_orb_03", 12), I("inv_misc_coin_01"), money(40, 93), money(0, 0, 0), money(43, 13), rows))

spots = [("inv_misc_fish_11", "Azshara", " (you are here)", "40g 93s", "Eastern coast / Bay of Storms (Stonescale schools)", "330", "your data"),
         ("inv_misc_fish_11", "Feralas", "", "34g 10s", "Sardor Isle / Feathermoon coast (Stonescale schools)", "300", "estimate"),
         ("inv_misc_fish_23", "Winterspring", "", "22g 48s", "Lakes near Everlook", "330", "estimate"),
         ("inv_misc_fish_23", "Felwood", "", "19g 75s", "Lakes and rivers", "300", "estimate"),
         ("inv_misc_fish_20", "Riverglades", "", "18g 02s", "Your fishing data", "", "your data"),
         ("inv_misc_fish_20", "The Hinterlands", "", "16g 40s", "Rivers and lakes (Greater Sagefish schools)", "300", "estimate"),
         ("inv_misc_monsterhead_01", "Wetlands", "", "9g 12s", "Menethil Harbor coast", "150", "estimate")]
srows = "".join('<div class="spot"><img class="ii32" src="%s"><div class="sp"><div class="st">%d. %s<em>%s</em></div><div class="ss">%s</div></div><div class="sv">%s<i>/h</i></div></div>'
                % (I(i), k + 1, z, here, " &middot; ".join([sp] + (['<em>skill %s</em>' % sk] if sk else []) + ['<em>your data</em>' if tag == "your data" else '<i>estimate</i>']), v)
                for k, (i, z, here, v, sp, sk, tag) in enumerate(spots))
spotsf = frame("Spots", """<div class="hdr">%s Best fishing spots right now <i>(effective skill 325)</i></div>
<div class="chk"><span class="box"></span> Only spots I can fish<div class="pager"><div class="btn sm dim">&lt;</div><span>1 / 3</span><div class="btn sm">&gt;</div></div></div>%s
<div class="note">Values update with your price source. Zones you fish get ranked from your own catches.</div>""" % (ic("inv_misc_map_01"), srows))

tooltip = """<div class="tt"><div class="ttt">Azshara</div><div>Eastern coast / Bay of Storms (Stonescale schools)</div><div class="gr">Recommended skill: 330</div><br>
<div class="dl"><b>Estimated per hour</b><span>40g 93s</span></div><div class="dl"><b>Catches per hour</b><span>123</span></div>
<div class="gn">Based on YOUR 131 catches here.</div><br><b class="y">Main catches:</b>
<div class="dl"><span>%s Stonescale Eel</span><span class="gr">31%%  19s 25c/catch</span></div>
<div class="dl"><span>%s Large Raw Mightfish</span><span class="gr">15%%  5s 08c/catch</span></div>
<div class="dl"><span>%s Raw Summer Bass</span><span class="gr">13%%  3s 64c/catch</span></div><br>
<div class="bl">Best Stonescale Eel farm. Big-mouth Clams can hold Golden Pearls.</div></div>""" % (ic("inv_misc_fish_11"), ic("inv_misc_monsterhead_02"), ic("inv_misc_fish_19"))

tips = [("inv_misc_orb_03", True, "Your lure expires in under a minute."),
        ("inv_misc_fish_19", True, "It is daytime: Raw Sunscale Salmon bites in high level lakes; Nightfin starts at 18:00."),
        ("inv_misc_fish_03", True, "Summer season: Raw Summer Bass in high level coastal waters."),
        ("inv_misc_pocketwatch_01", True, "Today is Sunday: Stranglethorn Fishing Extravaganza at 14:00!"),
        ("inv_misc_orb_03", False, "Always keep a lure on your pole. Below skill 25 a Shiny Bauble guarantees catches in starting zones."),
        ("trade_fishing", False, "In Forever every zone has a skill requirement: once you reach it, every catch succeeds. Poles, lures, food and gear raise your effective skill.")]
trows = "".join('<div class="tip"><img class="ii30" src="%s"><div>%s%s</div></div>' % (I(i), '<b class="y">Now:</b> ' if now else "", t) for i, now, t in tips)
tipsf = frame("Tips", '<div class="hdr">%s Fishing tips<div class="pager"><div class="btn sm dim">&lt;</div><span>1 / 3</span><div class="btn sm">&gt;</div></div></div>%s' % (ic("inv_misc_book_09"), trows))

settings = frame("Settings", """<div class="hdr">%s Prices</div>
<div class="line"><div class="btn wide">Source: Auto (Auctionator &gt; TSM &gt; vendor)</div><span class="sm">Detected: <em>Auctionator</em> <i>TSM</i></span></div>
<div class="line">TSM price source: <span class="edit">DBMarket</span></div>
<div class="chk"><span class="box on"></span> Subtract 5%% Auction House cut</div>
<div class="line y sm">Manual price (drop an item or type its ID):</div>
<div class="line"><img class="ii26" src="%s"><span class="edit">13422</span><span class="edit">0.70</span> gold <div class="btn sm2">Set</div><div class="btn sm2">Clear</div></div>
<div class="hdr">%s Tracking</div>
<div class="line">Pause session after no catch for (minutes): <span class="edit s">5</span></div>
<div class="line">Use my own zone data after this many catches: <span class="edit s">40</span></div>
<div class="hdr">%s Display</div>
<div class="chk"><span class="box on"></span> Show HUD (compact gold/time tracker)</div>
<div class="chk"><span class="box on"></span> Show HUD only while a fishing pole is equipped</div>
<div class="chk"><span class="box"></span> Lock HUD position</div>
<div class="chk"><span class="box on"></span> Show minimap button</div>
<div class="foot"><div class="btn">Forget zone data</div><i class="sm">v1.0.1 &middot; data 1 (2026-11-16, client 1.60.1)</i></div>""" % (
    ic("inv_misc_coin_01"), I("inv_misc_fish_11"), ic("inv_misc_pocketwatch_01"), ic("inv_misc_gear_01")))

hud = """<div class="hud"><img class="ii34" src="%s"><div><div class="hr">%s <i>per hour</i></div><div class="sm">1h 04m &middot; 131 catches</div><div class="sm">Total %s</div></div></div>""" % (
    I("inv_misc_fish_11"), money(40, 93), money(43, 13))
mm = """<div class="tt" style="width:250px"><div class="ttt">Fishing <b class="y">Coach</b></div><div class="dl"><b>Gold per hour</b><span>40g 93s</span></div>
<div class="dl"><b>Session value</b><span>43g 13s</span></div><div class="dl"><b>Best spot</b><span>Azshara</span></div><br><div class="gr sm">Left-click: open &middot; Right-click: toggle HUD</div></div>"""

css = """body{background:linear-gradient(#24323a,#1a2420);color:#fff;font:12px Georgia,serif;margin:0;padding:20px 16px}
h1{font:500 22px system-ui;color:#ffd100;margin:0}p.n{font:13px system-ui;color:#aaa;margin:4px 0 18px;max-width:900px}h2{font:500 14px system-ui;color:#ccc;margin:0 0 6px}
.grid{display:flex;flex-wrap:wrap;gap:22px;align-items:flex-start}.cell{max-width:100%}
.win{width:470px;max-width:100%;height:520px;background:rgba(10,14,20,.94);border:3px solid #6f6f78;border-radius:6px;position:relative;box-sizing:border-box}
.title{display:flex;align-items:center;gap:8px;padding:6px 10px;font-size:17px;color:#fff}.title b{color:#ffd100;font-weight:normal}.x{margin-left:auto;background:#7a1010;border:1px solid #c33;border-radius:3px;width:20px;height:20px;text-align:center;line-height:20px;font-size:12px}
.tabs{display:flex;gap:4px;padding:2px 12px}.btn{display:inline-flex;align-items:center;gap:6px;background:linear-gradient(#a01515,#5a0909);border:1px solid #2a0000;border-radius:3px;color:#ffd100;padding:3px 10px;font-size:12px;white-space:nowrap;box-shadow:inset 0 1px #e05050}
.tab{width:84px}.dim{opacity:.6}.body{padding:8px 14px}.i{vertical-align:-3px;border-radius:2px}
.hdr{color:#ffd100;font-size:13px;margin:4px 0;display:flex;align-items:center;gap:6px}.hdr i,.gr,i{color:#999;font-style:normal}em{color:#33ff33;font-style:normal}.sub{font-size:11px;color:#ddd}
.ratebox{display:flex;align-items:center;gap:10px;border:2px solid #555;border-radius:5px;padding:8px 10px;margin:10px 0 6px;background:rgba(15,18,25,.9)}.big{width:36px;height:36px}.rate{font-size:18px;color:#ffd100}.unit{margin-left:auto}
.stats div{display:flex;justify-content:space-between;font-size:11px;padding:1px 2px}.stats b{color:#ffd100;font-weight:normal}
.lt{display:flex;align-items:center;margin-top:10px;color:#ffd100;font-size:13px}.lt b{font-weight:normal}.pager{margin-left:auto;display:flex;gap:6px;align-items:center;color:#ffd100;font-size:11px}.btn.sm{padding:1px 8px}
.row{display:flex;align-items:center;gap:6px;height:25px;font-size:11px}.row img{width:22px;height:22px;border:1px solid #333}.green{box-shadow:0 0 0 2px #1eff00}.nm{width:170px}.nm.g{color:#1eff00}.ct{width:120px}.tot{margin-left:auto}
.cg,.cs,.cc{display:inline-block;width:10px;height:10px;border-radius:50%;margin-left:2px;vertical-align:-1px}.cg{background:#e8c43a}.cs{background:#c9ccd1}.cc{background:#b8733b}
.foot{position:absolute;left:14px;right:14px;bottom:12px;display:flex;gap:8px;align-items:center}.foot i{margin-left:auto}
.chk{display:flex;align-items:center;gap:6px;margin:6px 0;font-size:11px}.box{width:14px;height:14px;border:1px solid #888;background:#111;border-radius:2px;position:relative}.box.on:after{content:"\\2713";color:#ffd100;position:absolute;top:-3px;left:2px;font-size:13px}
.spot{display:flex;align-items:center;gap:8px;height:42px;border:1px solid #444;border-radius:4px;background:rgba(25,25,30,.7);margin-bottom:5px;padding:0 8px}.ii32{width:32px;height:32px}.sp{flex:1;min-width:0}.st{color:#ffd100;font-size:12px}
.ss{font-size:10.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.sv{font-size:12px}.note{position:absolute;left:14px;right:14px;bottom:14px;color:#777;font-size:10.5px}
.tt{width:300px;background:rgba(10,10,25,.95);border:2px solid #888;border-radius:5px;padding:8px 10px;font:12px system-ui;box-sizing:border-box;max-width:100%}.ttt{font-size:14px;color:#ffd100}.dl{display:flex;justify-content:space-between;gap:8px}.dl b{color:#ffd100;font-weight:normal}
.gn{color:#33ff33}.bl{color:#33ccff}.y{color:#ffd100;font-weight:normal}.sm{font-size:11px}
.tip{display:flex;gap:8px;margin:8px 0 12px;font-size:11.5px;line-height:1.45}.ii30{width:30px;height:30px}.line{display:flex;align-items:center;gap:8px;margin:6px 0;font-size:11px}
.edit{background:#000;border:1px solid #555;border-radius:3px;padding:2px 6px;min-width:56px}.edit.s{min-width:24px}.wide{width:240px}.sm2{padding:1px 8px}.ii26{width:26px;height:26px}
.hud{display:flex;gap:8px;align-items:center;width:210px;height:62px;box-sizing:border-box;background:rgba(10,14,20,.92);border:2px solid #6f6f78;border-radius:5px;padding:0 8px}.ii34{width:34px;height:34px}.hr{color:#ffd100;font-size:12px}"""


scene_css = """body{margin:0;width:1280px;height:720px;overflow:hidden;background:radial-gradient(ellipse at 30% 20%,#2f5a66 0%,#16303a 45%,#0b171c 100%);font-family:Georgia,serif}
.stage{position:absolute;inset:0;display:flex;gap:28px;align-items:center;justify-content:center}
.side{display:flex;flex-direction:column;gap:22px;align-items:flex-start}
.cap{position:absolute;left:28px;top:22px;font:600 26px system-ui;color:#ffd100;text-shadow:0 2px 6px #000}
.cap small{display:block;font:400 15px system-ui;color:#cfd8dc;margin-top:4px}
.note{position:absolute;right:16px;bottom:10px;font:12px system-ui;color:#8fa3aa}
.win{height:520px}"""

SCENES = {
    "1-session": ("Gold per hour, honestly measured", "Active fishing time only, with a catch log of real items",
                  session + '<div class="side">' + hud + mm + "</div>"),
    "2-spots": ("Best fishing spots for you", "Ranked by gold per hour with your prices, learned from your catches",
                spotsf + '<div class="side">' + tooltip + "</div>"),
    "3-tips": ("Tips that fit the moment", "Lure, skill, day or night, season and Extravaganza reminders",
               tipsf),
    "4-settings": ("Your prices, your rules", "Auctionator / TSM / vendor prices, manual prices and display options",
                   settings),
}


def find_browser():
    for b in BROWSERS:
        if os.path.exists(b):
            return b
    raise SystemExit("Edge or Chrome not found")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    browser = find_browser()
    with tempfile.TemporaryDirectory() as tmp:
        for name, (title, sub, inner) in SCENES.items():
            page = pathlib.Path(tmp) / (name + ".html")
            page.write_text(
                '<!doctype html><html><head><meta charset="utf-8"><style>%s %s</style></head><body>'
                '<div class="cap">%s<small>%s</small></div><div class="stage">%s</div>'
                '<div class="note">Preview mockup of the Fishing Coach UI with example values, not an in-game screenshot</div>'
                '</body></html>' % (css, scene_css, title, sub, inner), encoding="utf-8")
            out = OUT / (name + ".png")
            subprocess.run([browser, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                            "--user-data-dir=" + str(pathlib.Path(tmp) / "profile"),
                            "--window-size=1280,720", "--virtual-time-budget=8000",
                            "--screenshot=" + str(out), page.as_uri()],
                           check=True, capture_output=True)
            print(out)


if __name__ == "__main__":
    main()
