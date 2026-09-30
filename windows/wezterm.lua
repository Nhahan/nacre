local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- WSL Ubuntu 를 기본 셸로
config.default_prog = { 'wsl.exe', '-d', 'Ubuntu', '--cd', '~' }

-- 폰트: Menlo 기반 Meslo LG M (macOS 터미널 폰트와 가장 비슷)
config.font = wezterm.font_with_fallback { 'Meslo LG M', 'Malgun Gothic' }
config.font_size = 12.0
config.adjust_window_size_when_changing_font_size = false  -- 글자 크기를 바꿔도 창 크기는 그대로
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }

-- iTerm2 Default 색상
config.colors = {
  foreground = '#c7c7c7',
  background = '#000000',
  cursor_bg = '#c7c7c7',
  cursor_fg = '#000000',
  cursor_border = '#c7c7c7',
  split = '#4a9eff',
  selection_bg = '#c1ddff',
  selection_fg = '#000000',
  ansi    = { '#000000', '#c91b00', '#00c200', '#c7c400', '#2225c4', '#ca30c7', '#00c5c7', '#c7c7c7' },
  brights = { '#686868', '#ff6e67', '#5ffa68', '#fffc67', '#6871ff', '#ff77ff', '#60fdff', '#ffffff' },
  tab_bar = {
    background = '#1c1c1c',
    active_tab   = { bg_color = '#000000', fg_color = '#e0e0e0' },
    inactive_tab = { bg_color = '#2b2b2b', fg_color = '#8a8a8a' },
    inactive_tab_hover = { bg_color = '#3a3a3a', fg_color = '#c7c7c7' },
    new_tab       = { bg_color = '#1c1c1c', fg_color = '#8a8a8a' },
    new_tab_hover = { bg_color = '#3a3a3a', fg_color = '#c7c7c7' },
  },
}
config.default_cursor_style = 'SteadyBlock'
config.inactive_pane_hsb = { saturation = 0.7, brightness = 0.5 }

-- 창 / 탭 UI
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.use_fancy_tab_bar = true
config.window_frame = {
  font = wezterm.font_with_fallback { 'Segoe UI', 'Malgun Gothic' },
  font_size = 10.0,
  active_titlebar_bg = '#1c1c1c',
  inactive_titlebar_bg = '#1c1c1c',
}
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32
config.window_padding = { left = 6, right = 6, top = 4, bottom = 4 }
config.initial_cols = 120
config.initial_rows = 34
config.scrollback_lines = 100000
config.enable_scroll_bar = false
config.audible_bell = 'Disabled'
config.window_close_confirmation = 'NeverPrompt'
config.check_for_updates = false

local equalize_panes  -- 아래에서 정의

-- 분할 후 균등화 (분할 직후 + 레이아웃이 반영된 뒤 한 번 더)
local function split_and_equalize(kind)
  return wezterm.action_callback(function(window, pane)
    if kind == 'h' then
      window:perform_action(act.SplitVertical { domain = 'CurrentPaneDomain' }, pane)
    else
      window:perform_action(act.SplitHorizontal { domain = 'CurrentPaneDomain' }, pane)
    end
    equalize_panes(window)
    wezterm.time.call_after(0.15, function() equalize_panes(window) end)
  end)
end

-- 키: iTerm 의 Cmd 대신 Ctrl+Shift
config.keys = {
  -- Ctrl+Shift+H: 위/아래 분할, Ctrl+Shift+V: 좌/우 분할 (분할 후 균등 배치)
  { key = 'h', mods = 'CTRL|SHIFT', action = split_and_equalize('h') },
  { key = 'v', mods = 'CTRL|SHIFT', action = split_and_equalize('v') },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = false } },
  { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'k', mods = 'CTRL|SHIFT', action = act.ClearScrollback 'ScrollbackAndViewport' },
  { key = 'Enter', mods = 'CTRL|SHIFT', action = act.TogglePaneZoomState },
  { key = 'LeftArrow',  mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow',    mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow',  mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Down' },
  -- Shift+Enter 줄바꿈
  { key = 'Enter', mods = 'SHIFT', action = act.SendString '\x1b\r' },
  -- Ctrl+C: 선택 영역이 있으면 복사, 없으면 실행 중단(SIGINT). Ctrl+V: 붙여넣기
  {
    key = 'c', mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      local sel = window:get_selection_text_for_pane(pane)
      if sel ~= nil and sel ~= '' then
        window:perform_action(act.CopyTo 'Clipboard', pane)
        window:perform_action(act.ClearSelection, pane)
      else
        window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
      end
    end),
  },
  { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
  -- Alt+←/→ 단어 이동 (zsh bindkey 와 짝)
  { key = 'LeftArrow',  mods = 'ALT', action = act.SendString '\x1b[1;3D' },
  { key = 'RightArrow', mods = 'ALT', action = act.SendString '\x1b[1;3C' },
}
for i = 1, 9 do
  table.insert(config.keys, { key = tostring(i), mods = 'ALT', action = act.ActivateTab(i - 1) })
