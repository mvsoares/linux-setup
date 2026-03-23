local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ─── Font ────────────────────────────────────────────────────────────────────
config.font = wezterm.font('JetBrainsMono Nerd Font', { weight = 'Regular' })
config.font_size = 14.0
config.line_height = 1.1

-- ─── Color Scheme ────────────────────────────────────────────────────────────
config.color_scheme = 'Monokai Remastered'

-- ─── Window ──────────────────────────────────────────────────────────────────
config.enable_wayland = false
config.window_background_opacity = 0.95
config.window_decorations = 'RESIZE'  -- hide titlebar, keep resize border
config.window_padding = { left = 10, right = 10, top = 10, bottom = 10 }
config.initial_cols = 220
config.initial_rows = 50

-- ─── Tab Bar ─────────────────────────────────────────────────────────────────
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = true
config.tab_max_width = 30
config.window_frame = {
  font = wezterm.font('JetBrainsMono Nerd Font', { weight = 'Bold' }),
  font_size = 12.5,
}

local tab_colors = {
  { bg = '#4285F4', light = '#D9E8FD' },  -- blue
  { bg = '#EA4335', light = '#FACDC8' },  -- red
  { bg = '#34A853', light = '#C4E8CF' },  -- green
  { bg = '#FBBC05', light = '#FEECB8' },  -- yellow
}

wezterm.on('format-tab-title', function(tab)
  local pane = tab.active_pane
  local index = tab.tab_index + 1
  local colors = tab_colors[(tab.tab_index % #tab_colors) + 1]

  -- Directory name from OSC 7 (needs shell integration) or fallback
  local cwd_uri = pane.current_working_dir
  local dir = '~'
  if cwd_uri then
    local cwd = cwd_uri.file_path
    dir = cwd:match('([^/]+)/?$') or cwd
  end

  -- Process name from bash hook (user_vars.cmd), fallback to foreground_process_name
  local process = ''
  local uv_cmd = (pane.user_vars or {}).cmd or ''
  if uv_cmd ~= '' then
    process = uv_cmd
  else
    local fg = pane.foreground_process_name or ''
    process = fg:match('([^/\\]+)$') or ''
  end

  -- Hide common shells so the tab just shows the directory when idle
  if process == 'bash' or process == 'zsh' or process == 'fish'
      or process == 'tmux' or process == 'wezterm' or process == '' then
    process = ''
  end

  -- Build label: "process|dir" or just "dir" if idle at shell
  local label = dir
  if process ~= '' then
    label = process .. '|' .. dir
  end

  if tab.is_active then
    return wezterm.format {
      { Background = { Color = colors.bg } },
      { Foreground = { Color = '#ffffff' } },
      { Attribute = { Intensity = 'Bold' } },
      { Text = ' ' .. index .. ' ' .. label .. ' ' },
    }
  else
    return wezterm.format {
      { Background = { Color = colors.light } },
      { Foreground = { Color = '#888888' } },
      { Attribute = { Intensity = 'Half' } },
      { Attribute = { Italic = true } },
      { Text = ' ' .. index .. ' ' .. label .. ' ' },
    }
  end
end)

-- ─── Scrollback & Performance ────────────────────────────────────────────────
config.scrollback_lines = 10000
config.animation_fps = 60
config.front_end = 'WebGpu'           -- GPU acceleration
config.automatically_reload_config = true

-- ─── Cursor ──────────────────────────────────────────────────────────────────
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 500

-- ─── Bell ────────────────────────────────────────────────────────────────────
config.audible_bell = 'Disabled'
config.visual_bell = { fade_in_duration_ms = 0, fade_out_duration_ms = 0 }

-- ─── Key Bindings ────────────────────────────────────────────────────────────
config.keys = {
  -- Pane splitting (tmux-style)
  { key = 'd', mods = 'SUPER',       action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'D', mods = 'SUPER',       action = wezterm.action.SplitVertical   { domain = 'CurrentPaneDomain' } },

  -- Pane navigation
  { key = 'h', mods = 'SUPER|CTRL',  action = wezterm.action.ActivatePaneDirection 'Left'  },
  { key = 'l', mods = 'SUPER|CTRL',  action = wezterm.action.ActivatePaneDirection 'Right' },
  { key = 'k', mods = 'SUPER|CTRL',  action = wezterm.action.ActivatePaneDirection 'Up'    },
  { key = 'j', mods = 'SUPER|CTRL',  action = wezterm.action.ActivatePaneDirection 'Down'  },

  -- Close pane
  { key = 'w', mods = 'SUPER',       action = wezterm.action.CloseCurrentPane { confirm = false } },

  -- Tabs
  { key = 't', mods = 'SUPER',       action = wezterm.action.SpawnTab 'CurrentPaneDomain' },
  { key = '[', mods = 'SUPER',       action = wezterm.action.ActivateTabRelative(-1) },
  { key = ']', mods = 'SUPER',       action = wezterm.action.ActivateTabRelative(1)  },

  -- Font size
  { key = '+', mods = 'SUPER',       action = wezterm.action.IncreaseFontSize },
  { key = '-', mods = 'SUPER',       action = wezterm.action.DecreaseFontSize },
  { key = '0', mods = 'SUPER',       action = wezterm.action.ResetFontSize    },

  -- Fullscreen
  { key = 'f', mods = 'SUPER|CTRL',  action = wezterm.action.ToggleFullScreen },

  -- Copy / Paste
  { key = 'c', mods = 'SUPER',       action = wezterm.action.CopyTo 'Clipboard'        },
  { key = 'v', mods = 'SUPER',       action = wezterm.action.PasteFrom 'Clipboard'     },

  -- Search
  { key = 'f', mods = 'SUPER',       action = wezterm.action.Search { CaseSensitiveString = '' } },
}

-- ─── Mouse ───────────────────────────────────────────────────────────────────
-- Triple-click selects semantic zone (shell output block)
config.mouse_bindings = {
  {
    event  = { Down = { streak = 3, button = 'Left' } },
    action = wezterm.action.SelectTextAtMouseCursor 'SemanticZone',
    mods   = 'NONE',
  },
}

return config
