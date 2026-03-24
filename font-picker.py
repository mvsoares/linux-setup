#!/usr/bin/env python3
"""
Font Picker — serves the preview page and applies fonts/sizes to WezTerm config.
Lists all installed monospace fonts (Fontconfig) plus any Nerd Font families that
might not be tagged as mono. Usage: python3 font-picker.py — then open http://localhost:7777
"""
import http.server
import json
import re
import socketserver
import subprocess
import urllib.parse
from pathlib import Path

PORT = 7777
WEZTERM_CFG = Path.home() / ".config/wezterm/wezterm.lua"
HTML_FILE   = Path(__file__).parent / "nerd-fonts-preview.html"

# Known Nerd Font metadata: family → (short author tag, preview description)
# Keys match the actual fc-list family names (which differ from install slugs).
_FONT_META = {
    "0xProto Nerd Font":          ("0xType",            "Designed specifically for terminals and code. Every character optimised for distinction. Strong x-height, zero ambiguity guaranteed."),
    "BlexMono Nerd Font":         ("IBM",               "Engineered precision from IBM Design (IBM Plex Mono). Humanist mono with strong technical character. Excellent for code and docs."),
    "CaskaydiaCove Nerd Font":    ("Microsoft",         "Microsoft's modern mono (Cascadia Code) built for Windows Terminal. Cursive italic variant. Crisp at small sizes, rich ligature set."),
    "CommitMono Nerd Font":       ("Eigil Nikolajsen",  "Modern neutral coding font built for focus. Smart spacing, optical adjustments, no distracting personality. Pure utility."),
    "FiraCode Nerd Font":         ("Mozilla",           "Pioneered programming ligatures. Transforms != -> => into elegant symbols. Clean strokes, wide adoption across editors worldwide."),
    "GeistMono Nerd Font":        ("Vercel",            "Vercel's sleek mono companion to Geist. Minimal and modern, designed for developer interfaces. Clean zero, clear punctuation."),
    "Hack Nerd Font":             ("Source Forge",      "Workhorse coding font with no frills. Optimised for source code at 8–14px. High contrast, open apertures, zero confusion."),
    "Inconsolata Nerd Font":      ("Raph Levien",       "Humanist mono inspired by Consolas. Elegant curves, tight spacing. One of the most readable fonts at small point sizes."),
    "Iosevka Nerd Font":          ("Belleve Invis",     "Ultra-condensed, infinitely customisable. Fits more code on screen than almost any alternative. Minimal and precise."),
    "IosevkaTerm Nerd Font":      ("Belleve Invis",     "Terminal-optimised variant of Iosevka. Fixed cell widths for perfect glyph alignment. Compact and extremely fast to scan."),
    "JetBrainsMono Nerd Font":    ("JetBrains",         "Sharp, geometric mono by JetBrains. Excellent readability, 139 ligatures, zero-ambiguity glyphs. Perfect for long coding sessions."),
    "JetBrainsMonoNL Nerd Font":  ("JetBrains",         "JetBrains Mono without ligatures. Same exceptional clarity and spacing, with every operator rendered as distinct characters."),
    "MesloLGS Nerd Font":         ("André Berg",        "Small Meslo — tighter line-height for dense terminal layouts. The go-to for Powerlevel10k setups."),
    "MesloLGM Nerd Font":         ("André Berg",        "Medium Meslo — customised Apple Monaco derivative. Generous line height, clear punctuation, iconic for terminals."),
    "MesloLGL Nerd Font":         ("André Berg",        "Large Meslo — extra-generous line-height. Great readability on high-DPI displays."),
    "MesloLGSDZ Nerd Font":       ("André Berg",        "Meslo Small with dotted zero variant. Clearer zero/O distinction for security-conscious developers."),
    "MesloLGMDZ Nerd Font":       ("André Berg",        "Meslo Medium with dotted zero variant. Combines generous spacing with unambiguous zero glyph."),
    "MesloLGLDZ Nerd Font":       ("André Berg",        "Meslo Large with dotted zero variant. Maximum line-height with the clearest zero glyph."),
    "MonaspiceNe Nerd Font":      ("GitHub",            "Monaspace Neon: the flagship neo-grotesque variant. Texture healing keeps columns aligned regardless of glyph width."),
    "MonaspiceAr Nerd Font":      ("GitHub",            "Monaspace Argon: humanist fixed-width variant. Warmer personality while retaining precise code alignment."),
    "MonaspiceKr Nerd Font":      ("GitHub",            "Monaspace Krypton: mechanical slab-serif flavour. Distinctive serifs add personality without hurting readability."),
    "MonaspiceRn Nerd Font":      ("GitHub",            "Monaspace Radon: handwriting-influenced cursive variant. Beautiful italics that make keyword highlighting expressive."),
    "MonaspiceXe Nerd Font":      ("GitHub",            "Monaspace Xenon: transitional serif style. Bridges the gap between classic editorial type and modern coding fonts."),
    "RecMonoCasual Nerd Font":    ("Arrow Type",        "Recursive Casual — variable font leaning into a handwritten feel. Expressive italics and a relaxed baseline rhythm."),
    "RecMonoLinear Nerd Font":    ("Arrow Type",        "Recursive Linear — the neutral, no-personality variant. All axes zeroed for pure readability without distraction."),
    "RecMonoDuotone Nerd Font":   ("Arrow Type",        "Recursive Duotone — optimised for syntax themes that separate keywords visually. Contrast-first design."),
    "RecMonoSmCasual Nerd Font":  ("Arrow Type",        "Recursive Semi-Casual — midpoint between Linear and Casual. Subtle personality with professional restraint."),
    "RobotoMono Nerd Font":       ("Google",            "Google's geometric mono, sibling to Roboto. Mechanical feel with friendly curves. Consistent rendering across all platforms."),
    "SauceCodePro Nerd Font":     ("Adobe",             "Adobe Source Code Pro. Neutral, professional and exceptionally legible at all sizes. Part of the open-source Source family."),
    "SpaceMono Nerd Font":        ("Colophon",          "Quirky, wide-spaced typeface designed for editorial use. Distinctive personality that makes code feel like crafted writing."),
    "UbuntuMono Nerd Font":       ("Canonical",         "Canonical's official mono, warm and humanist. Wider than most, trades density for personality. Great on HiDPI displays."),
    "VictorMono Nerd Font":       ("Rune Bjørnerås",   "Semi-condensed with gorgeous cursive italics for keywords. Ligatures feel natural. One of the most beautiful coding fonts."),
    "ZedMono Nerd Font":          ("Zed Industries",    "Built for the Zed editor. Clean and neutral, optimised for dense code display. Pairs beautifully with Zed's minimal UI."),
}

