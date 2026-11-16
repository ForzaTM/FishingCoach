// Renders docs/art/icon.svg to the in-game texture Media/Icon.tga (128x128, 32-bit
// with alpha) plus a PNG preview. WoW reliably loads TGA/BLP textures.
//   npm run icon        (needs Microsoft Edge or Google Chrome for rendering)
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { pathToFileURL } = require("url");
const { PNG } = require("pngjs");

const root = path.resolve(__dirname, "..");
const svg = path.join(root, "docs", "art", "icon.svg");
const previewPng = path.join(root, "docs", "art", "icon.png");
const tga = path.join(root, "Media", "Icon.tga");
const SIZE = 128;

const browsers = [
  String.raw`C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`,
  String.raw`C:\Program Files\Microsoft\Edge\Application\msedge.exe`,
  String.raw`C:\Program Files\Google\Chrome\Application\chrome.exe`,
  "/usr/bin/google-chrome", "/usr/bin/chromium",
];
const browser = browsers.find((b) => fs.existsSync(b));
if (!browser) throw new Error("Edge or Chrome not found");

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "fishingcoach-icon-"));
const html = path.join(tmp, "icon.html");
fs.writeFileSync(html, `<!doctype html><html><head><style>html,body{margin:0;background:transparent;overflow:hidden}</style></head>
<body>${fs.readFileSync(svg, "utf8")}</body></html>`);
execFileSync(browser, ["--headless=new", "--disable-gpu", "--hide-scrollbars",
  "--default-background-color=00000000", `--user-data-dir=${path.join(tmp, "profile")}`,
  `--window-size=${SIZE},${SIZE}`, `--screenshot=${previewPng}`, pathToFileURL(html).href], { stdio: "ignore" });

const png = PNG.sync.read(fs.readFileSync(previewPng));
if (png.width !== SIZE || png.height !== SIZE) throw new Error(`unexpected size ${png.width}x${png.height}`);

// TGA: uncompressed true-color (type 2), 32 bpp, 8 alpha bits, top-left origin.
const header = Buffer.alloc(18);
header[2] = 2;
header.writeUInt16LE(SIZE, 12);
header.writeUInt16LE(SIZE, 14);
header[16] = 32;
header[17] = 0x28;
const pixels = Buffer.alloc(SIZE * SIZE * 4);
for (let i = 0; i < SIZE * SIZE; i++) {
  pixels[i * 4] = png.data[i * 4 + 2];     // B
  pixels[i * 4 + 1] = png.data[i * 4 + 1]; // G
  pixels[i * 4 + 2] = png.data[i * 4];     // R
  pixels[i * 4 + 3] = png.data[i * 4 + 3]; // A
}
fs.mkdirSync(path.dirname(tga), { recursive: true });
fs.writeFileSync(tga, Buffer.concat([header, pixels]));
fs.rmSync(tmp, { recursive: true, force: true });

const alpha = (x, y) => png.data[(y * SIZE + x) * 4 + 3];
console.log(`${tga} (${SIZE}x${SIZE}), corner alpha ${alpha(0, 0)}, center alpha ${alpha(64, 64)}`);
