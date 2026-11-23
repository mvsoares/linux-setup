-- WezTerm loader — installed as ~/.config/wezterm/wezterm.lua. Do not edit.
--
-- Every preference lives in JSON next to this file:
--   defaults.json  repo defaults (lib/wezterm-defaults.json), replaced on install
--   settings.json  this machine's overrides, never touched by the installer
--   user.lua       optional code run last: return function(config, wezterm, settings)
--
-- settings.json is deep-merged over defaults.json: objects merge key by key,
-- arrays (keys, mouse bindings, hyperlink rules) replace the default list.
-- A broken settings.json is logged and ignored, so WezTerm keeps the defaults.

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()
local dir = wezterm.config_dir

-- ─── Settings loading ────────────────────────────────────────────────────────
local function exists(path)
  local f = io.open(path, 'r')
  if f then
    f:close()
  end
  return f ~= nil
end

local function read_json(path)
  local f = io.open(path, 'r')
  if not f then
    return nil
  end
  local text = f:read('*a')
  f:close()
  local decode = (wezterm.serde and wezterm.serde.json_decode) or wezterm.json_parse
  local ok, data = pcall(decode, text)
  if not ok or type(data) ~= 'table' then
    wezterm.log_error('wezterm settings: cannot parse ' .. path .. ': ' .. tostring(data))
    return nil
  end
  return data
end

local function is_array(t)
  return type(t) == 'table' and #t > 0
end

local function merge(base, over)
  if type(base) ~= 'table' or type(over) ~= 'table' or is_array(base) or is_array(over) then
    return over
  end
  local out = {}
  for k, v in pairs(base) do
    out[k] = v
  end
  for k, v in pairs(over) do
    out[k] = merge(base[k], v)
  end
  return out
end

for _, name in ipairs { 'defaults.json', 'settings.json', 'user.lua' } do
  if exists(dir .. '/' .. name) then
    wezterm.add_to_config_reload_watch_list(dir .. '/' .. name)
  end
end

local settings = merge(read_json(dir .. '/defaults.json') or {}, read_json(dir .. '/settings.json') or {})

local function section(name)
  return settings[name] or {}
end

-- Copy a value only when the JSON sets it, so missing keys keep WezTerm's own default.
local function set(key, value)
  if value ~= nil then
    config[key] = value
  end
end

local function is_appearance_dark()
  local appearance = (wezterm.gui and wezterm.gui.get_appearance and wezterm.gui.get_appearance()) or 'Dark'
  return appearance:find('Dark') ~= nil
end

local function font(family, weight, italic)
  local attrs = {}
  if weight then
    attrs.weight = weight
  end
  if italic then
    attrs.italic = true
  end
  return wezterm.font(family, attrs)
end

