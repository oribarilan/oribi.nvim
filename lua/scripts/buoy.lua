-- floating terminal, based off of tjdevries
-- https://github.com/tjdevries/advent-of-nvim/blob/master/nvim/plugin/floaterminal.lua

-- exiting terminal mode with double esc
vim.keymap.set('t', '<esc><esc>', '<c-\\><c-n>')

local state = {
  floating = {
    win = -1,
    current_tab = 1,
    tabs = {
      { buf = -1 },
      { buf = -1 },
    },
  },
}

local function get_window_title()
  return string.format(' Buoy [%d/%d] ', state.floating.current_tab, #state.floating.tabs)
end

local function create_floating_window(opts)
  opts = opts or {}
  local width = opts.width or math.floor(vim.o.columns * 0.8)
  local height = opts.height or math.floor(vim.o.lines * 0.8)

  -- Calculate the position to center the window
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  -- Define window configuration
  local win_config = {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = {
      { '╭', 'FloatBorder' },
      { '─', 'FloatBorder' },
      { '╮', 'FloatBorder' },
      { '│', 'FloatBorder' },
      { '╯', 'FloatBorder' },
      { '─', 'FloatBorder' },
      { '╰', 'FloatBorder' },
      { '│', 'FloatBorder' },
    },
    title = get_window_title(),
    title_pos = 'left',
  }

  -- create an empty buffer first
  local buf = vim.api.nvim_create_buf(false, true)

  -- create the floating window
  local win = vim.api.nvim_open_win(buf, true, win_config)

  return { win = win, buf = buf }
end

local function init_terminal_buffer(tab_index)
  local tab = state.floating.tabs[tab_index]

  -- create new terminal buffer if needed
  if not vim.api.nvim_buf_is_valid(tab.buf) or vim.bo[tab.buf].buftype ~= 'terminal' then
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.cmd.terminal()
    tab.buf = buf
  end

  return tab.buf
end

local function update_window_title()
  if vim.api.nvim_win_is_valid(state.floating.win) then
    vim.api.nvim_win_set_config(state.floating.win, {
      title = get_window_title(),
      title_pos = 'left',
    })
  end
end

local function switch_to_tab(tab_number)
  if tab_number >= 1 and tab_number <= #state.floating.tabs then
    state.floating.current_tab = tab_number
    if vim.api.nvim_win_is_valid(state.floating.win) then
      -- Initialize terminal if needed
      local buf = init_terminal_buffer(tab_number)
      -- Set the buffer in the window
      vim.api.nvim_win_set_buf(state.floating.win, buf)
      -- Update the window title
      update_window_title()
    end
  end
end

local toggle_terminal = function()
  if not vim.api.nvim_win_is_valid(state.floating.win) then
    local result = create_floating_window()
    state.floating.win = result.win

    -- Initialize the current tab's terminal buffer
    local buf = init_terminal_buffer(state.floating.current_tab)
    vim.api.nvim_win_set_buf(state.floating.win, buf)
  else
    vim.api.nvim_win_hide(state.floating.win)
  end
end

-- Key mappings
vim.api.nvim_create_user_command('Buoy', toggle_terminal, {})
vim.keymap.set({ 'n', 't' }, '<leader>bb', toggle_terminal, { desc = 'Toggle Buoy terminal' })
vim.keymap.set({ 'n', 't' }, '<leader>b1', function()
  switch_to_tab(1)
end, { desc = 'Switch to terminal tab 1' })
vim.keymap.set({ 'n', 't' }, '<leader>b2', function()
  switch_to_tab(2)
end, { desc = 'Switch to terminal tab 2' })
