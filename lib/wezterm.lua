local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- GNOME may expose SSH via gcr/keyring sockets under /run/user/UID/gcr/ssh.
-- WezTerm's mux can try to symlink that path before it exists → ERROR mux::ssh_agent.
-- Disabling avoids clobbering SSH_AUTH_SOCK; use your real agent/socket as usual.
config.mux_enable_ssh_agent = false

-- ─── Font ────────────────────────────────────────────────────────────────────
config.font = wezterm.font('VictorMono NF', { weight = 'Regular' })
config.font_size = 12.5
config.line_height = 1.0

-- ─── Color Scheme ────────────────────────────────────────────────────────────
--config.color_scheme = 'Monokai Remastered'

-- ─── Window ──────────────────────────────────────────────────────────────────
config.window_background_opacity = 0.95
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.window_padding = { left = 10, right = 10, top = 10, bottom = 10 }
config.initial_cols = 220
config.initial_rows = 50

-- ─── Tab Bar ─────────────────────────────────────────────────────────────────
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = true
config.tab_max_width = 32
config.window_frame = {
  font = wezterm.font('VictorMono NFM Thin', { weight = 'Bold' }),
  font_size = 12,
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

  local title = ' ' .. index .. ' ' .. label .. ' '

  if tab.is_active then
    return wezterm.format {
      { Background = { Color = colors.bg } },
      { Foreground = { Color = '#ffffff' } },
      { Attribute = { Intensity = 'Bold' } },
      { Attribute = { Underline = 'Single' } },
      { Text = '⚡ == ' .. index .. ' ' .. label .. ' ' },
    }
  else
    return wezterm.format {
      { Background = { Color = colors.bg } },
      { Foreground = { Color = '#ffffff' } },
      { Text = '' .. index .. ' ' .. label .. ' ' },
    }
  end
end)

-- ─── Scrollback & Performance ────────────────────────────────────────────────
config.scrollback_lines = 10000
config.animation_fps = 60
-- Prefer WebGPU when a *real* GPU is available. In VMs, vulkaninfo may list
-- lavapipe/llvmpipe but EGL/Mesa can still hit ZINK "failed to choose pdev"
-- and spam libEGL warnings — OpenGL is more reliable there.
local function use_webgpu()
  local f = io.popen('vulkaninfo --summary 2>/dev/null')
  if not f then
    return false
  end
  local out = f:read('*a') or ''
  f:close()
  if out:find('deviceName') == nil then
    return false
  end
  -- Skip software-only stacks (VM / no GPU passthrough)
  local lower = out:lower()
  if lower:find('llvmpipe') or lower:find('lavapipe') or lower:find('swiftshader') then
    return false
  end
  return true
end
config.front_end = use_webgpu() and 'WebGpu' or 'OpenGL'
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