-- Custom high-level workflow actions referenceable by string name in JSON.
local custom_actions = {
  RenameTab = function()
    return act.PromptInputLine {
      description = 'Rename tab (leave empty to reset automatic title):',
      action = wezterm.action_callback(function(window, _pane, line)
        if line ~= nil then
          window:active_tab():set_title(line)
        end
      end),
    }
  end,
  EditLastOutput = function()
    return wezterm.action_callback(function(window, pane)
      local text = nil
      local ok_z, zones = pcall(function()
        return pane:get_semantic_zones('Output')
      end)
      if ok_z and type(zones) == 'table' and #zones > 0 then
        for idx = #zones, 1, -1 do
          local ok_t, ztxt = pcall(function()
            return pane:get_text_from_semantic_zone(zones[idx])
          end)
          if ok_t and ztxt and ztxt:match('%S') then
            text = ztxt
            break
          end
        end
      end
      if not text or not text:match('%S') then
        local ok_l, lines = pcall(function()
          return pane:get_lines_as_text(config.scrollback_lines or 5000)
        end)
        if ok_l then
          text = lines
        end
      end
      if not text or text == '' then
        return
      end
      local path = os.tmpname() .. '.log'
      local fh = io.open(path, 'w')
      if not fh then
        return
      end
      fh:write(text)
      fh:close()
      local h_cfg = section('hyperlinks')
      local editor = (h_cfg.editor and h_cfg.editor ~= '' and h_cfg.editor)
        or os.getenv('EDITOR')
        or os.getenv('VISUAL')
        or 'nvim'
      window:perform_action(
        act.SpawnCommandInNewTab {
          args = { 'sh', '-c', editor .. ' "$1"; rm -f "$1"', 'sh', path },
        },
        pane
      )
    end)
  end,
  OpenUrlQuickSelect = function()
    return act.QuickSelectArgs {
      label = 'open url',
      patterns = {
        'https?://\\S+',
      },
      action = wezterm.action_callback(function(window, pane)
        local url = window:get_selection_text_for_pane(pane)
        if url and url ~= '' then
          url = url:gsub('[.,;:%)%]>\"\']+$', '')
          wezterm.open_with(url)
        end
      end),
    }
  end,
  ProjectSessionizer = function()
    return wezterm.action_callback(function(window, pane)
      local choices = {}
      local seen = {}
      local open_ws = {}
      local ok_mw, ws_list = pcall(function()
        return wezterm.mux.get_workspace_names()
      end)
      if ok_mw and type(ws_list) == 'table' then
        for _, wname in ipairs(ws_list) do
          open_ws[wname] = true
          seen['ws:' .. wname] = true
          table.insert(choices, {
            id = 'ws:' .. wname,
            label = '★ [active workspace] ' .. wname,
          })
        end
      end

      local function add_dir(raw_path)
        if not raw_path or raw_path == '' then
          return
        end
        local clean = raw_path:gsub('/+$', '')
        if clean == '' or seen[clean] then
          return
        end
        seen[clean] = true
        local name = clean:match('([^/\\]+)$') or clean
        local tag = open_ws[name] and '● ' or '󰉋 '
        table.insert(choices, {
          id = 'dir:' .. clean,
          label = tag .. name .. '  (' .. clean .. ')',
        })
      end

      local home = wezterm.home_dir or os.getenv('HOME') or ''
      for _, sub in ipairs { '/projetos', '/projects', '/src', '/work' } do
        local root = home .. sub
        local ok_rd, entries = pcall(wezterm.read_dir, root)
        if ok_rd and type(entries) == 'table' then
          table.sort(entries)
          for _, entry in ipairs(entries) do
            local base = entry:match('([^/\\]+)$') or ''
            if not base:match('^%.') then
              add_dir(entry)
            end
          end
        end
      end

      local ok_z, z_ok, z_out = pcall(wezterm.run_child_process, { 'zoxide', 'query', '-l' })
      if ok_z and z_ok and z_out then
        for line in z_out:gmatch('[^\r\n]+') do
          add_dir(line)
        end
      end

      if #choices == 0 then
        add_dir(home)
      end

      window:perform_action(
        act.InputSelector {
          title = '󱂬 Switch / Spawn Project Workspace',
          choices = choices,
          fuzzy = true,
          fuzzy_description = 'Project or workspace: ',
          action = wezterm.action_callback(function(win, p, id, _label)
            if not id then
              return
            end
            local ws_only = id:match('^ws:(.+)$')
            if ws_only then
              win:perform_action(act.SwitchToWorkspace { name = ws_only }, p)
              return
            end
            local dir_target = id:match('^dir:(.+)$')
            if dir_target then
              local ws_name = dir_target:match('([^/\\]+)$') or 'project'
              win:perform_action(
                act.SwitchToWorkspace {
                  name = ws_name,
                  spawn = { cwd = dir_target },
                },
                p
              )
            end
          end),
        },
        pane
      )
    end)
  end,
  BroadcastToPanes = function()
    local skip_apps = {
      nvim = true, vim = true, vi = true, hx = true, helix = true, nano = true, emacs = true,
      less = true, more = true, man = true, top = true, htop = true, btop = true,
      claude = true, gemini = true, antigravity = true, agy = true, codex = true,
      aider = true, opencode = true, goose = true, cline = true, amp = true,
    }
    return act.PromptInputLine {
      description = '📡 Broadcast command to shell panes in active tab (skips editors/AI agents/prod SSH):',
      action = wezterm.action_callback(function(window, _pane, line)
        if not line or line == '' then
          return
        end
        local tab = window:active_tab()
        if not tab then
          return
        end
        local sent, skipped = 0, 0
        for _, p in ipairs(tab:panes()) do
          local ok_uv, uv = pcall(function() return p:get_user_vars() end)
          uv = (ok_uv and type(uv) == 'table') and uv or {}
          local cmdline = uv.WEZTERM_PROG or uv.WEZTERM_CMD or uv.cmd or ''
          local ufirst = (cmdline:match('^%s*(%S+)') or ''):match('([^/\\]+)$') or ''
          ufirst = ufirst:lower():gsub('%.exe$', '')
          local ok_fg, fg = pcall(function() return p:get_foreground_process_name() end)
          local fg_bin = ((ok_fg and fg) and (fg:match('([^/\\]+)$') or fg) or ''):lower():gsub('%.exe$', '')
          local low_cmd = cmdline:lower()
          local is_prod_ssh = (ufirst == 'ssh' or fg_bin == 'ssh')
            and (low_cmd:find('prod') or low_cmd:find('prd') or low_cmd:find('root@'))
          if skip_apps[ufirst] or skip_apps[fg_bin] or is_prod_ssh then
            skipped = skipped + 1
          else
            p:send_text(line .. '\n')
            sent = sent + 1
          end
        end
        if skipped > 0 then
          pcall(function()
            window:toast_notification(
              'Broadcast Guard',
              string.format('Sent to %d shell pane(s); skipped %d interactive/agent/prod pane(s)', sent, skipped),
              nil,
              3000
            )
          end)
        end
      end),
    }
  end,
  ToggleZenMode = function()
    return wezterm.action_callback(function(window, _pane)
      wezterm.GLOBAL._wt_zen_windows = wezterm.GLOBAL._wt_zen_windows or {}
      local ok_wid, raw_wid = pcall(function() return window:window_id() end)
      local wid = tostring((ok_wid and raw_wid) or '0')
      local overrides = window:get_config_overrides() or {}
      if wezterm.GLOBAL._wt_zen_windows[wid] then
        wezterm.GLOBAL._wt_zen_windows[wid] = nil
        overrides.font_size = nil
        overrides.enable_tab_bar = nil
        overrides.window_background_opacity = nil
        overrides.window_padding = nil
      else
        wezterm.GLOBAL._wt_zen_windows[wid] = true
        overrides.font_size = (config.font_size or 14) + 4
        overrides.enable_tab_bar = false
        overrides.window_background_opacity = 1.0
        overrides.window_padding = { left = 48, right = 48, top = 24, bottom = 24 }
      end
      window:set_config_overrides(overrides)
    end)
  end,
  SaveSession = function()
    return wezterm.action_callback(function(window, _pane)
      local ok_m, all_wins = pcall(function()
        return wezterm.mux.all_windows()
      end)
      if not ok_m or type(all_wins) ~= 'table' then
        return
      end
      local snapshot = {
        saved_at = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        active_workspace = window:active_workspace(),
        workspaces = {},
      }
      local total_tabs = 0
      for _, mw in ipairs(all_wins) do
        local w_entry = {
          name = mw:get_workspace() or 'default',
          tabs = {},
        }
        for _, mtab in ipairs(mw:tabs()) do
          local ap = mtab:active_pane()
          local cwd_str = ''
          if ap then
            local ok_c, u = pcall(function()
              return ap:get_current_working_dir()
            end)
            if ok_c and u then
              cwd_str = type(u) == 'string' and u:gsub('^file://[^/]*', '') or (u.file_path or '')
            end
          end
          table.insert(w_entry.tabs, {
            title = mtab:get_title() or '',
            cwd = cwd_str,
          })
          total_tabs = total_tabs + 1
        end
        table.insert(snapshot.workspaces, w_entry)
      end
      local encode = (wezterm.serde and wezterm.serde.json_encode_pretty)
        or (wezterm.serde and wezterm.serde.json_encode)
        or wezterm.json_encode
      local snap_path = dir .. '/wezterm_session.json'
      local fh = io.open(snap_path, 'w')
      if fh then
        fh:write(encode(snapshot) .. '\n')
        fh:close()
        pcall(function()
          window:toast_notification(
            'WezTerm Session Saved',
            string.format('Saved %d tab(s) across %d workspace(s) to wezterm_session.json', total_tabs, #snapshot.workspaces),
            nil,
            3000
          )
        end)
      end
    end)
  end,
  RestoreSession = function()
    return wezterm.action_callback(function(window, pane)
      local snap = read_json(dir .. '/wezterm_session.json') or read_json(dir .. '/session-snapshot.json')
      local ws_entries = snap and (snap.workspaces or snap.windows) or nil
      if not ws_entries or type(ws_entries) ~= 'table' or #ws_entries == 0 then
        pcall(function()
          window:toast_notification('WezTerm Session', 'No saved wezterm_session.json found.', nil, 3000)
        end)
        return
      end
      local existing_ws = {}
      local ok_w, ws_names = pcall(function()
        return wezterm.mux.get_workspace_names()
      end)
      if ok_w and type(ws_names) == 'table' then
        for _, n in ipairs(ws_names) do
          existing_ws[n] = true
        end
      end
      local restored_tabs = 0
      for _, w_entry in ipairs(ws_entries) do
        local ws_name = w_entry.name or w_entry.workspace or 'default'
        local tabs = w_entry.tabs or {}
        if #tabs > 0 and not existing_ws[ws_name] then
          existing_ws[ws_name] = true
          local first_cwd = (tabs[1].cwd and tabs[1].cwd ~= '') and tabs[1].cwd or nil
          local ok_sp, mtab, _mpane, mwin = pcall(wezterm.mux.spawn_window, {
            workspace = ws_name,
            cwd = first_cwd,
          })
          if ok_sp and mwin then
            if mtab and tabs[1].title and tabs[1].title ~= '' then
              pcall(function()
                mtab:set_title(tabs[1].title)
              end)
            end
            restored_tabs = restored_tabs + 1
            for idx = 2, #tabs do
              local tc = (tabs[idx].cwd and tabs[idx].cwd ~= '') and tabs[idx].cwd or nil
              local ok_t, nt = pcall(function()
                return mwin:spawn_tab { cwd = tc }
              end)
              if ok_t and nt and tabs[idx].title and tabs[idx].title ~= '' then
                pcall(function()
                  nt:set_title(tabs[idx].title)
                end)
              end
              restored_tabs = restored_tabs + 1
            end
          end
        end
      end
      if snap.active_workspace and snap.active_workspace ~= '' then
        window:perform_action(act.SwitchToWorkspace { name = snap.active_workspace }, pane)
      end
      pcall(function()
        window:toast_notification(
          'WezTerm Session Restored',
          string.format('Restored %d tab(s) from wezterm_session.json', restored_tabs),
          nil,
          3000
        )
      end)
    end)
  end,
}

-- JSON action → KeyAssignment: "Name" for unit/custom actions, { "Name": args } otherwise.
local function action(spec)
  if type(spec) == 'string' then
    if custom_actions[spec] then
      return custom_actions[spec]()
    end
    return act[spec]
  end
  local name, args = next(spec)
  if name == 'Multiple' then
    local list = {}
    for i, a in ipairs(args) do
      list[i] = action(a)
    end
    return act.Multiple(list)
  end
  if name == 'SmartActivatePaneDirection' then
    return wezterm.action_callback(function(window, pane)
      local ok_uv, uv = pcall(function()
        return pane:get_user_vars()
      end)
      local is_nvim = ok_uv and type(uv) == 'table' and (uv.IS_NVIM == 'true' or uv.IS_NVIM == true)
      if is_nvim then
        window:perform_action(act.SendKey { key = args.key, mods = args.mods }, pane)
      else
        window:perform_action(act.ActivatePaneDirection(args.direction), pane)
      end
    end)
  end
  return act[name](args)
end

local function bindings(list)
  local out = {}
  for i, b in ipairs(list or {}) do
    out[i] = { key = b.key, mods = b.mods, event = b.event, action = action(b.action) }
  end
  return out
end

-- ─── Font ────────────────────────────────────────────────────────────────────
local f = section('font')
if f.family then
  if f.fallback then
    local primary = { family = f.family }
    if f.weight then
      primary.weight = f.weight
    end
    config.font = wezterm.font_with_fallback { primary, 'Symbols Nerd Font Mono', 'Noto Color Emoji' }
  else
    config.font = font(f.family, f.weight)
  end
  -- Half-intensity rules keep dim text (status lines) off Victor Mono's
  -- Thin/Light cuts, which render almost invisible.
  if f.rules then
    config.font_rules = {}
    for i, r in ipairs(f.rules) do
      config.font_rules[i] = {
        intensity = r.intensity,
        italic = r.italic,
        font = font(r.family or f.family, r.weight, r.italic),
      }
    end
  end
end
set('font_size', f.size)
set('line_height', f.line_height)
if f.ligatures == false then
  config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }
