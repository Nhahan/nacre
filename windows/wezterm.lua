local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Start WSL Ubuntu as the shell (the installer replaces 'Ubuntu' with your distro name)
config.default_prog = { 'wsl.exe', '-d', 'Ubuntu', '--cd', '~' }

-- Font: Meslo LG M (Menlo based, closest to the macOS terminal font); Malgun Gothic covers Korean
config.font = wezterm.font_with_fallback { 'Meslo LG M', 'Malgun Gothic' }
config.font_size = 12.0
config.adjust_window_size_when_changing_font_size = false  -- keep the window size when the font size changes
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }

-- iTerm2 Default colors
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

-- Window / tab bar
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
-- Closing the window kills everything running in WSL, so always ask first
config.window_close_confirmation = 'AlwaysPrompt'
config.check_for_updates = false

----------------------------------------------------------------------
-- Split panes keep equal sizes (after a split and when the window is resized)
----------------------------------------------------------------------
local equalizing = false

local function distinct(infos, key)
  local seen, list = {}, {}
  for _, i in ipairs(infos) do
    if not seen[i[key]] then seen[i[key]] = true; table.insert(list, i[key]) end
  end
  table.sort(list)
  return list
end

-- axis: 'x' (column widths) or 'y' (row heights).
-- Moves every border except the last one to its target size. The remainder cells go to the first
-- columns (sizes differ by at most 1). A border cannot move past a neighbour that has no room left,
-- so the pass is repeated until nothing moves any more.
local function equalize_axis(window, tab, axis)
  local pos, size, grow, shrink
  if axis == 'x' then pos, size, grow, shrink = 'left', 'width', 'Right', 'Left'
  else pos, size, grow, shrink = 'top', 'height', 'Down', 'Up' end

  local infos = tab:panes_with_info()
  local starts = distinct(infos, pos)
  local n = #starts
  if n < 2 then return end
  -- Only aligned layouts are handled: every pane that starts at the same position must have the same
  -- size (rows of panes / columns of panes). Mixed layouts are left alone instead of guessing.
  local size_at, mn, mx = {}, math.huge, -math.huge
  for _, i in ipairs(infos) do
    if size_at[i[pos]] and size_at[i[pos]] ~= i[size] then return end
    size_at[i[pos]] = i[size]
    mn = math.min(mn, i[size]); mx = math.max(mx, i[size])
  end
  if mx - mn <= 1 then return end  -- already equal, do not move anything
  local last_end = 0
  for _, i in ipairs(infos) do
    last_end = math.max(last_end, i[pos] + i[size])
  end
  local avail = last_end - starts[1] - (n - 1)  -- minus one cell per divider
  local base, rem = math.floor(avail / n), avail % n

  for _ = 1, n + 2 do
    local moved = false
    for c = 1, n - 1 do
      infos = tab:panes_with_info()
      starts = distinct(infos, pos)
      local pane_c
      for _, i in ipairs(infos) do
        if i[pos] == starts[c] then pane_c = i; break end
      end
      if not pane_c then return end
      local d = base + ((c <= rem) and 1 or 0) - pane_c[size]
      if d ~= 0 then
        moved = true
        pane_c.pane:activate()
        local dir, amt = grow, d
        if d < 0 then dir, amt = shrink, -d end
        window:perform_action(act.AdjustPaneSize { dir, amt }, pane_c.pane)
      end
    end
    if not moved then break end
  end
end

local function equalize_panes(window)
  if equalizing then return end
  equalizing = true
  pcall(function()
    local tab = window:active_tab()
    if not tab or #tab:panes() < 2 then return end
    for _, info in ipairs(tab:panes_with_info()) do
      if info.is_zoomed then return end  -- do not un-zoom a zoomed pane
    end
    local keep = window:active_pane()
    equalize_axis(window, tab, 'x')
    equalize_axis(window, tab, 'y')
    keep:activate()
  end)
  equalizing = false
end

wezterm.on('window-resized', function(window, pane) equalize_panes(window) end)

-- kind: 'h' = top/bottom, 'v' = left/right
local function split_and_equalize(kind)
  return wezterm.action_callback(function(window, pane)
    if kind == 'h' then
      window:perform_action(act.SplitVertical { domain = 'CurrentPaneDomain' }, pane)
    else
      window:perform_action(act.SplitHorizontal { domain = 'CurrentPaneDomain' }, pane)
    end
    equalize_panes(window)
    -- once more after the new layout has been applied
    wezterm.time.call_after(0.15, function() pcall(equalize_panes, window) end)
  end)
end

----------------------------------------------------------------------
-- Keys (Ctrl+Shift instead of the macOS Cmd key)
----------------------------------------------------------------------
config.keys = {
  { key = 'h', mods = 'CTRL|SHIFT', action = split_and_equalize('h') },  -- split top/bottom
  { key = 'v', mods = 'CTRL|SHIFT', action = split_and_equalize('v') },  -- split left/right
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = false } },
  { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'k', mods = 'CTRL|SHIFT', action = act.ClearScrollback 'ScrollbackAndViewport' },
  { key = 'Enter', mods = 'CTRL|SHIFT', action = act.TogglePaneZoomState },
  { key = 'LeftArrow',  mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow',    mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow',  mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Down' },
  -- Shift+Enter: new line (ESC + Enter)
  { key = 'Enter', mods = 'SHIFT', action = act.SendString '\x1b\r' },
  -- Ctrl+C copies when text is selected, otherwise it interrupts (SIGINT). Ctrl+V pastes.
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
  -- Alt+Left/Right: move by word (matches the zsh key bindings)
  { key = 'LeftArrow',  mods = 'ALT', action = act.SendString '\x1b[1;3D' },
  { key = 'RightArrow', mods = 'ALT', action = act.SendString '\x1b[1;3C' },
}
for i = 1, 9 do
  table.insert(config.keys, { key = tostring(i), mods = 'ALT', action = act.ActivateTab(i - 1) })
end

-- Ctrl + mouse wheel: change the font size
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

----------------------------------------------------------------------
-- Tab bar [+] button: left click = new tab, right click = menu (number keys or arrows + Enter)
----------------------------------------------------------------------
local menu_actions = {
  window = function(w, p) w:perform_action(act.SpawnWindow, p) end,
  tab    = function(w, p) w:perform_action(act.SpawnTab 'CurrentPaneDomain', p) end,
  splith = function(w, p) w:perform_action(split_and_equalize('h'), p) end,
  splitv = function(w, p) w:perform_action(split_and_equalize('v'), p) end,
  close  = function(w, p) w:perform_action(act.CloseCurrentPane { confirm = false }, p) end,
}

wezterm.on('new-tab-button-click', function(window, pane, button, default_action)
  if button == 'Right' then
    window:perform_action(
      act.InputSelector {
        title = 'Menu',
        fuzzy = false,
        alphabet = '12345',
        choices = {
          { id = 'window', label = 'New Window' },
          { id = 'tab',    label = 'New Tab' },
          { id = 'splith', label = 'Split Horizontally (top/bottom)' },
          { id = 'splitv', label = 'Split Vertically (left/right)' },
          { id = 'close',  label = 'Close Pane' },
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
