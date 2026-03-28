local wezterm = require("wezterm")
local config = wezterm.config_builder()

----------------------------------------------------
-- Claude Code notification
----------------------------------------------------
-- タブ番号を取得する関数
local function get_tab_id(window, pane)
  local mux_window = window:mux_window()
  for i, tab_info in ipairs(mux_window:tabs_with_info()) do
    for _, p in ipairs(tab_info.tab:panes()) do
      if p:pane_id() == pane:pane_id() then
        return i
      end
    end
  end
end

wezterm.on('bell', function(window, pane)
  -- タブ番号を取得
  local tab_id = get_tab_id(window, pane)
  local message = tab_id and string.format('Task completed in tab %d', tab_id) or 'Task completed'

  -- OS通知を表示
  window:toast_notification('Claude Code', message, nil, 4000)

  -- macOS向けの追加機能（オプション）
  if wezterm.target_triple:find("darwin") then
    -- システムサウンドを再生（Submarineサウンド）
    os.execute('afplay /System/Library/Sounds/Submarine.aiff')

    -- 音声通知（コメントアウト状態）
    -- os.execute('say "Claude is calling you"')
  end
end)

config.automatically_reload_config = true
config.font = wezterm.font_with_fallback({
  'FiraCode Nerd Font',
  'Menlo',
  'Hiragino Sans GB',
  'monospace',
})
config.font_size = 14.0
config.use_ime = true
config.window_background_opacity = 0.75
config.macos_window_background_blur = 10

----------------------------------------------------
-- Tab
----------------------------------------------------
-- タイトルバーを非表示
-- config.window_decorations = "RESIZE"
-- タブバーの表示
-- config.show_tabs_in_tab_bar = true
-- タブが一つの時は非表示
-- config.hide_tab_bar_if_only_one_tab = true
-- falseにするとタブバーの透過が効かなくなる
-- config.use_fancy_tab_bar = false

-- タブバーの透過
-- config.window_frame = {
--   inactive_titlebar_bg = "none",
--   active_titlebar_bg = "none",
-- }

-- タブバーを背景色に合わせる
-- config.window_background_gradient = {
--   colors = { "#000000" },
-- }

-- タブの追加ボタンを非表示
config.show_new_tab_button_in_tab_bar = false
-- nightlyのみ使用可能
-- タブの閉じるボタンを非表示
-- config.show_close_tab_button_in_tabs = false

-- タブ同士の境界線を非表示
-- config.colors = {
--   tab_bar = {
--     inactive_tab_edge = "none",
--   },
-- }

-- タブの形をカスタマイズ
-- タブの左側の装飾
-- local SOLID_LEFT_ARROW = wezterm.nerdfonts.ple_lower_right_triangle
-- タブの右側の装飾
-- local SOLID_RIGHT_ARROW = wezterm.nerdfonts.ple_upper_left_triangle

-- wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
--   local background = "#2d373c"
--   local foreground = "#FFFFFF"
--   local edge_background = "none"
--   if tab.is_active then
--     background = "#2a37c3"
--     foreground = "#FFFFFF"
--   end
--   local edge_foreground = background
--   local title = "   " .. wezterm.truncate_right(tab.active_pane.title, max_width - 1) .. "   "
--   return {
--     { Background = { Color = edge_background } },
--     { Foreground = { Color = edge_foreground } },
--     { Text = SOLID_LEFT_ARROW },
--     { Background = { Color = background } },
--     { Foreground = { Color = foreground } },
--     { Text = title },
--     { Background = { Color = edge_background } },
--     { Foreground = { Color = edge_foreground } },
--     { Text = SOLID_RIGHT_ARROW },
--   }
-- end)

----------------------------------------------------
-- keybinds
----------------------------------------------------
config.disable_default_key_bindings = true
config.keys = require("keybinds").keys
config.key_tables = require("keybinds").key_tables
config.leader = { key = "q", mods = "CTRL", timeout_milliseconds = 2000 }
config.audible_bell = "SystemBeep"

return config