end

-- ─── Display backend & per-screen scaling ────────────────────────────────────
-- X11 (XWayland) gets GNOME's real title bar, so maximize and edge resize
-- work, but it needs a healthy XWayland: when X11 windows get stuck minimized,
-- set display.use_x11 = false until the next GNOME login. X11 clients see one
-- DPI (288) on every monitor, hence dpi_by_screen for the laptop panel.
local d = section('display')
if d.enable_wayland ~= nil then
  config.enable_wayland = d.enable_wayland
else
  config.enable_wayland = not d.use_x11
end
set('dpi_by_screen', d.dpi_by_screen)

-- ─── Colors & terminal emulation ─────────────────────────────────────────────
local c = section('colors')
local dark_ui = is_appearance_dark()
local using_light_scheme = (not dark_ui) and c.scheme_light and c.scheme_light ~= ''
if using_light_scheme then
  config.color_scheme = c.scheme_light
else
  set('color_scheme', c.scheme)
end
set('bold_brightens_ansi_colors', c.bold_brightens_ansi_colors)
if c.oled_black and not using_light_scheme then
  config.colors = config.colors or {}
  config.colors.background = '#000000'
end
if c.cursor_color and type(c.cursor_color) == 'string' and c.cursor_color:match('^#%x%x%x%x%x%x$') then
  config.colors = config.colors or {}
  config.colors.cursor_bg = c.cursor_color
  config.colors.cursor_border = c.cursor_color
  local cr = tonumber(c.cursor_color:sub(2, 3), 16) or 0
  local cg = tonumber(c.cursor_color:sub(4, 5), 16) or 0
  local cb = tonumber(c.cursor_color:sub(6, 7), 16) or 0
  local lum = (0.2126 * cr + 0.7152 * cg + 0.0722 * cb) / 255
  config.colors.cursor_fg = lum > 0.5 and '#000000' or '#ffffff'
