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
  config.font = font(f.family, f.weight)
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
config.enable_wayland = not d.use_x11
set('dpi_by_screen', d.dpi_by_screen)

-- ─── Colors & terminal emulation ─────────────────────────────────────────────
local c = section('colors')
local dark_ui = is_appearance_dark()
if not dark_ui and c.scheme_light and c.scheme_light ~= '' then
  config.color_scheme = c.scheme_light
else
  set('color_scheme', c.scheme)
end
set('bold_brightens_ansi_colors', c.bold_brightens_ansi_colors)

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
if tb.theme_file then
  local path = dir .. '/' .. tb.theme_file
  if exists(path) then
    wezterm.add_to_config_reload_watch_list(path)
    local ok, theme = pcall(dofile, path)
    if ok and type(theme) == 'table' and type(theme.apply) == 'function' then
      local applied, err = pcall(theme.apply, config, wezterm)
      theme_applied = applied
      if not applied then
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
  set('status_update_interval', st.interval_ms)

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
    local ok, success, stdout = pcall(wezterm.run_child_process, {
      'git',
      '-C',
      cwd,
      'rev-parse',
      '--abbrev-ref',
      'HEAD',
    })
    local branch = ''
    if ok and success and stdout then
      branch = stdout:gsub('%s+$', '')
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

    if wide and st.battery then
      for _, b in ipairs(wezterm.battery_info()) do
        table.insert(segments, string.format('%.0f%%', b.state_of_charge * 100))
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

    if #segments > 0 then
      table.insert(elements, { Foreground = { Color = st.color or '#a6adc8' } })
      table.insert(elements, { Text = '  ' .. table.concat(segments, '   ') .. '  ' })
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