_GENERIC_NERD = (
    "Nerd Font",
    "A Nerd Font patched with icons, ligatures and developer glyphs for terminal and editor use.",
)
_GENERIC_MONO = (
    "Monospace",
    "A monospace font — suitable for code, terminals and aligned columns.",
)


def _fc_list_families(args):
    """Run fc-list and yield first family name per line (comma = locale/weight variants)."""
    try:
        raw = subprocess.check_output(
            ["fc-list", *args, "--format=%{family}\\n"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        return
    for line in raw.splitlines():
        family = line.split(",")[0].strip()
        if family:
            yield family


def _skip_nerd_width_dup(family):
    """Omit Nerd Font Mono/Propo rows when the base '… Nerd Font' face is listed separately."""
    return family.endswith((" Nerd Font Mono", " Nerd Font Propo"))


def _meta_for_family(family):
    if family in _FONT_META:
        return _FONT_META[family]
    if "Nerd Font" in family:
        return _GENERIC_NERD
    return _GENERIC_MONO


def get_installed_fonts():
    """All monospace fonts (fc :spacing=mono) plus any Nerd Font families not tagged mono."""
    seen = set()
    order = []

    def add(family):
        if _skip_nerd_width_dup(family):
            return
        if family in seen:
            return
        seen.add(family)
        order.append(family)

    # 1) Fontconfig monospace — catches JetBrains Mono, Liberation Mono, Nerd faces, etc.
    for family in _fc_list_families([":spacing=mono"]):
        add(family)

    # 2) Supplement: families whose name contains "Nerd Font" (some installs mis-report spacing)
    for family in _fc_list_families([]):
        if "Nerd Font" not in family:
            continue
        add(family)

    fonts = []
    for family in order:
        desc, text = _meta_for_family(family)
        fonts.append({"name": family, "family": family, "desc": desc, "text": text})

    return sorted(fonts, key=lambda f: f["name"].casefold())


def read_cfg():
    return WEZTERM_CFG.read_text() if WEZTERM_CFG.exists() else ""

def write_cfg(src):
    WEZTERM_CFG.write_text(src)

def apply_font(family):
    src = read_cfg()
    src = re.sub(
        r"(config\.font\s*=\s*wezterm\.font\(')[^']+(')",
        rf"\g<1>{family}\g<2>",
        src,
    )
    write_cfg(src)
    return f"Editor font → {family}"

def apply_tab_font(family):
    src = read_cfg()
    # Match font inside window_frame block
    src = re.sub(
        r"(config\.window_frame\s*=\s*\{[^}]*font\s*=\s*wezterm\.font\(')[^']+(')",
        rf"\g<1>{family}\g<2>",
        src,
        flags=re.DOTALL,
    )
    write_cfg(src)
    return f"Tab font → {family}"

def apply_size(size):
    src = read_cfg()
    src = re.sub(
        r"(config\.font_size\s*=\s*)[\d.]+",
        rf"\g<1>{size}",
        src,
    )
    write_cfg(src)
    return f"Editor size → {size}"

def apply_tab_size(size):
    src = read_cfg()
    # Match font_size inside window_frame block
    src = re.sub(
        r"(config\.window_frame\s*=\s*\{[^}]*font_size\s*=\s*)[\d.]+",
        rf"\g<1>{size}",
        src,
        flags=re.DOTALL,
    )
    write_cfg(src)
    return f"Tab size → {size}"

def get_current():
    src = read_cfg()
    font = tab_font = ""
    size = tab_size = ""

    m = re.search(r"config\.font\s*=\s*wezterm\.font\('([^']+)'", src)
    if m: font = m.group(1)

    m = re.search(r"config\.font_size\s*=\s*([\d.]+)", src)
    if m: size = m.group(1)

    frame = re.search(r"config\.window_frame\s*=\s*\{([^}]+)\}", src, re.DOTALL)
    if frame:
        block = frame.group(1)
        m = re.search(r"font\s*=\s*wezterm\.font\('([^']+)'", block)
        if m: tab_font = m.group(1)
        m = re.search(r"font_size\s*=\s*([\d.]+)", block)
        if m: tab_size = m.group(1)

    return {"font": font, "size": size, "tabFont": tab_font, "tabSize": tab_size}


DISPATCH = {
    "/apply":          lambda p: apply_font(p.get("font", [""])[0]),
    "/apply-tab":      lambda p: apply_tab_font(p.get("font", [""])[0]),
    "/apply-size":     lambda p: apply_size(p.get("size", ["14"])[0]),
    "/apply-tab-size": lambda p: apply_tab_size(p.get("size", ["12.5"])[0]),
}


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)

        if parsed.path in ("/", "/index.html"):
            content = HTML_FILE.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)

        elif parsed.path in DISPATCH:
            try:
                msg = DISPATCH[parsed.path](params)
                body = json.dumps({"ok": True, "msg": msg}).encode()
            except Exception as e:
                body = json.dumps({"ok": False, "msg": str(e)}).encode()
            self._json(body)

        elif parsed.path == "/fonts":
            self._json(json.dumps(get_installed_fonts()).encode())

        elif parsed.path == "/current":
            self._json(json.dumps(get_current()).encode())

        else:
            self.send_response(404)
            self.end_headers()

    def _json(self, body):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"Font Picker running → http://localhost:{PORT}")
        print(f"WezTerm config      → {WEZTERM_CFG}")
        print("Press Ctrl+C to stop.")
        httpd.serve_forever()
