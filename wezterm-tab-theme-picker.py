#!/usr/bin/env python3
"""Interactive WezTerm Tab Theme Picker with Live Terminal Preview.

Supports 60 themes with 4-tab color previews, category navigation,
and instant switching without restart.
"""

import argparse
import os
import random
import re
import shutil
import signal
import subprocess
import sys
import unicodedata
import webbrowser
from datetime import datetime
from pathlib import Path

# Prevent BrokenPipeError when piping to head/less
try:
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
except Exception:
    pass

# Add lib/ to sys.path
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR / "lib"))

from wezterm_tab_themes import THEMES, get_theme_by_id, find_theme, generate_lua_for_theme

CONFIG_DIR = Path.home() / ".config" / "wezterm"
CONFIG_FILE = CONFIG_DIR / "wezterm.lua"
THEME_FILE = CONFIG_DIR / "tab_theme.lua"
REPO_THEME_FILE = SCRIPT_DIR / "lib" / "wezterm_tab_theme.lua"
BACKUP_DIR = CONFIG_DIR / "backups"
HTML_PATH = SCRIPT_DIR / "wezterm-tab-color-preview.html"
TMP_HTML_PATH = Path("/home/mvsoares/tmp/catalogo_interativo.html")

RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
CYAN = "\033[36m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
BLUE = "\033[34m"
MAGENTA = "\033[35m"
RED = "\033[31m"

_ANSI_RE = re.compile(r"\033\[[0-9;]*m")

CATEGORIES = [
    ("c1", "Google & Material", 1, 10),
    ("c2", "Powerline & Geometrias", 11, 20),
    ("c3", "Paletas Populares Devs", 21, 30),
    ("c4", "Synth & Cyberpunk", 31, 40),
    ("c5", "Natureza & Tons Terrosos", 41, 50),
    ("c6", "Minimalista, Badges & CRT", 51, 60),
]


def hex_to_rgb(hex_str: str) -> tuple[int, int, int]:
    h = hex_str.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def ansi_fg(hex_str: str) -> str:
    r, g, b = hex_to_rgb(hex_str)
    return f"\033[38;2;{r};{g};{b}m"


def ansi_bg(hex_str: str) -> str:
    r, g, b = hex_to_rgb(hex_str)
    return f"\033[48;2;{r};{g};{b}m"


def visible_len(s: str) -> int:
    plain = _ANSI_RE.sub("", s)
    w = 0
    for ch in plain:
        cat = unicodedata.east_asian_width(ch)
        w += 2 if cat in ("W", "F") else 1
    return w


def detect_current_theme_id() -> int:
    """Read active theme ID from tab_theme.lua if present, default to 10."""
    if not THEME_FILE.exists():
        return 10
    try:
        content = THEME_FILE.read_text(encoding="utf-8")
        m = re.search(r"-- Theme #(\d+):", content)
        if m:
            return int(m.group(1))
    except Exception:
        pass
    return 10


def detect_current_tab_title_len() -> int:
    """Read TAB_TITLE_LEN from tab_theme.lua if present, default to 15."""
    if not THEME_FILE.exists():
        return 15
    try:
        content = THEME_FILE.read_text(encoding="utf-8")
        m = re.search(r"TAB_TITLE_LEN\s*=\s*(\d+)", content)
        if m:
            return int(m.group(1))
    except Exception:
        pass
    return 15


def backup_current_config(label: str = None) -> Path | None:
    """Create a timestamped backup of tab_theme.lua (and wezterm.lua if labeled)."""
    if not THEME_FILE.exists():
        return None
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    clean_label = f"_{re.sub(r'[^a-zA-Z0-9_-]', '_', label)}" if label else ""
    dest = BACKUP_DIR / f"tab_theme.lua.{stamp}{clean_label}.bak"
    shutil.copy2(THEME_FILE, dest)

    # If label is given (manual backup), also back up wezterm.lua
    if label and CONFIG_FILE.exists():
        dest_main = BACKUP_DIR / f"wezterm.lua.{stamp}{clean_label}.bak"
        shutil.copy2(CONFIG_FILE, dest_main)

    return dest


