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
      { buf = -1 }
    },
  },
}

local function create_floating_window(opts)
  opts = opts or {}
  local width = opts.width or math.floor(vim.o.columns * 0.8)
  local height = opts.height or math.floor(vim.o.lines * 0.8)

  -- Calculate the position to center the window
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  -- Get or create buffer for current tab
  local current_tab = state.floating.tabs[state.floating.current_tab]
  local buf = nil
  if vim.api.nvim_buf_is_valid(current_tab.buf) then
    buf = current_tab.buf
  else
    buf = vim.api.nvim_create_buf(false, true) -- No file, scratch buffer
    current_tab.buf = buf
  end

  -- Define window configuration
  local win_config = {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = {
      { "╭", "FloatBorder" },
      { "─", "FloatBorder" },
      { "╮", "FloatBorder" },
      { "│", "FloatBorder" },
      { "╯", "FloatBorder" },
      { "─", "FloatBorder" },
      { "╰", "FloatBorder" },
      { "│", "FloatBorder" },
    },
    title = " Terminal [" .. state.floating.current_tab .. "] ",
    title_pos = "left",
  }

  -- Create the floating window
  local win = vim.api.nvim_open_win(buf, true, win_config)

  return { win = win }
end

local function init_terminal_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= 'terminal' then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.cmd.terminal()
    return buf
  end
  return buf
end

local function update_window_title()
  if vim.api.nvim_win_is_valid(state.floating.win) then
    vim.api.nvim_win_set_config(state.floating.win, {
      title = " Terminal [" .. state.floating.current_tab .. "] ",
      title_pos = "left",
    })
  end
end

local function switch_to_tab(tab_number)
  if tab_number >= 1 and tab_number <= #state.floating.tabs then
    state.floating.current_tab = tab_number
    if vim.api.nvim_win_is_valid(state.floating.win) then
      local current_tab = state.floating.tabs[state.floating.current_tab]
      -- Initialize terminal if needed
      current_tab.buf = init_terminal_buffer(current_tab.buf)
      -- Set the buffer in the window
      vim.api.nvim_win_set_buf(state.floating.win, current_tab.buf)
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
    local current_tab = state.floating.tabs[state.floating.current_tab]
    current_tab.buf = init_terminal_buffer(current_tab.buf)
    vim.api.nvim_win_set_buf(state.floating.win, current_tab.buf)
  else
    vim.api.nvim_win_hide(state.floating.win)
  end
end

-- Key mappings
vim.api.nvim_create_user_command('Buoy', toggle_terminal, {})
vim.keymap.set({ 'n', 't' }, '<leader>tt', toggle_terminal, { desc = 'Toggle Buoy terminal' })
vim.keymap.set('t', '<A-1>', function() switch_to_tab(1) end, { desc = 'Switch to terminal tab 1' })
vim.keymap.set('t', '<A-2>', function() switch_to_tab(2) end, { desc = 'Switch to terminal tab 2' })