end

local t = section('terminal')
set('term', t.term)
set('unicode_version', t.unicode_version)
set('allow_square_glyphs_to_overflow_width', t.allow_square_glyphs_to_overflow_width)
set('exit_behavior', t.exit_behavior)

-- ─── Window & geometry ───────────────────────────────────────────────────────
-- GNOME draws no frame for Wayland clients, so without X11 the window buttons
-- go into the tab bar (resize via Alt+F8). Resize increments fight mutter's
-- maximize/tile sizes.
local w = section('window')
set('window_background_opacity', w.opacity)
if w.blur and tonumber(w.blur) and tonumber(w.blur) > 0 then
  config.macos_window_background_blur = tonumber(w.blur)
  config.kde_window_background_blur = true
end
if w.win32_backdrop and w.win32_backdrop ~= '' then
  config.win32_system_backdrop = w.win32_backdrop
end
config.window_decorations = w.decorations or (d.use_x11 and 'TITLE | RESIZE' or 'INTEGRATED_BUTTONS | RESIZE')
set('window_padding', w.padding)
set('initial_cols', w.initial_cols)
set('initial_rows', w.initial_rows)
set('adjust_window_size_when_changing_font_size', w.adjust_window_size_when_changing_font_size)
set('use_resize_increments', w.use_resize_increments)
set('inactive_pane_hsb', w.inactive_pane_hsb)

-- ─── Tab bar ─────────────────────────────────────────────────────────────────
local tb = section('tabs')
set('hide_tab_bar_if_only_one_tab', tb.hide_if_only_one_tab)
set('use_fancy_tab_bar', tb.fancy)
set('tab_bar_at_bottom', tb.at_bottom)
set('tab_max_width', tb.max_width)
if tb.frame_font then
  config.window_frame = {
    font = font(tb.frame_font.family, tb.frame_font.weight),
    font_size = tb.frame_font.size,
  }
end

-- Tab theme module written by wezterm-theme; it returns
-- { apply = function(config, wezterm) } and installs its own format-tab-title.
local theme_applied = false
local loaded_theme = nil
if tb.theme_file then
  local path = dir .. '/' .. tb.theme_file
  if exists(path) then
    wezterm.add_to_config_reload_watch_list(path)
    local ok, theme = pcall(dofile, path)
    if ok and type(theme) == 'table' and type(theme.apply) == 'function' then
      local applied, err = pcall(theme.apply, config, wezterm)
      theme_applied = applied
      if applied then
        loaded_theme = theme
      else
        wezterm.log_error('wezterm settings: tab theme failed: ' .. tostring(err))
      end
    else
      wezterm.log_error('wezterm settings: cannot load tab theme ' .. path .. ': ' .. tostring(theme))
    end
  end
end

-- Optional Oklab background gradient & 1px accent frame border (applied after theme
-- so active tab accent and color scheme are already resolved).
if w.background_gradient then
  local schemes = (wezterm.color and wezterm.color.get_builtin_schemes and wezterm.color.get_builtin_schemes()) or {}
  local active_scheme = schemes[config.color_scheme or ''] or {}
  local base_hex = active_scheme.background
    or (config.colors and config.colors.tab_bar and config.colors.tab_bar.background)
    or (dark_ui and '#15161c' or '#f8fafc')
  local ok_col, base_col = pcall(wezterm.color.parse, base_hex)
  if ok_col and base_col then
    local edge_col = dark_ui and base_col:lighten(0.06) or base_col:darken(0.06)
    config.window_background_gradient = {
      colors = { tostring(edge_col), tostring(base_col) },
      blend = 'Oklab',
      orientation = { Radial = { cx = 0.8, cy = 0.85, radius = 1.15 } },
    }
  end
end

if w.accent_border then
  local border_col = type(w.accent_border) == 'string' and w.accent_border
    or (config.colors and config.colors.tab_bar and config.colors.tab_bar.active_tab and config.colors.tab_bar.active_tab.bg_color)
    or '#4285F4'
  config.window_frame = config.window_frame or {}
  config.window_frame.border_left_width = '1px'
  config.window_frame.border_right_width = '1px'
  config.window_frame.border_top_height = '1px'
  config.window_frame.border_bottom_height = '1px'
  config.window_frame.border_left_color = border_col
  config.window_frame.border_right_color = border_col
  config.window_frame.border_top_color = border_col
  config.window_frame.border_bottom_color = border_col
  config.colors = config.colors or {}
  config.colors.split = config.colors.split or border_col
end