def get_available_backups() -> list[dict]:
    """Retrieve and parse all saved tab_theme backups sorted newest first."""
    if not BACKUP_DIR.exists():
        return []
    backups = []
    for f in BACKUP_DIR.glob("tab_theme.lua.*.bak"):
        m = re.search(r"tab_theme\.lua\.(\d{8}-\d{6})(?:_(.+))?\.bak", f.name)
        date_str = ""
        label = ""
        if m:
            raw_stamp = m.group(1)
            label = m.group(2) or ""
            try:
                dt = datetime.strptime(raw_stamp, "%Y%m%d-%H%M%S")
                date_str = dt.strftime("%d/%m/%Y %H:%M:%S")
            except Exception:
                date_str = raw_stamp
        else:
            mtime = datetime.fromtimestamp(f.stat().st_mtime)
            date_str = mtime.strftime("%d/%m/%Y %H:%M:%S")

        theme_info = "Configuração Personalizada"
        theme_id = None
        try:
            content = f.read_text(encoding="utf-8", errors="replace")
            tm = re.search(r"-- Theme #(\d+):\s*([^\n\r]+)", content)
            if tm:
                theme_id = int(tm.group(1))
                theme_info = f"Tema #{theme_id:02d}: {tm.group(2).strip()}"
        except Exception:
            pass

        backups.append({
            "path": f,
            "filename": f.name,
            "date_str": date_str,
            "label": label,
            "theme_info": theme_info,
            "theme_id": theme_id,
            "mtime": f.stat().st_mtime,
        })

    backups.sort(key=lambda b: b["mtime"], reverse=True)
    return backups


