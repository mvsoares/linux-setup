#!/usr/bin/env python3
"""Renders preview PNGs, master composite catalog image, and interactive HTML
for all 60 WezTerm tab-bar themes.
"""

import glob
import multiprocessing
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

# Add lib/ to sys.path
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))

from wezterm_tab_themes import THEMES

OUTPUT_DIR = Path("/home/mvsoares/tmp")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

ARTIFACT_DIR = Path("/home/mvsoares/.gemini/antigravity-cli/brain/abe6e0c6-f1c8-47ec-aa10-72f44071a605/tab_previews")
ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)


def slugify(text: str) -> str:
    s = text.lower()
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"[\s_]+", "_", s)
    return s.strip("_")


def make_html_for_theme(theme: dict) -> str:
    tid = theme["id"]
    name = theme["name"]
    cat = theme["category"]
    bg_bar = theme.get("bg_bar", "#15161c")
    style = theme.get("style", "pills")
    palette = theme.get("palette", [
        {"bg": "#4285F4", "fg": "#ffffff", "active_sym": "⚡ 🔵 ➜ ", "inactive_sym": " 🔘"},
        {"bg": "#EA4335", "fg": "#ffffff", "active_sym": "⚡ 🔴 ➜ ", "inactive_sym": " 🔘"},
        {"bg": "#34A853", "fg": "#ffffff", "active_sym": "⚡ 🟢 ➜ ", "inactive_sym": " 🔘"},
        {"bg": "#FBBC05", "fg": "#ffffff", "active_sym": "⚡ 🟠 ➜ ", "inactive_sym": " 🔘"},
    ])

    tabs_data = [
        {"num": 1, "dir": "linux-setup", "process": "git", "active": True},
        {"num": 2, "dir": "mvsoares", "process": "", "active": False},
        {"num": 3, "dir": "careplus", "process": "ssh", "active": False},
        {"num": 4, "dir": "cloud-run", "process": "gcp", "active": False},
    ]

    tabs_html = []
    is_compact = style == "compact" or tid == 56
    tab_height = "26px" if is_compact else "34px"
    font_size = "11.5px" if is_compact else "12.5px"

    if style == "powerline":
        pw_type = theme.get("powerline_type", "arrow")
        for i, t in enumerate(tabs_data):
            c = palette[i % len(palette)]
            next_c = palette[(i + 1) % len(palette)] if i + 1 < len(tabs_data) else {"bg": bg_bar}
            weight = "700" if t["active"] else "500"
            sym = c.get("active_sym", "⚡ ➜ ") if t["active"] else c.get("inactive_sym", "  ")
            bg = c["bg"]
            fg = c["fg"]
            next_bg = next_c["bg"]

            if pw_type == "arrow":
                svg = f'''<svg style="margin-left:-1px;display:inline-block;vertical-align:bottom;flex-shrink:0;" width="14" height="34" viewBox="0 0 14 34"><polygon points="0,0 14,17 0,34" fill="{bg}"/></svg>'''
                tabs_html.append(f"""
                <div style="display:flex;align-items:center;height:34px;background:{next_bg};">
                    <div style="background:{bg};color:{fg};font-weight:{weight};height:34px;display:flex;align-items:center;padding:0 6px 0 10px;font-size:12px;white-space:nowrap;">
                        {sym}{t['num']} {t['dir']} <span style="margin-left:6px;opacity:0.5;font-size:11px;">✕</span>
                    </div>
                    {svg}
                </div>
                """)
            elif pw_type == "bubble":
                svg_l = f'''<svg width="8" height="32" viewBox="0 0 8 32"><path d="M8,0 C3,0 0,6 0,16 C0,26 3,32 8,32 Z" fill="{bg}"/></svg>'''
                svg_r = f'''<svg width="8" height="32" viewBox="0 0 8 32"><path d="M0,0 C5,0 8,6 8,16 C8,26 5,32 0,32 Z" fill="{bg}"/></svg>'''
                tabs_html.append(f"""
                <div style="display:flex;align-items:center;margin-right:4px;height:32px;">
                    {svg_l}
                    <div style="background:{bg};color:{fg};font-weight:{weight};height:32px;display:flex;align-items:center;padding:0 5px;font-size:12px;">
                        {sym}{t['num']} {t['dir']} <span style="margin-left:5px;opacity:0.5;font-size:11px;">✕</span>
                    </div>
                    {svg_r}
                </div>
                """)
            elif pw_type == "slant":
                svg = f'''<svg width="10" height="34" viewBox="0 0 10 34"><polygon points="0,0 10,0 0,34" fill="{bg}"/><polygon points="10,0 0,34 10,34" fill="{next_bg}"/></svg>'''
                tabs_html.append(f"""
                <div style="display:flex;align-items:center;height:34px;background:{next_bg};">
                    <div style="background:{bg};color:{fg};font-weight:{weight};height:34px;display:flex;align-items:center;padding:0 6px 0 10px;font-size:12px;">
                        {sym}{t['num']} {t['dir']} <span style="margin-left:5px;opacity:0.5;font-size:11px;">✕</span>
                    </div>
                    {svg}
                </div>
                """)
            else:
                tabs_html.append(f"""
                <div style="background:{bg};color:{fg};font-weight:{weight};height:32px;display:flex;align-items:center;padding:0 10px;margin-right:3px;border-radius:4px;font-size:12px;">
                    {sym}{t['num']} {t['dir']} <span style="margin-left:5px;opacity:0.5;font-size:11px;">✕</span>
                </div>
                """)

    elif style == "left_bar":
        for i, t in enumerate(tabs_data):
            c = palette[i % len(palette)]
            if t["active"]:
                tabs_html.append(f"""
                <div style="background:{c['bg']};color:{c['fg']};font-weight:bold;height:{tab_height};display:flex;align-items:center;padding:0 10px;margin-right:4px;border-left:4px solid #ffffff;font-size:{font_size};">
                    ▌ {t['num']} {t['dir']} <span style="margin-left:7px;opacity:0.6;font-size:11px;">✕</span>
                </div>
                """)
            else:
                tabs_html.append(f"""
                <div style="background:#1a1c23;color:{c['bg']};height:{tab_height};display:flex;align-items:center;padding:0 10px;margin-right:4px;border-left:4px solid {c['bg']};font-size:{font_size};">
                    {t['num']} {t['dir']} <span style="margin-left:7px;opacity:0.4;font-size:11px;">✕</span>
                </div>
                """)

    elif style == "top_neon":
        for i, t in enumerate(tabs_data):
            c = palette[i % len(palette)]
            if t["active"]:
                tabs_html.append(f"""
                <div style="background:rgba(255,255,255,0.08);color:{c['bg']};font-weight:bold;height:{tab_height};display:flex;align-items:center;padding:0 10px;margin-right:4px;border-top:3px solid {c['bg']};box-shadow:0 -2px 10px {c['bg']}88;font-size:{font_size};">
                    ⚡ {t['num']} {t['dir']} <span style="margin-left:7px;opacity:0.6;font-size:11px;">✕</span>
                </div>
                """)
            else:
                tabs_html.append(f"""
                <div style="background:#111219;color:#94a3b8;height:{tab_height};display:flex;align-items:center;padding:0 10px;margin-right:4px;border-top:3px solid {c['bg']};font-size:{font_size};">
                    {t['num']} {t['dir']} <span style="margin-left:7px;opacity:0.4;font-size:11px;">✕</span>
                </div>
                """)

    elif style == "ghost":
        for i, t in enumerate(tabs_data):
            c = palette[i % len(palette)]
            if t["active"]:
                tabs_html.append(f"""
                <div style="background:rgba(255,255,255,0.16);color:{c['bg']};font-weight:bold;height:30px;display:flex;align-items:center;padding:0 10px;margin-right:6px;border-radius:4px;font-size:{font_size};">
                    ● {t['num']} {t['dir']} <span style="margin-left:7px;opacity:0.6;font-size:11px;">✕</span>
                </div>
                """)
            else:
                tabs_html.append(f"""
                <div style="background:rgba(255,255,255,0.03);color:{c['bg']};height:30px;display:flex;align-items:center;padding:0 10px;margin-right:6px;border:1px solid {c['bg']}44;border-radius:4px;font-size:{font_size};">
                    ○ {t['num']} {t['dir']} <span style="margin-left:7px;opacity:0.4;font-size:11px;">✕</span>
                </div>
                """)

    elif style == "outline":
        for i, t in enumerate(tabs_data):
            c = palette[i % len(palette)]
            if t["active"]:
                tabs_html.append(f"""
                <div style="background:{c['bg']};color:{c['fg']};font-weight:bold;height:30px;display:flex;align-items:center;padding:0 10px;margin-right:6px;border-radius:6px;font-size:{font_size};">
                    【 {t['num']} {t['dir']} 】<span style="margin-left:6px;opacity:0.7;font-size:11px;">✕</span>
                </div>
                """)
            else:
                tabs_html.append(f"""
                <div style="background:#161822;color:{c['bg']};height:30px;display:flex;align-items:center;padding:0 10px;margin-right:6px;border-radius:6px;border:1.5px solid {c['bg']};font-size:{font_size};">
                    〔 {t['num']} {t['dir']} 〕<span style="margin-left:6px;opacity:0.4;font-size:11px;">✕</span>
                </div>
                """)

    elif style == "smart_badges":
        badges = ["GIT:main", "IDLE", "SSH", "GCP"]
        for i, t in enumerate(tabs_data):
            c = palette[i % len(palette)]
            weight = "bold" if t["active"] else "500"
            tabs_html.append(f"""
            <div style="background:{c['bg']};color:{c['fg']};font-weight:{weight};height:32px;display:flex;align-items:center;padding:0 10px;margin-right:5px;border-radius:6px;font-size:{font_size};">
                <span style="background:rgba(0,0,0,0.3);color:#fff;border-radius:4px;padding:1px 5px;margin-right:6px;font-size:9.5px;font-weight:700;">{badges[i]}</span>
                {t['num']} {t['dir']} <span style="margin-left:6px;opacity:0.6;font-size:11px;">✕</span>
            </div>
            """)

    elif style == "circle_numbers":
        nums_active = ["❶", "❷", "❸", "❹"]
        nums_inactive = ["①", "②", "③", "④"]
        for i, t in enumerate(tabs_data):
            c = palette[i % len(palette)]
            sym = nums_active[i] if t["active"] else nums_inactive[i]
            weight = "bold" if t["active"] else "500"
            tabs_html.append(f"""
            <div style="background:{c['bg']};color:{c['fg']};font-weight:{weight};height:32px;display:flex;align-items:center;padding:0 12px;margin-right:5px;border-radius:9999px;font-size:{font_size};">
                <span style="font-size:14px;margin-right:6px;">{sym}</span> {t['dir']} <span style="margin-left:6px;opacity:0.6;font-size:11px;">✕</span>
            </div>
            """)

    elif style == "pulse_dots":
        dots = ["🟢", "🔴", "🟡", "⚪"]
        for i, t in enumerate(tabs_data):
            c = palette[i % len(palette)]
            weight = "bold" if t["active"] else "500"
            tabs_html.append(f"""
            <div style="background:{c['bg']};color:{c['fg']};font-weight:{weight};height:32px;display:flex;align-items:center;padding:0 10px;margin-right:5px;border-radius:6px;font-size:{font_size};">
                <span style="font-size:11px;margin-right:5px;">{dots[i]}</span> {t['num']} {t['dir']} <span style="margin-left:6px;opacity:0.6;font-size:11px;">✕</span>
            </div>
            """)

    elif style == "crt_amber":
        for i, t in enumerate(tabs_data):
            c = palette[i % len(palette)]
            marker = "*" if t["active"] else "-"
            weight = "bold" if t["active"] else "normal"
            tabs_html.append(f"""
            <div style="background:{c['bg']};color:{c['fg']};font-weight:{weight};height:32px;display:flex;align-items:center;padding:0 10px;margin-right:4px;border:1px solid {c['fg']}88;font-size:{font_size};font-family:monospace;">
                [{marker} {t['num']:02d}:{t['dir'].upper()} {marker}] <span style="margin-left:6px;opacity:0.7;">[X]</span>
            </div>
            """)

    elif style == "underline":
        for i, t in enumerate(tabs_data):
            c = palette[i % len(palette)]
            if t["active"]:
                tabs_html.append(f"""
                <div style="background:{c['bg']};color:{c['fg']};font-weight:bold;height:{tab_height};display:flex;align-items:center;padding:0 12px;margin-right:3px;border-bottom:3px solid #ffffff;font-size:{font_size};">
                    ⚡ 🔵 ➜ {t['num']} {t['dir']} <span style="margin-left:6px;opacity:0.6;font-size:11px;">✕</span>
                </div>
                """)
            else:
                tabs_html.append(f"""
                <div style="background:#181922;color:{c['bg']};height:{tab_height};display:flex;align-items:center;padding:0 12px;margin-right:3px;border-bottom:3px solid {c['bg']};font-size:{font_size};">
                    {t['num']} 🔘 {t['dir']} <span style="margin-left:6px;opacity:0.4;font-size:11px;">✕</span>
                </div>
                """)

    else:
        # Default: full color cycling tabs (pills / google_cycle / palette_cycle)
        is_pill = "pill" in style or style == "pills"
        border_radius = "9999px" if is_pill else ("4px 4px 0 0" if "google" in style else "5px")
        for i, t in enumerate(tabs_data):
            c = palette[i % len(palette)]
            if t["active"]:
                sym = c.get("active_sym", "⚡ ➜ ")
                border_bottom = "border-bottom: 2px solid rgba(255,255,255,0.85);" if ("google" in style or not is_pill) else ""
                box_shadow = "box-shadow: 0 2px 8px rgba(0,0,0,0.35);"
                tabs_html.append(f"""
                <div style="background:{c['bg']};color:{c['fg']};font-weight:700;height:{tab_height};display:flex;align-items:center;padding:0 11px;margin-right:4px;font-size:{font_size};border-radius:{border_radius};{border_bottom}{box_shadow}">
                    {sym}{t['num']} {t['dir']} <span style="margin-left:6px;opacity:0.65;font-size:11px;">✕</span>
                </div>
                """)
            else:
                sym = c.get("inactive_sym", " 🔘")
                tabs_html.append(f"""
                <div style="background:{c['bg']};color:{c['fg']};opacity:0.9;font-weight:500;height:{tab_height};display:flex;align-items:center;padding:0 11px;margin-right:4px;font-size:{font_size};border-radius:{border_radius};">
                    {t['num']}{sym} {t['dir']} <span style="margin-left:6px;opacity:0.5;font-size:11px;">✕</span>
                </div>
                """)

    plus_html = f"""<div style="background:#222430;color:#64748b;width:26px;height:{tab_height};border-radius:9999px;display:flex;align-items:center;justify-content:center;margin-left:3px;font-size:13px;">+</div>"""

    html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  @import url('https://fonts.googleapis.com/css2?family=Victor+Mono:wght@400;600;700&family=JetBrains+Mono:wght@400;600;700&display=swap');
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    width: 880px;
    height: 120px;
    background: #18191f;
    font-family: 'VictorMono Nerd Font Mono', 'JetBrains Mono', monospace;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
  }}
  .header-preview {{
    height: 56px;
    padding: 9px 16px;
    background: #1e1f26;
    border-bottom: 1px solid #282a36;
    display: flex;
    flex-direction: column;
    justify-content: center;
  }}
  .title-line {{
    display: flex;
    align-items: center;
    gap: 10px;
  }}
  .badge {{
    background: #3b82f6;
    color: white;
    font-size: 11px;
    font-weight: bold;
    padding: 2px 7px;
    border-radius: 4px;
  }}
  .cat-tag {{
    color: #94a3b8;
    font-size: 11px;
  }}
  .name {{
    color: #f1f5f9;
    font-size: 13.5px;
    font-weight: 700;
  }}
  .term-cmd {{
    color: #64748b;
    font-size: 11px;
    margin-top: 3px;
    font-family: monospace;
  }}
  .tab-bar {{
    height: 64px;
    background: {bg_bar};
    padding: 0 12px;
    display: flex;
    align-items: center;
    overflow: hidden;
  }}