-- Without a theme: cycle the fallback palette, "process|dir" titles.
local fb = tb.fallback
if not theme_applied and fb and fb.palette then
  local title_len = tb.tab_title_len or fb.title_len or 15
  local sup_digits = { '', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹' }
  local idle_shells = {
    bash = true, zsh = true, fish = true, sh = true, dash = true, ksh = true,
    pwsh = true, powershell = true, cmd = true, nu = true, tmux = true,
    wezterm = true, ['wezterm-gui'] = true,
  }

  local function format_fixed(text)
    if wezterm.column_width(text) > title_len then
      return wezterm.truncate_right(text, title_len - 1) .. '…'
    end
    return wezterm.pad_right(text, title_len)
  end

  wezterm.on('format-tab-title', function(tab, _tabs, panes, _cfg, hover)
    local pane = tab.active_pane
    local index = tab.tab_index + 1
    local colors = fb.palette[(tab.tab_index % #fb.palette) + 1]

    local raw = ''
    if tab.tab_title and tab.tab_title ~= '' then
      raw = tab.tab_title
    else
      local dir_name = '~'
      if pane.current_working_dir then
        local cwd = type(pane.current_working_dir) == 'string'
          and pane.current_working_dir
          or (pane.current_working_dir.file_path or '')
        cwd = cwd:gsub('^file://[^/]*', ''):gsub('\\\\', '/'):gsub('/+$', '')
        if cwd ~= '' then
          dir_name = cwd:match('([^/]+)$') or cwd
        end
      end

      local uv = pane.user_vars or {}
      local prog = uv.cmd or uv.WEZTERM_CMD or ''
      if prog == '' and uv.WEZTERM_PROG and uv.WEZTERM_PROG ~= '' then
        prog = uv.WEZTERM_PROG:match('^%S+') or ''
      end
      if prog == '' then
        prog = pane.foreground_process_name or ''
      end
      local process = prog:match('([^/\\]+)$') or prog
      process = process:gsub('%.[eE][xX][eE]$', '')
      if idle_shells[process:lower()] then
        process = ''
      end
      raw = process ~= '' and (process .. '|' .. dir_name) or dir_name
    end

    local label = format_fixed(raw)
    local extra = ''
    if pane.is_zoomed then
      extra = extra .. '🔍'
    end
    local n_panes = panes and #panes or 1
    if n_panes > 1 then
      extra = extra .. (sup_digits[math.min(n_panes, #sup_digits)] or '⁺')
    end
    if extra ~= '' then
      extra = extra .. ' '
    end

    local bg = colors.bg
    if hover and not tab.is_active then
      local ok_c, parsed = pcall(wezterm.color.parse, bg)
      if ok_c and parsed then
        bg = tostring(parsed:lighten(0.12))
      end
    end

    if tab.is_active then
      return wezterm.format {
        { Background = { Color = bg } },
        { Foreground = { Color = '#ffffff' } },
        { Attribute = { Intensity = 'Bold' } },
        { Attribute = { Underline = 'Single' } },
        { Text = colors.active_symbol .. index .. ' ' .. extra .. label .. ' ' },
      }
    end
    return wezterm.format {
      { Background = { Color = bg } },
      { Foreground = { Color = '#ffffff' } },
      { Text = index .. ' ' .. colors.inactive_symbol .. ' ' .. extra .. label .. ' ' },
    }
  end)
end

-- ─── Status bar ──────────────────────────────────────────────────────────────
-- WezTerm's default tick is 1000ms; the clock only has minute resolution, so a
-- slower tick costs nothing visible and cuts the battery/git work per window.
-- Leader/key-table transitions trigger update-status immediately with zero lag.
local st = section('status')
if st.enabled then
  set('status_update_interval', st.update_interval or st.interval_ms)

  wezterm.GLOBAL.git_branch_cache = wezterm.GLOBAL.git_branch_cache or {}

  local function git_branch(cwd)
    if not cwd or cwd == '' then
      return ''
    end
    local now = os.time()
    local cache = wezterm.GLOBAL.git_branch_cache
    local entry = cache[cwd]
    if entry and (now - entry.ts) < (st.git_recheck_s or 10) then
      return entry.branch
    end
    local branch = ''
    local scan_dir = cwd:gsub('\\', '/')
    if scan_dir ~= '/' then
      scan_dir = scan_dir:gsub('/+$', '')
    end
    local needs_git_cli = true
    for _ = 1, 20 do
      if scan_dir == '' then
        needs_git_cli = false
        break
      end
      local base = scan_dir == '/' and '' or scan_dir
      local hf = io.open(base .. '/.git/HEAD', 'r')
      if hf then
        local head = hf:read('*l') or ''
        hf:close()
        local ref = head:match('^ref:%s*refs/heads/(.+)$')
        ref = ref and ref:gsub('%s+$', '') or ''
        if ref ~= '' and ref ~= '.invalid' then
          branch = ref
          needs_git_cli = false
        end
        break
      end
      local gf = io.open(base .. '/.git', 'r')
      if gf then
        local line = gf:read('*l') or ''
        gf:close()
        if line:match('^gitdir:') then
          break
        end
      end
      if scan_dir == '/' then
        needs_git_cli = false
        break
      end
      local parent = scan_dir:match('^(.+)/[^/]+$')
      scan_dir = parent or '/'
    end
    if needs_git_cli then
      local ok, success, stdout = pcall(wezterm.run_child_process, {
        'git',
        '-C',
        cwd,
        'rev-parse',
        '--abbrev-ref',
        'HEAD',
      })
      if ok and success and stdout then
        branch = stdout:gsub('%s+$', '')
      end
    end
    local count = 0
    for _ in pairs(cache) do
      count = count + 1
    end
    if count > 64 then
      cache = {}
      wezterm.GLOBAL.git_branch_cache = cache
    end
    cache[cwd] = { branch = branch, ts = now }
    return branch
  end

  local mode_badges = {
    resize_pane = { text = ' 󰙕 RESIZE ', bg = '#f9ab00', fg = '#202124' },
    copy_mode   = { text = ' 󰆏 COPY ',   bg = '#8ab4f8', fg = '#202124' },
    search_mode = { text = ' 󰍉 SEARCH ', bg = '#c58af9', fg = '#202124' },
  }

  local function detect_ssh_target(pane)
    local ok_uv, uv = pcall(function()
      return pane:get_user_vars()
    end)
    uv = (ok_uv and type(uv) == 'table') and uv or {}
    local cmdline = uv.WEZTERM_PROG or uv.WEZTERM_CMD or uv.cmd or ''
    if cmdline ~= '' then
      local first = cmdline:match('^%s*(%S+)') or ''
      local bin = (first:match('([^/\\]+)$') or first):lower():gsub('%.exe$', '')
      if bin == 'ssh' or bin == 'mosh' or bin == 'mosh-client' then
        local skip_next = false
        for tok in cmdline:gmatch('%S+') do
          if tok ~= first then
            if skip_next then
              skip_next = false
            elseif tok:match('^-[pPiJlFobcSDEeLKRW]$') then
              skip_next = true
            elseif not tok:match('^-') then
              return tok
            end
          end
        end
        return 'remote'
      end
    end
    local ok_fg, fg = pcall(function()
      return pane:get_foreground_process_name()
    end)
    local fg_bin = ((ok_fg and fg) and (fg:match('([^/\\]+)$') or fg) or ''):lower():gsub('%.exe$', '')
    if fg_bin == 'ssh' or fg_bin == 'mosh' or fg_bin == 'mosh-client' then
      return 'remote'
    end
    return nil
  end

  wezterm.GLOBAL._wt_agent_notified = wezterm.GLOBAL._wt_agent_notified or {}

  wezterm.on('update-status', function(window, pane)
    local cols = 200
    local ok_dims, dims = pcall(function()
      return pane:get_dimensions()
    end)
    if ok_dims and dims and dims.cols then
      cols = dims.cols
    end
    local wide = cols >= 90

    local segments = {}
    local ssh_danger_badge = nil

    if st.ssh_host ~= false then
      local ssh_host = detect_ssh_target(pane)
      if ssh_host then
        local low_h = ssh_host:lower()
        if low_h:find('prod') or low_h:find('prd') or low_h:find('^root@') then
          ssh_danger_badge = { text = ' ⚠ PROD:' .. ssh_host .. ' ', bg = '#dc2626', fg = '#ffffff' }
        else
          table.insert(segments, '󰣀 ssh:' .. ssh_host)
        end
      end
    end

    if st.agent_toast then
      pcall(function()
        wezterm.GLOBAL._wt_agent_notified = wezterm.GLOBAL._wt_agent_notified or {}
        local mw = window:mux_window()
        if not mw then
          return
        end
        local tlist = mw.tabs_with_info and mw:tabs_with_info() or nil
        if not tlist and mw.tabs then
          tlist = {}
          for _, mt in ipairs(mw:tabs()) do
            table.insert(tlist, { is_active = false, tab = mt })
          end
        end
        for _, item in ipairs(tlist or {}) do
          local mtab = item.tab or item
          local ap = mtab and mtab:active_pane() or nil
          if ap then
            local pid = tostring((ap.pane_id and ap:pane_id()) or (mtab.tab_id and mtab:tab_id()) or '0')
            local unseen = (not item.is_active) and (ap.has_unseen_output and ap:has_unseen_output() or false)
            if not unseen then
              wezterm.GLOBAL._wt_agent_notified[pid] = nil
            elseif not wezterm.GLOBAL._wt_agent_notified[pid] then
              local uv = (ap.get_user_vars and ap:get_user_vars()) or {}
              local ucmd = ((uv.WEZTERM_PROG or uv.WEZTERM_CMD or uv.cmd or ''):match('^%s*(%S+)') or ''):lower()
              local ptitle = (ap.get_title and ap:get_title() or ''):lower()
              local pfg = ((ap.get_foreground_process_name and ap:get_foreground_process_name() or ''):match('([^/\\]+)$') or ''):lower()
              local probe = ucmd .. ' ' .. pfg .. ' ' .. ptitle
              local ag = nil
              for _, name in ipairs { 'claude', 'gemini', 'antigravity', 'agy', 'codex', 'aider', 'opencode', 'goose', 'cline', 'amp' } do
                if probe:find('%f[%w]' .. name .. '%f[%W]') then
                  ag = name
                  break
                end
              end
              if ag then
                wezterm.GLOBAL._wt_agent_notified[pid] = true
                local ttitle = (mtab.get_title and mtab:get_title()) or ''
                window:toast_notification('AI Agent Ready', 'Agent (' .. ag .. ') has new output' .. (ttitle ~= '' and (' in ' .. ttitle) or ''), nil, 3500)
              end
            end
          end
        end
      end)
    end

    if st.mux_domain ~= false then
      local ok_dom, domain = pcall(function()
        return pane:get_domain_name()
      end)
      if ok_dom and domain and domain ~= '' and domain ~= 'local' then
        local ok_meta, meta = pcall(function()
          return pane:get_metadata()
        end)
        local lag = (ok_meta and type(meta) == 'table' and meta.since_last_response_ms) or nil
        if lag and lag > 0 then
          table.insert(segments, string.format('󰌘 %s %dms', domain, lag))
        else
          table.insert(segments, '󰌘 ' .. domain)
        end
      end
    end

    if wide and st.git_branch then
      local cwd_uri = pane:get_current_working_dir()
      local cwd_path = cwd_uri and (type(cwd_uri) == 'string' and cwd_uri:gsub('^file://[^/]*', '') or cwd_uri.file_path)
      local branch = git_branch(cwd_path)
      if branch ~= '' then
        table.insert(segments, ' ' .. branch)
      end
    end

    if st.battery ~= false and st.battery_mode ~= 'off' then
      local bat_opts = {
        enabled = st.battery ~= false,
        mode = st.battery_mode or 'always',
        style = st.battery_style or 'nerd',
        time = st.battery_time or 'off',
        warn = st.battery_warn or 30,
        crit = st.battery_crit or 15,
        toast = st.battery_toast == true,
        color = st.color or '#a6adc8',
      }
      local bat_segs = nil
      if loaded_theme and type(loaded_theme.format_battery_segments) == 'function' then
        local ok_bs, res_bs = pcall(loaded_theme.format_battery_segments, wezterm, window, bat_opts)
        if ok_bs and type(res_bs) == 'table' then
          bat_segs = res_bs
        end
      end
      if not bat_segs then
        bat_segs = {}
        local ok_bi, binfo = pcall(wezterm.battery_info)
        if ok_bi and type(binfo) == 'table' then
          local nf_steps = { '\u{f008e}', '\u{f007a}', '\u{f007b}', '\u{f007c}', '\u{f007d}', '\u{f007e}', '\u{f007f}', '\u{f0080}', '\u{f0081}', '\u{f0082}', '\u{f0079}' }
          for _, b in ipairs(binfo) do
            local pct = math.min(100, math.max(0, math.floor(((b.state_of_charge or 0) * 100) + 0.5)))
            local step = math.min(10, math.max(0, math.floor((pct + 5) / 10)))
            local b_state = tostring(b.state or '')
            local icon = b_state == 'Charging' and '\u{f0084}' or (nf_steps[step + 1] or '\u{f0079}')
            local fg = (b_state == 'Charging' or b_state == 'Full') and '#34d399' or (pct <= 15 and '#f87171' or (pct <= 30 and '#fbbf24' or (st.color or '#a6adc8')))
            table.insert(bat_segs, { text = string.format('%s %d%%', icon, pct), fg = fg, bold = pct <= 30 })
          end
        end
      end
      for _, bseg in ipairs(bat_segs) do
        if wide or (type(bseg) == 'table' and bseg.bg ~= nil) then
          table.insert(segments, bseg)
        end
      end
    end

    if st.clock then
      table.insert(segments, wezterm.strftime(st.clock))
    end

    local elements = {}
    if st.mode_indicator ~= false then
      local badge = nil
      if window:leader_is_active() then
        badge = { text = ' ⚡ LEADER ', bg = '#ea4335', fg = '#ffffff' }
      else
        local kt = window:active_key_table()
        if kt then
          badge = mode_badges[kt] or { text = ' 󰌌 ' .. kt:upper() .. ' ', bg = '#81c995', fg = '#202124' }
        end
      end
      if badge then
        table.insert(elements, { Background = { Color = badge.bg } })
        table.insert(elements, { Foreground = { Color = badge.fg } })
        table.insert(elements, { Attribute = { Intensity = 'Bold' } })
        table.insert(elements, { Text = badge.text })
        table.insert(elements, 'ResetAttributes')
      end
    end

    if ssh_danger_badge then
      table.insert(elements, { Background = { Color = ssh_danger_badge.bg } })
      table.insert(elements, { Foreground = { Color = ssh_danger_badge.fg } })
      table.insert(elements, { Attribute = { Intensity = 'Bold' } })
      table.insert(elements, { Text = ssh_danger_badge.text })
      table.insert(elements, 'ResetAttributes')
    end

    if #segments > 0 then
      local base_col = st.color or '#a6adc8'
      table.insert(elements, { Foreground = { Color = base_col } })
      table.insert(elements, { Text = '  ' })
      for idx, seg in ipairs(segments) do
        if idx > 1 then
          table.insert(elements, { Foreground = { Color = base_col } })
          table.insert(elements, { Text = '   ' })
        end
        if type(seg) == 'table' then
          if seg.bg then
            table.insert(elements, { Background = { Color = seg.bg } })
          end
          table.insert(elements, { Foreground = { Color = seg.fg or base_col } })
          if seg.bold then
            table.insert(elements, { Attribute = { Intensity = 'Bold' } })
          end
          table.insert(elements, { Text = seg.text })
          if seg.bg or seg.bold then
            table.insert(elements, 'ResetAttributes')
          end
        else
          table.insert(elements, { Foreground = { Color = base_col } })
          table.insert(elements, { Text = tostring(seg) })
        end
      end
      table.insert(elements, { Text = '  ' })
    end

    window:set_right_status(wezterm.format(elements))
  end)
end

-- ─── Scrollback & performance ────────────────────────────────────────────────
-- animation_fps = 1 makes the cursor blink a hard toggle; higher values repaint
-- the whole window at that rate forever (idle CPU burn). OpenGL beats WebGpu
-- on the Iris Xe iGPU, and fixing it avoids probing vulkaninfo on reload.
local p = section('performance')
set('scrollback_lines', p.scrollback_lines)
set('animation_fps', p.animation_fps)
set('max_fps', p.max_fps)
set('front_end', p.front_end)
set('automatically_reload_config', p.automatically_reload_config)

-- ─── Cursor & bell ───────────────────────────────────────────────────────────
local cu = section('cursor')
set('default_cursor_style', cu.style)
set('cursor_blink_rate', cu.blink_rate)

local be = section('bell')
set('audible_bell', be.audible)
set('visual_bell', be.visual)

-- ─── Hyperlinks ──────────────────────────────────────────────────────────────
local h = section('hyperlinks')
if h.quick_select then
  config.quick_select_patterns = config.quick_select_patterns or {}
  for _, pat in ipairs {
    '\\b[0-9a-f]{7,40}\\b',
    '\\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\\b',
    '\\b(?:\\d{1,3}\\.){3}\\d{1,3}(?::\\d{1,5})?\\b',
    '\\bv?\\d+\\.\\d+\\.\\d+(?:-[0-9A-Za-z.-]+)?\\b',
    '#[0-9a-fA-F]{6}\\b',
    '\\b[a-z][a-z0-9-]{2,62}-[0-9a-f]{8,10}-[a-z0-9]{5}\\b',
    '(?:[A-Za-z0-9_./-]+\\.[A-Za-z0-9]{1,8}):\\d+(?::\\d+)?',
  } do
    table.insert(config.quick_select_patterns, pat)
  end
end
if h.include_defaults ~= false or h.extra then
  config.hyperlink_rules = h.include_defaults ~= false and wezterm.default_hyperlink_rules() or {}
  for _, rule in ipairs(h.extra or {}) do
    table.insert(config.hyperlink_rules, rule)
  end
end

if h.open_in_editor ~= false then
  local function build_editor_args(ed, file_path, line_num)
    local base = (ed:match('([^/\\]+)$') or ed):lower()
    if base:find('^code') or base:find('^codium') or base:find('^cursor') or base == 'subl' then
      return { ed, '-g', file_path .. ':' .. line_num }
    elseif base == 'hx' or base == 'helix' or base == 'zed' then
      return { ed, file_path .. ':' .. line_num }
    end
    return { ed, '+' .. line_num, file_path }
  end

  wezterm.on('open-uri', function(window, pane, uri)
    local raw_target = type(uri) == 'string' and uri:match('^editfile://(.+)$') or nil
    if not raw_target then
      return
    end
    local file_part, line_num = raw_target:match('^(.+):(%d+)$')
    if not file_part then
      file_part = raw_target
      line_num = '1'
    end
    local resolved = file_part
    if not resolved:match('^/') and not resolved:match('^%a:[/\\]') then
      local cwd_uri = pane:get_current_working_dir()
      local cwd = cwd_uri
          and (type(cwd_uri) == 'string' and cwd_uri:gsub('^file://[^/]*', '') or cwd_uri.file_path)
        or ''
      cwd = cwd:gsub('/+$', '')
      if cwd ~= '' then
        resolved = cwd .. '/' .. resolved
      end
    end
    local editor = (h.editor and h.editor ~= '' and h.editor)
      or os.getenv('EDITOR')
      or os.getenv('VISUAL')
      or 'nvim'
    window:perform_action(
      act.SpawnCommandInNewTab {
        args = build_editor_args(editor, resolved, line_num),
      },
      pane
    )
    return false
  end)
end

-- ─── Multiplexer domains ─────────────────────────────────────────────────────
-- Local unix-domain mux: detach/reattach panes across GUI restarts.
set('unix_domains', section('mux').unix_domains)

-- ─── Keys & mouse ────────────────────────────────────────────────────────────
-- The leader is SUPER+CTRL+a: plain SUPER+<letter> is grabbed by GNOME Shell
-- under Wayland and never reaches WezTerm.
local k = section('keys')
set('leader', k.leader)
if k.bindings then
  config.keys = bindings(k.bindings)
end
if k.tables then
  config.key_tables = {}
  for name, list in pairs(k.tables) do
    config.key_tables[name] = bindings(list)
  end
end

local m = section('mouse')
if m.bindings then
  config.mouse_bindings = bindings(m.bindings)
end

-- ─── Command Palette (Ctrl+Shift+P) ──────────────────────────────────────────
if tb.command_palette ~= false then
  wezterm.on('augment-command-palette', function(window, pane)
    local has_studio_palette = loaded_theme and type(loaded_theme.command_palette_entries) == 'function'
    local entries = {
      {
        brief = 'Workflow: Broadcast Command to Shell Panes in Active Tab',
        icon = 'md_broadcast',
        action = custom_actions.BroadcastToPanes(),
      },
      {
        brief = 'Workflow: Rename Active Tab',
        icon = 'md_rename_box',
        action = custom_actions.RenameTab(),
      },
      {
        brief = 'Workflow: Open Last Command Output in $EDITOR',
        icon = 'md_file_document_edit',
        action = custom_actions.EditLastOutput(),
      },
      {
        brief = 'Workflow: Open URL on Screen (QuickSelect)',
        icon = 'md_open_in_new',
        action = custom_actions.OpenUrlQuickSelect(),
      },
    }
    if has_studio_palette then
      local ok_e, extra = pcall(loaded_theme.command_palette_entries, config, wezterm, window, pane)
      if ok_e and type(extra) == 'table' then
        for _, item in ipairs(extra) do
          table.insert(entries, item)
        end
      end
    else
      for _, fallback_entry in ipairs {
        {
          brief = 'Workflow: Switch / Spawn Project Workspace (zoxide + ~/projetos)',
          icon = 'md_folder_pound',
          action = custom_actions.ProjectSessionizer(),
        },
        {
          brief = 'Workflow: Toggle Zen / Presentation Mode (+4pt, distraction-free)',
          icon = 'md_meditation',
          action = custom_actions.ToggleZenMode(),
        },
        {
          brief = 'Workflow: Save Workspace & Tab Session Snapshot',
          icon = 'md_content_save',
          action = custom_actions.SaveSession(),
        },
        {
          brief = 'Workflow: Restore Workspace & Tab Session Snapshot',
          icon = 'md_backup_restore',
          action = custom_actions.RestoreSession(),
        },
      } do
        table.insert(entries, fallback_entry)
      end
    end
    return entries
  end)
end

-- ─── Escape hatches ──────────────────────────────────────────────────────────
-- extra: plain WezTerm options with no dedicated setting, copied as-is.
for key, value in pairs(section('extra')) do
  local ok, err = pcall(function()
    config[key] = value
  end)
  if not ok then
    wezterm.log_error('wezterm settings: extra.' .. key .. ': ' .. tostring(err))
  end
end

local user_file = dir .. '/user.lua'
if exists(user_file) then
  local ok, user = pcall(dofile, user_file)
  if ok and type(user) == 'function' then
    local applied, err = pcall(user, config, wezterm, settings)
    if not applied then
      wezterm.log_error('wezterm settings: user.lua failed: ' .. tostring(err))
    end
  elseif not ok then
    wezterm.log_error('wezterm settings: cannot load user.lua: ' .. tostring(user))
  end
end

return config
