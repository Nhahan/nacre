local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Start WSL Ubuntu as the shell (the installer replaces 'Ubuntu' with your distro name)
config.default_prog = { 'wsl.exe', '-d', 'Ubuntu', '--cd', '~' }

-- Font: Meslo LG M (Menlo based, closest to the macOS terminal font); Malgun Gothic covers Korean.
-- The font files are read straight from the per-user fonts folder, so this works even when Windows
-- does not list per-user fonts (it may not after a restart).
config.font_dirs = { (os.getenv('LOCALAPPDATA') or '') .. '\\Microsoft\\Windows\\Fonts' }
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
-- Closing a tab, a pane or the window never asks for confirmation.
-- Tabs and panes would still ask while wsl.exe runs in them, so wsl.exe is on the skip list.
config.window_close_confirmation = 'NeverPrompt'
config.skip_close_confirmation_for_processes_named = {
  'wsl.exe', 'wslhost.exe', 'bash', 'sh', 'zsh', 'fish', 'tmux', 'nu', 'cmd.exe', 'pwsh.exe', 'powershell.exe',
}
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

local AXIS = {
  x = { pos = 'left', size = 'width',  grow = 'Right', shrink = 'Left', other_pos = 'top',  other_size = 'height' },
  y = { pos = 'top',  size = 'height', grow = 'Down',  shrink = 'Up',   other_pos = 'left', other_size = 'width' },
}

-- Equalizes one run of panes along an axis (x = widths, y = heights).
-- select(all_infos) returns the panes that form the run; it is called again before every move because
-- the layout changes. Every border except the last one is moved to its target size, the remainder cells
-- go to the first panes (sizes differ by at most 1). The pass is repeated until nothing moves any more.
-- Returns false when the run is not aligned (panes starting at the same position differ in size).

-- One entry per column (distinct start position): its start, its size and one pane that lies in it.
local function columns(tab, a, select)
  local infos = select(tab:panes_with_info())
  local starts = distinct(infos, a.pos)
  local sizes, panes = {}, {}
  for k, s in ipairs(starts) do
    for _, i in ipairs(infos) do
      if i[a.pos] == s then sizes[k] = i[a.size]; panes[k] = i.pane; break end
    end
  end
  return sizes, panes, starts
end

-- Moves the border between column c and column c+1 by d cells (d > 0: to the right / down, column c grows).
-- AdjustPaneSize moves the divider of the active pane's own parent split, and that is the wanted border
-- only for some panes of a nested layout. So try the pane on either side, look at where the borders really
-- are afterwards, and undo a move that hit another border. A border counts as moved correctly when its
-- position changed in the wanted direction and no earlier (already placed) border changed; later borders
-- may shift, because a resized group gives or takes its cells at its far end.
local function move_border(window, tab, a, select, c, d)
  local _, panes, before = columns(tab, a, select)
  local dir = (d > 0) and a.grow or a.shrink
  local back = (d > 0) and a.shrink or a.grow
  for _, pane in ipairs({ panes[c], panes[c + 1] }) do
    pane:activate()
    window:perform_action(act.AdjustPaneSize { dir, math.abs(d) }, pane)
    local _, _, after = columns(tab, a, select)
    local m = 0
    if #after == #before then
      local earlier_changed = false
      for k = 2, #before do  -- border k-1 sits at the start of column k
        local delta = after[k] - before[k]
        if math.abs(delta) > m then m = math.abs(delta) end
        if k - 1 < c and delta ~= 0 then earlier_changed = true end
      end
      local moved = after[c + 1] - before[c + 1]
      if ((d > 0 and moved > 0) or (d < 0 and moved < 0)) and not earlier_changed then return true end
    end
    if m > 0 then  -- a different border moved: put it back
      pane:activate()
      window:perform_action(act.AdjustPaneSize { back, m }, pane)
    end
  end
  return false
end