</style>
</head>
<body>
  <div class="header-preview">
    <div class="title-line">
      <span class="badge">#{tid:02d}</span>
      <span class="name">{name}</span>
      <span class="cat-tag">• {cat}</span>
    </div>
    <div class="term-cmd">mvsoares@mvsoares2:~/projetos/linux-setup$ wezterm-tab-theme --set {tid}</div>
  </div>
  <div class="tab-bar">
    {''.join(tabs_html)}
    {plus_html}
  </div>
</body>
</html>"""
    return html


def render_single_theme(args):
    theme, output_png = args
    tid = theme["id"]
    html_content = make_html_for_theme(theme)
    tmp_html = OUTPUT_DIR / f"_temp_render_{tid:02d}.html"

    with open(tmp_html, "w", encoding="utf-8") as f:
        f.write(html_content)

    cmd = [
        "google-chrome",
        "--headless",
        "--disable-gpu",
        "--hide-scrollbars",
        "--window-size=880,120",
        f"--screenshot={str(output_png)}",
        str(tmp_html),
    ]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if tmp_html.exists():
        tmp_html.unlink()

    # Also copy to artifact dir
    artifact_png = ARTIFACT_DIR / output_png.name
    try:
        shutil.copy2(output_png, artifact_png)
    except Exception:
        pass

    return tid, str(output_png)


def build_composite_image(themes, rendered_map):
    print("Building composite image for all 60 themes...")
    categories = {}
    for t in themes:
        cat = t["category"]
        if cat not in categories:
            categories[cat] = []
        if t["id"] in rendered_map:
            categories[cat].append((t, rendered_map[t["id"]]))

    width = 1900
    header_height = 140
    cat_header_height = 50
    item_height = 120
    item_gap = 16
    cat_gap = 35

    total_height = header_height
    for cat, items in categories.items():
        rows = (len(items) + 1) // 2
        total_height += cat_header_height + rows * (item_height + item_gap) + cat_gap

    canvas = Image.new("RGB", (width, total_height), color="#111217")
    draw = ImageDraw.Draw(canvas)

    try:
        font_title = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 36)
        font_sub = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
        font_cat = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
    except Exception:
        font_title = font_sub = font_cat = ImageFont.load_default()

    draw.rectangle([(0, 0), (width, header_height - 20)], fill="#181920")
    draw.line([(0, header_height - 20), (width, header_height - 20)], fill="#2a2c38", width=2)
    draw.text((60, 28), "WEZTERM TAB-BAR — CATÁLOGO COMPLETO (60 TEMAS)", fill="#60a5fa", font=font_title)
    draw.text((60, 78), "Coleção com Google/Material, Geometrias Powerline, Paletas Devs (Monokai, Synth-Shell), Natureza e CRT Amber", fill="#94a3b8", font=font_sub)

    y = header_height
    for cat_name, items in categories.items():
        draw.rectangle([(50, y), (width - 50, y + cat_header_height - 10)], fill="#1f212d")
        draw.rectangle([(50, y), (56, y + cat_header_height - 10)], fill="#3b82f6")
        draw.text((70, y + 8), cat_name.upper(), fill="#f8fafc", font=font_cat)
        y += cat_header_height

        for i in range(0, len(items), 2):
            t1, file1 = items[i]
            if os.path.exists(file1):
                img1 = Image.open(file1)
                canvas.paste(img1, (60, y))

            if i + 1 < len(items):
                t2, file2 = items[i + 1]
                if os.path.exists(file2):
                    img2 = Image.open(file2)
                    canvas.paste(img2, (60 + 880 + 20, y))

            y += item_height + item_gap
        y += cat_gap

    composite_path = OUTPUT_DIR / "00_catalogo_completo_60_sugestoes.png"
    canvas.save(composite_path, quality=95)
    print(f"Composite catalog saved to {composite_path} ({width}x{total_height})")

    # Also save to artifact dir
    artifact_composite = ARTIFACT_DIR / "00_catalogo_completo_60_sugestoes.png"
    try:
        shutil.copy2(composite_path, artifact_composite)
    except Exception:
        pass


def build_interactive_html(themes):
    print("Building interactive HTML catalogs...")
    categories = list(dict.fromkeys(t["category"] for t in themes))

    cards_html = []
    for t in themes:
        tid = t["id"]
        name = t["name"]
        cat = t["category"]
        desc = t.get("description", "")
        slug = slugify(name)
        img_name = f"tab_theme_{tid:02d}_{slug}.png"

        # Swatches
        swatches = []
        if "palette" in t:
            for p in t["palette"][:6]:
                pbg = p.get("bg", "#3b82f6")
                swatches.append(f'<span class="swatch" style="background:{pbg};" title="{pbg}"></span>')
        else:
            if "active_bg" in t:
                abg = t["active_bg"]
                swatches.append(f'<span class="swatch" style="background:{abg};" title="Active: {abg}"></span>')
            if "inactive_bg" in t:
                ibg = t["inactive_bg"]
                swatches.append(f'<span class="swatch" style="background:{ibg};" title="Inactive: {ibg}"></span>')
            if "bg_bar" in t:
                bbg = t["bg_bar"]
                swatches.append(f'<span class="swatch" style="background:{bbg};" title="Bar: {bbg}"></span>')

        cards_html.append(f"""
        <div class="card" data-id="{tid}" data-cat="{cat}" data-name="{name.lower()}">
          <div class="card-header">
            <span class="badge-num">#{tid:02d}</span>
            <div class="card-title">
              <h3>{name}</h3>
              <span class="card-cat">{cat}</span>
            </div>
            <div class="swatches">{''.join(swatches)}</div>
          </div>
          <div class="card-img-wrap">
            <img src="{img_name}" alt="{name}" loading="lazy">
          </div>
          <div class="card-desc">
            {desc}
          </div>
          <div class="card-actions">
            <code class="cmd-code">wezterm-tab-theme --set {tid}</code>
            <button class="copy-btn" onclick="copyCmd('wezterm-tab-theme --set {tid}', this)">Copiar Comando</button>
          </div>
        </div>
        """)

    filter_buttons = ['<button class="filter-btn active" data-filter="all">Todos (60)</button>']
    for c in categories:
        count = sum(1 for t in themes if t["category"] == c)
        filter_buttons.append(f'<button class="filter-btn" data-filter="{c}">{c} ({count})</button>')

    html = f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>WezTerm Tab Themes Gallery (60 Temas)</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      background: #0d1117;
      color: #c9d1d9;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Victor Mono", monospace;
      padding: 30px 40px;
      line-height: 1.5;
    }}
    header {{
      margin-bottom: 25px;
      padding-bottom: 20px;
      border-bottom: 1px solid #21262d;
    }}
    .title-row {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 15px;
    }}
    h1 {{
      font-size: 26px;
      color: #58a6ff;
      display: flex;
      align-items: center;
      gap: 12px;
    }}
    .subtitle {{
      color: #8b949e;
      font-size: 14px;
      margin-top: 6px;
    }}
    .cli-box {{
      background: #161b22;
      border: 1px solid #30363d;
      border-radius: 8px;
      padding: 12px 18px;
      display: flex;
      align-items: center;
      gap: 12px;
    }}
    .cli-box code {{
      color: #7ee787;
      font-size: 14px;
      font-weight: 600;
      font-family: monospace;
    }}
    .controls {{
      display: flex;
      flex-direction: column;
      gap: 15px;
      margin-bottom: 25px;
    }}
    .search-input {{
      background: #161b22;
      border: 1px solid #30363d;
      color: #e6edf3;
      padding: 10px 16px;
      border-radius: 8px;
      font-size: 14px;
      width: 100%;
      max-width: 480px;
      outline: none;
    }}
    .search-input:focus {{
      border-color: #58a6ff;
    }}
    .filter-bar {{
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
    }}
    .filter-btn {{
      background: #161b22;
      border: 1px solid #30363d;
      color: #8b949e;
      padding: 6px 14px;
      border-radius: 20px;
      cursor: pointer;
      font-size: 13px;
      transition: all 0.2s ease;
    }}
    .filter-btn:hover, .filter-btn.active {{
      background: #1f6feb;
      color: #ffffff;
      border-color: #1f6feb;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(420px, 1fr));
      gap: 20px;
    }}
    .card {{
      background: #161b22;
      border: 1px solid #30363d;
      border-radius: 10px;
      overflow: hidden;
      display: flex;
      flex-direction: column;
      transition: transform 0.15s ease, border-color 0.15s ease;
    }}
    .card:hover {{
      transform: translateY(-2px);
      border-color: #58a6ff;
    }}
    .card-header {{
      padding: 12px 16px;
      background: #1c2128;
      border-bottom: 1px solid #30363d;
      display: flex;
      align-items: center;
      gap: 12px;
    }}
    .badge-num {{
      background: #238636;
      color: #fff;
      font-weight: 700;
      font-size: 12px;
      padding: 3px 8px;
      border-radius: 6px;
    }}
    .card-title h3 {{
      font-size: 14.5px;
      color: #f0f6fc;
    }}
    .card-cat {{
      font-size: 11.5px;
      color: #8b949e;
    }}
    .swatches {{
      margin-left: auto;
      display: flex;
      gap: 5px;
    }}
    .swatch {{
      width: 14px;
      height: 14px;
      border-radius: 50%;
      border: 1px solid rgba(255,255,255,0.2);
      display: inline-block;
    }}
    .card-img-wrap {{
      width: 100%;
      background: #090d13;
      border-bottom: 1px solid #21262d;
    }}
    .card-img-wrap img {{
      width: 100%;
      height: auto;
      display: block;
    }}
    .card-desc {{
      padding: 12px 16px;
      font-size: 12.5px;
      color: #8b949e;
      flex: 1;
    }}
    .card-actions {{
      padding: 10px 16px;
      background: #1c2128;
      border-top: 1px solid #30363d;
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 10px;
    }}
    .cmd-code {{
      background: #0d1117;
      border: 1px solid #30363d;
      color: #79c0ff;
      padding: 4px 8px;
      border-radius: 4px;
      font-size: 12px;
      font-family: monospace;
      flex: 1;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }}
    .copy-btn {{
      background: #238636;
      border: none;
      color: #fff;
      padding: 5px 12px;
      border-radius: 6px;
      font-size: 12px;
      cursor: pointer;
      font-weight: 600;
      transition: background 0.2s;
      white-space: nowrap;
    }}
    .copy-btn:hover {{
      background: #2ea043;
    }}
    .toast {{
      position: fixed;
      bottom: 20px;
      right: 20px;
      background: #238636;
      color: #fff;
      padding: 10px 18px;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.4);
      display: none;
      font-size: 13px;
      font-weight: 600;
      z-index: 1000;
    }}
  </style>
</head>
<body>
  <header>
    <div class="title-row">
      <div>
        <h1>⚡ WezTerm Tab Bar Themes Gallery</h1>
        <div class="subtitle">60 temas visuais de alta definição categorizados • Recarregamento instantâneo sem reiniciar sessões</div>
      </div>
      <div class="cli-box">
        <span>Terminal:</span>
        <code>wezterm-tab-theme</code>
      </div>
    </div>
  </header>

  <div class="controls">
    <input type="text" class="search-input" id="search" placeholder="🔍 Buscar tema por nome, categoria, estilo ou número...">
    <div class="filter-bar">
      {''.join(filter_buttons)}
    </div>
  </div>

  <div class="grid" id="grid">
    {''.join(cards_html)}
  </div>

  <div class="toast" id="toast">Comando copiado para a área de transferência!</div>

  <script>
    function copyCmd(cmd, btn) {{
      navigator.clipboard.writeText(cmd).then(() => {{
        const toast = document.getElementById('toast');
        toast.textContent = 'Comando copiado: ' + cmd;
        toast.style.display = 'block';
        setTimeout(() => {{ toast.style.display = 'none'; }}, 2500);
      }});
    }}

    const search = document.getElementById('search');
    const filterBtns = document.querySelectorAll('.filter-btn');
    const cards = document.querySelectorAll('.card');

    let activeFilter = 'all';

    function applyFilters() {{
      const query = search.value.toLowerCase().trim();
      cards.forEach(card => {{
        const cat = card.getAttribute('data-cat');
        const name = card.getAttribute('data-name');
        const id = card.getAttribute('data-id');
        const matchesCat = (activeFilter === 'all') || (cat === activeFilter);
        const matchesQuery = !query || name.includes(query) || cat.toLowerCase().includes(query) || id === query;
        if (matchesCat && matchesQuery) {{
          card.style.display = 'flex';
        }} else {{
          card.style.display = 'none';
        }}
      }});
    }}

    search.addEventListener('input', applyFilters);

    filterBtns.forEach(btn => {{
      btn.addEventListener('click', () => {{
        filterBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        activeFilter = btn.getAttribute('data-filter');
        applyFilters();
      }});
    }});
  </script>
</body>
</html>"""

    tmp_html = OUTPUT_DIR / "catalogo_interativo.html"
    with open(tmp_html, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Interactive HTML saved to {tmp_html}")

    repo_html = REPO_ROOT / "wezterm-tab-color-preview.html"
    with open(repo_html, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Repo preview HTML saved to {repo_html}")


def main():
    print(f"Rendering all {len(THEMES)} WezTerm themes with multiprocessing...")
    tasks = []
    for t in THEMES:
        tid = t["id"]
        slug = slugify(t["name"])
        out_png = OUTPUT_DIR / f"tab_theme_{tid:02d}_{slug}.png"
        tasks.append((t, out_png))

    with multiprocessing.Pool(processes=multiprocessing.cpu_count()) as pool:
        results = pool.map(render_single_theme, tasks)

    rendered_map = {tid: png_path for tid, png_path in results}
    print(f"Successfully rendered {len(rendered_map)} themes to PNG!")

    build_composite_image(THEMES, rendered_map)
    build_interactive_html(THEMES)
    print("All tasks completed successfully!")


if __name__ == "__main__":
    main()
