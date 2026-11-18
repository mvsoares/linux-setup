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

-- JSON action → KeyAssignment: "Name" for unit actions, { "Name": args } otherwise.
local function action(spec)
  if type(spec) == 'string' then
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
set('color_scheme', c.scheme)
set('bold_brightens_ansi_colors', c.bold_brightens_ansi_colors)

local t = section('terminal')
set('term', t.term)
set('unicode_version', t.unicode_version)
set('allow_square_glyphs_to_overflow_width', t.allow_square_glyphs_to_overflow_width)

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

-- Tab theme module written by wezterm-tab-theme-picker; it returns
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

-- Without a theme: cycle the fallback palette, "process|dir" titles.
local fb = tb.fallback
if not theme_applied and fb and fb.palette then
  local title_len = fb.title_len or 15

  local function format_fixed(text)
    if wezterm.column_width(text) > title_len then
      return wezterm.truncate_right(text, title_len - 1) .. '…'
    end
    return wezterm.pad_right(text, title_len)
  end

  wezterm.on('format-tab-title', function(tab)
    local pane = tab.active_pane
    local index = tab.tab_index + 1
    local colors = fb.palette[(tab.tab_index % #fb.palette) + 1]

    -- Directory name from OSC 7 (needs shell integration) or fallback
    local dir_name = '~'
    if pane.current_working_dir then
      local cwd = pane.current_working_dir.file_path
      dir_name = cwd:match('([^/]+)/?$') or cwd
    end

    -- Process name from bash hook (user_vars.cmd), fallback to foreground_process_name
    local process = (pane.user_vars or {}).cmd or ''
    if process == '' then
      process = (pane.foreground_process_name or ''):match('([^/\\]+)$') or ''
    end
    -- Hide common shells so the tab just shows the directory when idle
    if process == 'bash' or process == 'zsh' or process == 'fish' or process == 'tmux' or process == 'wezterm' then
      process = ''
    end

    local label = format_fixed(process ~= '' and (process .. '|' .. dir_name) or dir_name)

    if tab.is_active then
      return wezterm.format {
        { Background = { Color = colors.bg } },
        { Foreground = { Color = '#ffffff' } },
        { Attribute = { Intensity = 'Bold' } },
        { Attribute = { Underline = 'Single' } },
        { Text = colors.active_symbol .. index .. ' ' .. label .. ' ' },
      }
    end
    return wezterm.format {
      { Background = { Color = colors.bg } },
      { Foreground = { Color = '#ffffff' } },
      { Text = index .. ' ' .. colors.inactive_symbol .. ' ' .. label .. ' ' },
    }
  end)
end

-- ─── Status bar ──────────────────────────────────────────────────────────────
-- WezTerm's default tick is 1000ms; the clock only has minute resolution, so a
-- slower tick costs nothing visible and cuts the battery/git work per window.
local st = section('status')
if st.enabled then
  set('status_update_interval', st.interval_ms)

  local last_branch_check = 0
  local cached_branch = ''

  local function git_branch(cwd)
    if not cwd then
      return ''
    end
    local p = io.popen('git -C ' .. wezterm.shell_quote_arg(cwd) .. ' rev-parse --abbrev-ref HEAD 2>/dev/null')
    if not p then
      return ''
    end
    local branch = p:read('*l') or ''
    p:close()
    return branch
  end

  wezterm.on('update-status', function(window, pane)
    -- Branches change rarely: recheck at most every git_recheck_s seconds.
    if st.git_branch then
      local now = os.time()
      if now - last_branch_check >= (st.git_recheck_s or 10) then
        last_branch_check = now
        local cwd_uri = pane:get_current_working_dir()
        cached_branch = git_branch(cwd_uri and cwd_uri.file_path)
      end
    end

    local segments = {}
    if st.git_branch and cached_branch ~= '' then
      table.insert(segments, ' ' .. cached_branch)
    end
    if st.battery then
      for _, b in ipairs(wezterm.battery_info()) do
        table.insert(segments, string.format('%.0f%%', b.state_of_charge * 100))
      end
    end
    if st.clock then
      table.insert(segments, wezterm.strftime(st.clock))
    end

    window:set_right_status(wezterm.format {
      { Foreground = { Color = st.color or '#a6adc8' } },
      { Text = '  ' .. table.concat(segments, '   ') .. '  ' },
    })
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