local function run_axis(window, tab, axis, select)
  local a = AXIS[axis]
  local infos = select(tab:panes_with_info())
  local starts = distinct(infos, a.pos)
  local n = #starts
  if n < 2 then return true end
  local size_at, mn, mx = {}, math.huge, -math.huge
  for _, i in ipairs(infos) do
    if size_at[i[a.pos]] and size_at[i[a.pos]] ~= i[a.size] then return false end
    size_at[i[a.pos]] = i[a.size]
    mn = math.min(mn, i[a.size]); mx = math.max(mx, i[a.size])
  end
  if mx - mn <= 1 then return true end  -- already equal, do not move anything
  local last_end = 0
  for _, i in ipairs(infos) do
    last_end = math.max(last_end, i[a.pos] + i[a.size])
  end
  local avail = last_end - starts[1] - (n - 1)  -- minus one cell per divider
  local base, rem = math.floor(avail / n), avail % n

  local previous
  for _ = 1, n + 2 do
    local moved = false
    for c = 1, n - 1 do
      local sizes = columns(tab, a, select)
      local d = base + ((c <= rem) and 1 or 0) - (sizes[c] or 0)
      if d ~= 0 and move_border(window, tab, a, select, c, d) then moved = true end
    end
    if not moved then break end
    local key = table.concat((columns(tab, a, select)), ',')
    if key == previous then break end  -- no progress: stop instead of moving borders back and forth
    previous = key
  end
  return true
end

-- Mixed layouts (e.g. two full-height panes next to one that is split top/bottom) are not aligned as a
-- whole, so each stack of panes that shares the same column (for y) or row (for x) is equalized on its own.
local function equalize_stacks(window, tab, axis)
  local a = AXIS[axis]
  local groups, order = {}, {}
  for _, i in ipairs(tab:panes_with_info()) do
    local key = i[a.other_pos] .. ':' .. i[a.other_size]
    if not groups[key] then groups[key] = { pos = i[a.other_pos], size = i[a.other_size], n = 0 }; table.insert(order, key) end
    groups[key].n = groups[key].n + 1
  end
  for _, key in ipairs(order) do
    local g = groups[key]
    if g.n >= 2 then
      local function select(all)
        local out = {}
        for _, i in ipairs(all) do
          if i[a.other_pos] == g.pos and i[a.other_size] == g.size then table.insert(out, i) end
        end
        table.sort(out, function(p, q) return p[a.pos] < q[a.pos] end)
        return out
      end
      -- only stacks whose panes touch (one divider cell between neighbours)
      local m, contiguous = select(tab:panes_with_info()), true
      for k = 2, #m do
        if m[k][a.pos] ~= m[k - 1][a.pos] + m[k - 1][a.size] + 1 then contiguous = false end
      end
      if contiguous then run_axis(window, tab, axis, select) end
    end
  end
end

local function equalize_axis(window, tab, axis)
  local whole = run_axis(window, tab, axis, function(all) return all end)
  if not whole then equalize_stacks(window, tab, axis) end
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

-- Closing a pane hands its space to a single neighbour, so equalize again afterwards
local function close_pane_and_equalize()
  return wezterm.action_callback(function(window, pane)
    window:perform_action(act.CloseCurrentPane { confirm = false }, pane)
    equalize_panes(window)
    -- once more after the new layout has been applied
    wezterm.time.call_after(0.15, function() pcall(equalize_panes, window) end)
  end)
end

-- Panes can also vanish without our key (exit / Ctrl+D in the shell, the tab's X button):
-- when the pane count of the active tab drops, equalize the remaining panes.
local pane_counts = {}
wezterm.on('update-status', function(window, pane)
  pcall(function()
    local tab = window:active_tab()
    if not tab then return end
    local id = tostring(window:window_id()) .. ':' .. tostring(tab:tab_id())
    local n = #tab:panes()
    local prev = pane_counts[id]
    pane_counts[id] = n
    if prev and n < prev and n >= 2 then equalize_panes(window) end
  end)
end)

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
  { key = 'w', mods = 'CTRL|SHIFT', action = close_pane_and_equalize() },
  { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'k', mods = 'CTRL|SHIFT', action = act.ClearScrollback 'ScrollbackAndViewport' },
  {
    -- zoom / un-zoom the pane; after un-zooming, equalize again (the window may have been resized meanwhile)
    key = 'z', mods = 'CTRL|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      window:perform_action(act.TogglePaneZoomState, pane)
      equalize_panes(window)  -- does nothing while a pane is zoomed
      wezterm.time.call_after(0.15, function() pcall(equalize_panes, window) end)
    end),
  },
  { key = 'LeftArrow',  mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow',    mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow',  mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Down' },
  -- Ctrl+Shift+Enter: new line (ESC + Enter)
  { key = 'Enter', mods = 'CTRL|SHIFT', action = act.SendString '\x1b\r' },
  -- Ctrl+Enter is left alone: WezTerm does nothing with it, the running program receives it as is
  { key = 'Enter', mods = 'CTRL', action = act.DisableDefaultAssignment },
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
  close  = function(w, p) w:perform_action(close_pane_and_equalize(), p) end,
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