end

-- 우클릭 메뉴 (iTerm 스타일). 숫자키 또는 방향키+Enter 로 선택
local menu_actions = {
  window = function(w, p) w:perform_action(act.SpawnWindow, p) end,
  tab    = function(w, p) w:perform_action(act.SpawnTab 'CurrentPaneDomain', p) end,
  splith = function(w, p) w:perform_action(split_and_equalize('h'), p) end,
  splitv = function(w, p) w:perform_action(split_and_equalize('v'), p) end,
  close  = function(w, p) w:perform_action(act.CloseCurrentPane { confirm = false }, p) end,
}

-- 분할 화면 균등 배치: 창 크기가 바뀌면 열은 같은 너비로, 행은 같은 높이로 맞춘다
local equalizing = false

local function distinct(infos, key)
  local seen, list = {}, {}
  for _, i in ipairs(infos) do
    if not seen[i[key]] then seen[i[key]] = true; table.insert(list, i[key]) end
  end
  table.sort(list)
  return list
end

-- axis: 'x'(열 너비) 또는 'y'(행 높이). 첫 번째부터 마지막-1 까지 경계를 목표 크기로 옮긴다
local function equalize_axis(window, tab, axis)
  local pos, size, grow, shrink
  if axis == 'x' then pos, size, grow, shrink = 'left', 'width', 'Right', 'Left'
  else pos, size, grow, shrink = 'top', 'height', 'Down', 'Up' end

  local infos = tab:panes_with_info()
  local starts = distinct(infos, pos)
  local n = #starts
  if n < 2 then return end
  local last_end = 0
  for _, i in ipairs(infos) do
    last_end = math.max(last_end, i[pos] + i[size])
  end
  local target = math.floor((last_end - starts[1] - (n - 1)) / n)  -- 경계선 1칸씩 제외

  for c = 1, n - 1 do
    infos = tab:panes_with_info()
    starts = distinct(infos, pos)
    local pane_c
    for _, i in ipairs(infos) do
      if i[pos] == starts[c] then pane_c = i; break end
    end
    if not pane_c then return end
    local d = target - pane_c[size]
    if d ~= 0 then
      pane_c.pane:activate()
      local dir, amt = grow, d
      if d < 0 then dir, amt = shrink, -d end
      window:perform_action(act.AdjustPaneSize { dir, amt }, pane_c.pane)
    end
  end
end

equalize_panes = function(window)
  if equalizing then return end
  equalizing = true
  pcall(function()
    local tab = window:active_tab()
    if #tab:panes() < 2 then return end
    local keep = window:active_pane()
    equalize_axis(window, tab, 'x')
    equalize_axis(window, tab, 'y')
    keep:activate()
  end)
  equalizing = false
end

wezterm.on('window-resized', function(window, pane) equalize_panes(window) end)

-- Ctrl + 마우스 휠: 글자 크기 조절
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = { WheelUp = 1 } } },
    mods = 'CTRL',
    action = act.IncreaseFontSize,
  },
  {
    event = { Down = { streak = 1, button = { WheelDown = 1 } } },
    mods = 'CTRL',
    action = act.DecreaseFontSize,
  },
}

-- 탭바의 [+] 버튼: 좌클릭 = 새 탭, 우클릭 = 메뉴
wezterm.on('new-tab-button-click', function(window, pane, button, default_action)
  if button == 'Right' then
    window:perform_action(
      act.InputSelector {
        title = '메뉴',
        fuzzy = false,
        alphabet = '12345',
        choices = {
          { id = 'window', label = '새 창' },
          { id = 'tab',    label = '새 탭' },
          { id = 'splith', label = '화면 분할 - Split Horizontally (위/아래)' },
          { id = 'splitv', label = '화면 분할 - Split Vertically (좌/우)' },
          { id = 'close',  label = '현재 화면 닫기' },
        },
        action = wezterm.action_callback(function(w, p, id, label)
          if id and menu_actions[id] then menu_actions[id](w, p) end
        end),
      },
      pane
    )
    return false
  end
  if default_action then
    window:perform_action(default_action, pane)
  end
  return false
end)

return config