def restore_backup(target_spec: str | int = 1) -> tuple[bool, str]:
    """Restore a backup by 1-based index, filename, or label match."""
    backups = get_available_backups()
    if not backups:
        return False, f"Nenhum backup encontrado em {BACKUP_DIR}"

    selected = None
    spec_str = str(target_spec).strip()
    if spec_str.isdigit():
        idx = int(spec_str) - 1
        if 0 <= idx < len(backups):
            selected = backups[idx]
        else:
            return False, f"Índice de backup inválido: {spec_str}. Escolha entre 1 e {len(backups)}."
    else:
        for b in backups:
            if spec_str in b["filename"] or (b["label"] and spec_str.lower() in b["label"].lower()):
                selected = b
                break
        if not selected:
            return False, f"Nenhum backup correspondente a '{spec_str}'."

    try:
        content = selected["path"].read_text(encoding="utf-8")
        # Defensive fix: sanitize any obsolete field in legacy backups
        content = content.replace("show_tab_index_in_tab_title", "show_tab_index_in_tab_bar")

        # Save a safety backup before restoring
        backup_current_config(label="pre_restore")

        THEME_FILE.write_text(content, encoding="utf-8")
        REPO_THEME_FILE.parent.mkdir(parents=True, exist_ok=True)
        REPO_THEME_FILE.write_text(content, encoding="utf-8")

        if CONFIG_FILE.exists():
            CONFIG_FILE.touch()

        # Validate with WezTerm
        try:
            subprocess.run(
                ["wezterm", "--config-file", str(CONFIG_FILE), "show-keys"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=3,
            )
        except Exception:
            pass

        idx_display = backups.index(selected) + 1
        return True, f"Backup [{idx_display}] ({selected['theme_info']} - {selected['date_str']}) restaurado com sucesso!"
    except Exception as e:
        return False, f"Erro ao restaurar backup: {e}"


def print_backups_list(backups: list[dict]):
    """Print a clean formatted list of available backups."""
    print(f"\n{BOLD}{CYAN}=== BACKUPS DE CONFIGURAÇÃO DE ABAS WEZTERM ==={RESET}\n")
    if not backups:
        print(f"  {YELLOW}Nenhum backup encontrado em {BACKUP_DIR}.{RESET}\n")
        return

    cur_id = detect_current_theme_id()
    for idx, b in enumerate(backups, start=1):
        is_cur = (b.get("theme_id") == cur_id)
        cur_tag = f" {GREEN}{BOLD}← ATUAL{RESET}" if is_cur else ""
        label_str = f" [{YELLOW}{BOLD}{b['label']}{RESET}]" if b['label'] else ""
        print(f"  {BOLD}[{idx:02d}]{RESET}  {CYAN}{b['date_str']}{RESET}  {BOLD}{b['theme_info']:<48}{RESET}{label_str}{cur_tag}")
        print(f"        {DIM}Arquivo: {b['path']}{RESET}")
    print(f"\nPara restaurar, execute: {BOLD}wezterm-tab-theme --restore <NUMERO>{RESET} (ex: wezterm-tab-theme --restore 1)\n")


def interactive_restore_menu() -> str:
    """Interactive screen to choose and restore a previous backup."""
    backups = get_available_backups()
    if not backups:
        return f"{YELLOW}Nenhum backup disponível para restauração.{RESET}"

    print("\033[2J\033[H", end="")
    print(f"{BOLD}{BLUE}╔════════════════════════════════════════════════════════════════════════════════════════╗{RESET}")
    print(f"{BOLD}{BLUE}║  ↺ RESTAURAR BACKUP DA CONFIGURAÇÃO DE ABAS WEZTERM                                   ║{RESET}")
    print(f"{BOLD}{BLUE}╚════════════════════════════════════════════════════════════════════════════════════════╝{RESET}")

    print_backups_list(backups)
    print(f"  {DIM}Digite o número do backup (1-{len(backups)}) para restaurar, ou [q] para cancelar.{RESET}\n")

    try:
        ans = input(f"  {BOLD}{CYAN}❯ Escolha o número do backup para restaurar (1-{len(backups)}):{RESET} ").strip()
    except (KeyboardInterrupt, EOFError):
        return "Restauração cancelada."

    if not ans or ans.lower() in ("q", "quit", "cancel", "voltar"):
        return "Restauração cancelada."

    success, msg = restore_backup(ans)
    if success:
        return f"{GREEN}{BOLD}✔ {msg}{RESET}"
    else:
        return f"{RED}✖ {msg}{RESET}"


def apply_theme(theme: dict, tab_title_len: int = None) -> tuple[bool, Path | None]:
    """Generate and write tab_theme.lua, create automatic backup, and notify WezTerm."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    bkp_path = backup_current_config()

    if tab_title_len is None:
        tab_title_len = detect_current_tab_title_len()

    lua_code = generate_lua_for_theme(theme, tab_title_len=tab_title_len)
    THEME_FILE.write_text(lua_code, encoding="utf-8")

    REPO_THEME_FILE.parent.mkdir(parents=True, exist_ok=True)
    REPO_THEME_FILE.write_text(lua_code, encoding="utf-8")

    if CONFIG_FILE.exists():
        CONFIG_FILE.touch()

    try:
        res = subprocess.run(
            ["wezterm", "--config-file", str(CONFIG_FILE), "show-keys"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=3,
        )
        return (res.returncode == 0, bkp_path)
    except Exception:
        return (True, bkp_path)


def render_4_tab_bar(theme: dict) -> str:
    """Render a 4-tab bar in ANSI showcasing the theme's 4 distinct palette colors."""
    pal = theme.get("palette", [])
    if len(pal) < 4:
        pal = [
            {"bg": "#4285F4", "fg": "#ffffff", "active_sym": "⚡ 🔵 ➜ ", "inactive_sym": " 🔘"},
            {"bg": "#EA4335", "fg": "#ffffff", "active_sym": "⚡ 🔴 ➜ ", "inactive_sym": " 🔘"},
            {"bg": "#34A853", "fg": "#ffffff", "active_sym": "⚡ 🟢 ➜ ", "inactive_sym": " 🔘"},
            {"bg": "#FBBC05", "fg": "#ffffff", "active_sym": "⚡ 🟠 ➜ ", "inactive_sym": " 🔘"},
        ]

    p0, p1, p2, p3 = pal[0], pal[1], pal[2], pal[3]
    style = theme.get("style", "pills")
    bg_bar = theme.get("bg_bar", "#15161c")

    if style == "powerline":
        sep = theme.get("sep_char", "")
        t0 = f"{ansi_bg(p0['bg'])}{ansi_fg(p0['fg'])}{BOLD} {p0.get('active_sym', '⚡ ')}1 setup {ansi_bg(p1['bg'])}{ansi_fg(p0['bg'])}{sep}"
        t1 = f"{ansi_bg(p1['bg'])}{ansi_fg(p1['fg'])} 2 mvsoares {ansi_bg(p2['bg'])}{ansi_fg(p1['bg'])}{sep}"
        t2 = f"{ansi_bg(p2['bg'])}{ansi_fg(p2['fg'])} 3 careplus {ansi_bg(p3['bg'])}{ansi_fg(p2['bg'])}{sep}"
        t3 = f"{ansi_bg(p3['bg'])}{ansi_fg(p3['fg'])} 4 cloud-run {ansi_bg(bg_bar)}{ansi_fg(p3['bg'])}{sep}{RESET}"
        return f"{ansi_bg(bg_bar)} {t0}{t1}{t2}{t3} {RESET}"

    elif style == "smart_badges":
        t0 = f"{ansi_bg(p0['bg'])}{ansi_fg(p0['fg'])}{BOLD} 󰊢 1 setup ✕ {RESET}"
        t1 = f"{ansi_bg(p1['bg'])}{ansi_fg(p1['fg'])} 󰅩 2 mvsoares ✕ {RESET}"
        t2 = f"{ansi_bg(p2['bg'])}{ansi_fg(p2['fg'])} 󰒋 3 careplus ✕ {RESET}"
        t3 = f"{ansi_bg(p3['bg'])}{ansi_fg(p3['fg'])} 󰜎 4 cloud-run ✕ {RESET}"
        return f"{ansi_bg(bg_bar)}  {t0}  {t1}  {t2}  {t3}  {RESET}"

    elif style == "circle_numbers":
        t0 = f"{ansi_bg(p0['bg'])}{ansi_fg(p0['fg'])}{BOLD} ❶ setup ✕ {RESET}"
        t1 = f"{ansi_bg(p1['bg'])}{ansi_fg(p1['fg'])} ❷ mvsoares ✕ {RESET}"
        t2 = f"{ansi_bg(p2['bg'])}{ansi_fg(p2['fg'])} ❸ careplus ✕ {RESET}"
        t3 = f"{ansi_bg(p3['bg'])}{ansi_fg(p3['fg'])} ❹ cloud-run ✕ {RESET}"
        return f"{ansi_bg(bg_bar)}  {t0}  {t1}  {t2}  {t3}  {RESET}"

    elif style == "pulse_dots":
        t0 = f"{ansi_bg('#1e2029')}{ansi_fg(p0['bg'])}{BOLD} {p0.get('active_sym', '🔵 ')}1 setup ✕ {RESET}"
        t1 = f"{ansi_bg('#1e2029')}{ansi_fg(p1['bg'])} {p1.get('inactive_sym', '🔴 ')}2 mvsoares ✕ {RESET}"
        t2 = f"{ansi_bg('#1e2029')}{ansi_fg(p2['bg'])} {p2.get('inactive_sym', '🟢 ')}3 careplus ✕ {RESET}"
        t3 = f"{ansi_bg('#1e2029')}{ansi_fg(p3['bg'])} {p3.get('inactive_sym', '🟡 ')}4 cloud-run ✕ {RESET}"
        return f"{ansi_bg(bg_bar)}  {t0}  {t1}  {t2}  {t3}  {RESET}"

    elif style == "crt_amber":
        t0 = f"{ansi_bg(p0['bg'])}{ansi_fg(p0['fg'])}{BOLD} [* 01:SETUP *] {RESET}"
        t1 = f"{ansi_bg(p1['bg'])}{ansi_fg(p1['fg'])} [- 02:MVSOARES -] {RESET}"
        t2 = f"{ansi_bg(p2['bg'])}{ansi_fg(p2['fg'])} [- 03:CAREPLUS -] {RESET}"
        t3 = f"{ansi_bg(p3['bg'])}{ansi_fg(p3['fg'])} [- 04:CLOUD-RUN -] {RESET}"
        return f"{ansi_bg(bg_bar)} {t0} {t1} {t2} {t3} {RESET}"

    elif style == "left_bar":
        t0 = f"{ansi_bg('#1a1c23')}{ansi_fg(p0['bg'])}{BOLD} ▌ 1 setup ✕ {RESET}"
        t1 = f"{ansi_bg('#1a1c23')}{ansi_fg(p1['bg'])} ▌ 2 mvsoares ✕ {RESET}"
        t2 = f"{ansi_bg('#1a1c23')}{ansi_fg(p2['bg'])} ▌ 3 careplus ✕ {RESET}"
        t3 = f"{ansi_bg('#1a1c23')}{ansi_fg(p3['bg'])} ▌ 4 cloud-run ✕ {RESET}"
        return f"{ansi_bg(bg_bar)}  {t0}  {t1}  {t2}  {t3}  {RESET}"

    elif style == "ghost":
        t0 = f"{ansi_bg('#252836')}{ansi_fg(p0['bg'])}{BOLD} ● 1 setup ✕ {RESET}"
        t1 = f"{ansi_bg(bg_bar)}{ansi_fg(p1['bg'])} 2 mvsoares ✕ {RESET}"
        t2 = f"{ansi_bg(bg_bar)}{ansi_fg(p2['bg'])} 3 careplus ✕ {RESET}"
        t3 = f"{ansi_bg(bg_bar)}{ansi_fg(p3['bg'])} 4 cloud-run ✕ {RESET}"
        return f"{ansi_bg(bg_bar)}  {t0}   {t1}   {t2}   {t3}  {RESET}"

    elif style == "top_neon":
        t0 = f"{ansi_bg('#181a24')}{ansi_fg(p0['bg'])}{BOLD} ▔ 1 setup ✕ {RESET}"
        t1 = f"{ansi_bg('#181a24')}{ansi_fg(p1['bg'])} ▔ 2 mvsoares ✕ {RESET}"
        t2 = f"{ansi_bg('#181a24')}{ansi_fg(p2['bg'])} ▔ 3 careplus ✕ {RESET}"
        t3 = f"{ansi_bg('#181a24')}{ansi_fg(p3['bg'])} ▔ 4 cloud-run ✕ {RESET}"
        return f"{ansi_bg(bg_bar)}  {t0}  {t1}  {t2}  {t3}  {RESET}"

    else:
        # Default: Full vibrant 4-color cycling tabs
        t0 = f"{ansi_bg(p0['bg'])}{ansi_fg(p0['fg'])}{BOLD} {p0.get('active_sym', '⚡ ➜ ')}1 setup ✕ {RESET}"
        t1 = f"{ansi_bg(p1['bg'])}{ansi_fg(p1['fg'])} 2{p1.get('inactive_sym', ' 🔘')} mvsoares ✕ {RESET}"
        t2 = f"{ansi_bg(p2['bg'])}{ansi_fg(p2['fg'])} 3{p2.get('inactive_sym', ' 🔘')} careplus ✕ {RESET}"
        t3 = f"{ansi_bg(p3['bg'])}{ansi_fg(p3['fg'])} 4{p3.get('inactive_sym', ' 🔘')} cloud-run ✕ {RESET}"
        return f"{ansi_bg(bg_bar)} {t0} {t1} {t2} {t3} {RESET}"


def print_single_card(theme: dict, cur_id: int):
    """Print an uncluttered, high-contrast, single-column card with 4-tab preview."""
    tid = theme["id"]
    name = theme["name"]
    cat = theme["category"]
    desc = theme.get("description", "")
    pal = theme.get("palette", [])
    is_active = (tid == cur_id)

    # Header
    num_str = f"{BOLD}{CYAN}#{tid:02d}{RESET}"
    name_str = f"{BOLD}{name}{RESET}"
    cat_str = f"{DIM}[{cat}]{RESET}"
    active_badge = f"  {GREEN}{BOLD}★ TEMA ATUALMENTE ATIVO{RESET}" if is_active else ""

    # Swatches
    swatches = []
    for p in pal:
        swatches.append(f"{ansi_fg(p['bg'])}●{RESET} {DIM}{p['bg']}{RESET}")
    swatch_line = "  ".join(swatches)

    # 4-Tab Preview Line
    bar_preview = render_4_tab_bar(theme)

    border_color = GREEN if is_active else CYAN
    print(f"  {border_color}┌─{RESET} {num_str} {name_str} {cat_str}{active_badge}")
    print(f"  {border_color}│{RESET}  {swatch_line}")
    print(f"  {border_color}│{RESET}  {bar_preview}")
    print(f"  {border_color}│{RESET}  {DIM}{desc}{RESET}")
    print(f"  {border_color}└{'─' * 76}{RESET}")


def open_web_gallery():
    """Open interactive HTML catalog in browser."""
    target = None
    if TMP_HTML_PATH.exists():
        target = TMP_HTML_PATH
    elif HTML_PATH.exists():
        target = HTML_PATH
    if target:
        webbrowser.open(f"file://{target.resolve()}")
        print(f"Abrindo galeria visual no navegador: {target}")
    else:
        print("Arquivo de preview HTML não encontrado.")


def print_list(themes: list[dict]):
    """Print clean list of all 60 themes."""
    cur_id = detect_current_theme_id()
    print(f"\n{BOLD}{CYAN}=== CATÁLOGO COMPLETO DE TEMAS DE ABA WEZTERM (60 TEMAS) ==={RESET}\n")
    for t in themes:
        tid = t["id"]
        pal = t.get("palette", [])
        dots = "".join(f"{ansi_fg(p['bg'])}● {RESET}" for p in pal)
        active_str = f" {GREEN}{BOLD}← ATIVO{RESET}" if tid == cur_id else ""
        print(f"  {BOLD}#{tid:02d}{RESET}  {dots}  {BOLD}{t['name']:<28}{RESET}  {DIM}[{t['category']}]{RESET}{active_str}")
    print(f"\nUse: {BOLD}wezterm-tab-theme --set <NUMERO>{RESET} para aplicar diretamente.")


def interactive_picker(themes: list[dict], initial_filter: str = ""):
    """Clear, uncluttered interactive TUI picker."""
    filter_query = initial_filter
    page = 0
    page_size = 5
    status_msg = ""

    while True:
        # Re-detect active theme and tab title length
        cur_id = detect_current_theme_id()
        cur_theme = get_theme_by_id(cur_id)
        cur_name = cur_theme["name"] if cur_theme else f"#{cur_id}"
        cur_cat = cur_theme["category"] if cur_theme else ""
        cur_len = detect_current_tab_title_len()

        # Filter items
        filtered = themes
        if filter_query:
            q = filter_query.lower()
            filtered = [
                t for t in themes
                if q in t["name"].lower() or q in t["category"].lower() or q == str(t["id"])
            ]

        total_pages = max((len(filtered) + page_size - 1) // page_size, 1)
        if page >= total_pages:
            page = total_pages - 1
        if page < 0:
            page = 0

        # Clear screen
        print("\033[2J\033[H", end="")

        # Main Header
        active_info = f"#{cur_id:02d} {cur_name}"
        len_info = f"Tam. Abas: {cur_len} chars"
        print(f"{BOLD}{BLUE}╔════════════════════════════════════════════════════════════════════════════════════════╗{RESET}")
        print(f"{BOLD}{BLUE}║  🎨 WEZTERM TAB THEME PICKER (60 Temas com Pré-Visualização de 4 Abas Coloridas)       ║{RESET}")
        print(f"{BOLD}{BLUE}║  {GREEN}✔ Ativo Agora:{RESET} {BOLD}{active_info:<32}{RESET} {DIM}[{cur_cat:<20}]{RESET} {CYAN}{len_info:>21}{RESET}{BOLD}{BLUE} ║{RESET}")
        print(f"{BOLD}{BLUE}╚════════════════════════════════════════════════════════════════════════════════════════╝{RESET}")

        # Category Shortcuts Header
        print(f"\n  {BOLD}Atalhos de Categoria & Ações Rápidas:{RESET}")
        print(f"    {BOLD}[c1]{RESET} Google & Material (01-10)     {BOLD}[c2]{RESET} Powerline & Geometrias (11-20)")
        print(f"    {BOLD}[c3]{RESET} Paletas Populares Devs (21-30){BOLD}[c4]{RESET} Synth & Cyberpunk (31-40)")
        print(f"    {BOLD}[c5]{RESET} Natureza & Tons Terrosos (41-50){BOLD}[c6]{RESET} Minimalista, Badges & CRT (51-60)")
        print(f"    {BOLD}[b]{RESET}  Fazer Backup da Configuração   {BOLD}[u]{RESET}  Restaurar Backup Anterior")
        print(f"    {BOLD}[len <N>]{RESET} Ajustar Tam. Texto ({cur_len}c)  {BOLD}[w]{RESET}  Abrir Galeria Visual Web")
        print(f"    {BOLD}[all]{RESET} Exibir todos os 60 temas")

        if filter_query:
            print(f"\n  {YELLOW}Filtro Ativo:{RESET} '{filter_query}' ({len(filtered)} temas encontrados) | Digite {BOLD}[all]{RESET} para limpar")

        print(f"\n  {DIM}Exibindo {len(filtered)} temas (Página {page + 1}/{total_pages}):{RESET}\n")

        # Cards
        start = page * page_size
        end = start + page_size
        page_items = filtered[start:end]

        if not page_items:
            print(f"  {RED}Nenhum tema encontrado com o filtro '{filter_query}'.{RESET}")
        else:
            for t in page_items:
                print_single_card(t, cur_id)
                print()

        # Status Message
        if status_msg:
            print(f"  {status_msg}\n")
            status_msg = ""

        # Footer Navigation
        nav_parts = []
        if page < total_pages - 1:
            nav_parts.append(f"{BOLD}[n]{RESET} Próx")
        if page > 0:
            nav_parts.append(f"{BOLD}[p]{RESET} Ant")
        nav_str = " | ".join(nav_parts) + (" | " if nav_parts else "")

        print(f"  {DIM}{nav_str}{BOLD}[1-60]{RESET} Aplicar  |  {BOLD}[len <N>]{RESET} Tam. ({cur_len}c)  |  {BOLD}[b]{RESET} Backup  |  {BOLD}[u]{RESET} Restaurar  |  {BOLD}[r]{RESET} Random  |  {BOLD}[q]{RESET} Sair{RESET}")

        try:
            cmd = input(f"  {BOLD}{CYAN}❯ Digite o número do tema (1-60) ou comando:{RESET} ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\n  Até logo!")
            break

        if not cmd:
            continue

        cmd_lower = cmd.lower()

        # Navigation & special commands
        if cmd_lower in ("q", "quit", "exit"):
            print("  Até logo!")
            break
        elif cmd_lower in ("n", "next") and page < total_pages - 1:
            page += 1
        elif cmd_lower in ("p", "prev") and page > 0:
            page -= 1
        elif cmd_lower in ("all", "clear", "c"):
            filter_query = ""
            page = 0
            status_msg = f"{GREEN}Exibindo todos os 60 temas.{RESET}"
        elif cmd_lower in ("w", "web"):
            open_web_gallery()
            status_msg = f"{CYAN}Galeria aberta no navegador.{RESET}"
        elif cmd_lower in ("b", "backup", "bkp"):
            try:
                lbl = input(f"  {BOLD}{CYAN}❯ Etiqueta/nome para o backup (Enter para 'manual'):{RESET} ").strip()
            except (KeyboardInterrupt, EOFError):
                lbl = ""
            dest = backup_current_config(label=lbl or "manual")
            if dest:
                status_msg = f"{GREEN}{BOLD}✔ Backup criado:{RESET} {dest.name} {DIM}(use [u] para restaurar a qualquer momento){RESET}"
            else:
                status_msg = f"{YELLOW}Nenhuma configuração ativa encontrada para backup.{RESET}"
        elif cmd_lower in ("u", "undo", "restore", "restaurar"):
            status_msg = interactive_restore_menu()
        elif cmd_lower.startswith("len ") or cmd_lower.startswith("tam ") or cmd_lower.startswith("t "):
            parts = cmd.split(None, 1)
            if len(parts) > 1 and parts[1].strip().isdigit():
                new_len = int(parts[1].strip())
                if 4 <= new_len <= 50:
                    target_theme = cur_theme or THEMES[0]
                    _, bkp = apply_theme(target_theme, tab_title_len=new_len)
                    status_msg = f"{GREEN}{BOLD}✔ Tamanho do texto das abas ajustado para {new_len} caracteres fixos!{RESET}"
                else:
                    status_msg = f"{YELLOW}Escolha um tamanho entre 4 e 50 caracteres (ex: len 15).{RESET}"
            else:
                status_msg = f"{YELLOW}Uso: len <NÚMERO> (ex: len 15 para 15 caracteres){RESET}"
        elif cmd_lower in ("len", "tam", "largura"):
            try:
                ans = input(f"  {BOLD}{CYAN}❯ Digite o novo tamanho de texto para as abas (atual: {cur_len}, padrão: 15):{RESET} ").strip()
                if ans.isdigit():
                    new_len = int(ans)
                    if 4 <= new_len <= 50:
                        target_theme = cur_theme or THEMES[0]
                        _, bkp = apply_theme(target_theme, tab_title_len=new_len)
                        status_msg = f"{GREEN}{BOLD}✔ Tamanho do texto das abas ajustado para {new_len} caracteres fixos!{RESET}"
                    else:
                        status_msg = f"{YELLOW}Escolha um tamanho entre 4 e 50 caracteres.{RESET}"
                elif ans:
                    status_msg = f"{RED}Valor inválido. Digite apenas o número de caracteres (ex: 15).{RESET}"
            except (KeyboardInterrupt, EOFError):
                pass
        elif cmd_lower in ("r", "random"):
            chosen = random.choice(themes)
            _, bkp = apply_theme(chosen)
            bkp_str = f" {DIM}(Backup salvo: {bkp.name}){RESET}" if bkp else ""
            status_msg = f"{GREEN}{BOLD}✔ Tema #{chosen['id']:02d} '{chosen['name']}' aplicado instantaneamente!{RESET}{bkp_str}"
        elif cmd_lower in ("c1", "cat1", "cat 1"):
            filter_query = "Google & Material"
            page = 0
        elif cmd_lower in ("c2", "cat2", "cat 2"):
            filter_query = "Powerline & Geometrias"
            page = 0
        elif cmd_lower in ("c3", "cat3", "cat 3"):
            filter_query = "Paletas Populares Devs"
            page = 0
        elif cmd_lower in ("c4", "cat4", "cat 4"):
            filter_query = "Synth & Cyberpunk"
            page = 0
        elif cmd_lower in ("c5", "cat5", "cat 5"):
            filter_query = "Natureza & Tons Terrosos"
            page = 0
        elif cmd_lower in ("c6", "cat6", "cat 6"):
            filter_query = "Minimalista, Badges & CRT"
            page = 0
        elif cmd_lower.startswith("f ") or cmd_lower.startswith("/"):
            term = cmd[2:].strip() if cmd_lower.startswith("f ") else cmd[1:].strip()
            filter_query = term
            page = 0
        else:
            # Check if user entered a theme number (e.g. 1-60) or name
            target = find_theme(cmd)
            if target:
                _, bkp = apply_theme(target)
                bkp_str = f" {DIM}(Backup salvo: {bkp.name}){RESET}" if bkp else ""
                status_msg = f"{GREEN}{BOLD}✔ Tema #{target['id']:02d} '{target['name']}' aplicado ao WezTerm!{RESET}{bkp_str}"
            else:
                status_msg = f"{RED}Opção ou tema '{cmd}' não encontrado. Digite um número de 1 a 60, [b] para backup, [u] para restaurar ou [len 15].{RESET}"


def main():
    parser = argparse.ArgumentParser(
        description="Seletor interativo de temas de aba para o WezTerm (60 temas com preview ao vivo de 4 abas, backup e restauração)."
    )
    parser.add_argument("-s", "--set", metavar="ID_OU_NOME", help="Aplica diretamente um tema por número (1-60) ou nome")
    parser.add_argument("-t", "--tab-len", type=int, default=None, metavar="N", help="Define o tamanho fixo (em caracteres) para os títulos das abas (padrão: 15)")
    parser.add_argument("-l", "--list", action="store_true", help="Lista todos os 60 temas com amostras de cor")
    parser.add_argument("-r", "--random", action="store_true", help="Aplica um tema aleatório")
    parser.add_argument("-c", "--current", action="store_true", help="Mostra o tema de aba atualmente ativo")
    parser.add_argument("-w", "--web", action="store_true", help="Abre a galeria visual interativa no navegador")
    parser.add_argument("-f", "--filter", default="", help="Inicia o picker interativo com um filtro pré-definido")
    parser.add_argument(
        "-b", "--backup", nargs="?", const="manual", default=None, metavar="NOME",
        help="Cria um snapshot de backup da configuração atual de abas (com etiqueta opcional)"
    )
    parser.add_argument(
        "-u", "--restore", nargs="?", const="1", default=None, metavar="INDICE_OU_NOME",
        help="Restaura um backup anterior (padrão: 1 = backup mais recente)"
    )
    parser.add_argument(
        "--backups", "--list-backups", action="store_true",
        help="Lista todos os backups salvos com número, data e tema"
    )
    args = parser.parse_args()

    if args.backups:
        backups = get_available_backups()
        print_backups_list(backups)
        sys.exit(0)

    if args.backup is not None:
        dest = backup_current_config(label=args.backup or "manual")
        if dest:
            print(f"{GREEN}{BOLD}✔ Backup criado com sucesso:{RESET} {dest}")
            print(f"Para restaurar a qualquer momento use: {BOLD}wezterm-tab-theme --restore{RESET}")
        else:
            print(f"{RED}Erro: Não foi possível criar backup ({THEME_FILE} não existe).{RESET}")
        sys.exit(0)

    if args.restore is not None:
        success, msg = restore_backup(args.restore)
        if success:
            print(f"{GREEN}{BOLD}✔ {msg}{RESET}")
            print("O WezTerm recarregou a configuração restaurada automaticamente!")
        else:
            print(f"{RED}✖ {msg}{RESET}")
            print(f"Dica: Execute '{BOLD}wezterm-tab-theme --backups{RESET}' para ver a lista de backups disponíveis.")
            sys.exit(1)
        sys.exit(0)

    if args.web:
        open_web_gallery()
        sys.exit(0)

    if args.list:
        print_list(THEMES)
        sys.exit(0)

    if args.current:
        cur_id = detect_current_theme_id()
        cur_len = detect_current_tab_title_len()
        t = get_theme_by_id(cur_id)
        if t:
            print(f"Tema ativo: #{t['id']:02d} {t['name']} [{t['category']}] (Tamanho de texto: {cur_len} chars)")
        else:
            print(f"Tema ativo ID: #{cur_id} (Tamanho de texto: {cur_len} chars)")
        sys.exit(0)

    # Handle --tab-len when passed without --set or --random
    if args.tab_len is not None and not args.set and not args.random:
        if args.tab_len < 4 or args.tab_len > 50:
            print(f"{RED}Erro: O tamanho da aba deve ser entre 4 e 50 caracteres.{RESET}")
            sys.exit(1)
        cur_id = detect_current_theme_id()
        cur_theme = get_theme_by_id(cur_id) or THEMES[0]
        _, bkp = apply_theme(cur_theme, tab_title_len=args.tab_len)
        print(f"{GREEN}{BOLD}✔ Tamanho fixo do texto das abas atualizado para {args.tab_len} caracteres!{RESET}")
        if bkp:
            print(f"{DIM}Backup da configuração anterior salvo em: {bkp.name}{RESET}")
        print("O WezTerm recarregou a configuração automaticamente!")
        sys.exit(0)

    if args.random:
        chosen = random.choice(THEMES)
        _, bkp = apply_theme(chosen, tab_title_len=args.tab_len)
        print(f"{GREEN}{BOLD}Tema aleatório aplicado: #{chosen['id']:02d} {chosen['name']} [{chosen['category']}]{RESET}")
        if bkp:
            print(f"{DIM}Backup da configuração anterior salvo em: {bkp.name}{RESET}")
        print("O WezTerm recarregou a configuração automaticamente!")
        sys.exit(0)

    if args.set:
        target = find_theme(args.set)
        if not target:
            print(f"{RED}Erro: tema '{args.set}' não encontrado.{RESET}")
            print("Use --list para ver todos os temas disponíveis.")
            sys.exit(1)
        _, bkp = apply_theme(target, tab_title_len=args.tab_len)
        print(f"{GREEN}{BOLD}Tema #{target['id']:02d} '{target['name']}' aplicado com sucesso!{RESET}")
        print(f"Arquivo gerado: {THEME_FILE}")
        if bkp:
            print(f"{DIM}Backup da configuração anterior salvo em: {bkp.name}{RESET}")
        print("O WezTerm recarregou a configuração automaticamente!")
        sys.exit(0)

    interactive_picker(THEMES, initial_filter=args.filter)


if __name__ == "__main__":
    main()
