-- Floating terminal based on tjdevries
-- https://github.com/tjdevries/advent-of-nvim/blob/master/nvim/plugin/floaterminal.lua

--[[ State Configuration ]]
local state = {
  floating = {
    win = -1,
    current_buf = 1,
    bufs = {
      { buf = -1 }, -- Terminal buffer 1
      { buf = -1 }, -- Terminal buffer 2
      { buf = -1 }, -- Terminal buffer 3
      { buf = -1, command = 'lazygit' }, -- Lazygit buffer
    },
  },
}

--[[ Helper Functions ]]
local function get_window_title()
  local current_buf = state.floating.bufs[state.floating.current_buf]
  local command_str = current_buf.command and (' ' .. current_buf.command) or ''
  local mode = vim.api.nvim_get_mode().mode
  local mode_str = mode:match '^t' and ' [TERM]' or ' [NORM]'
  return string.format(' Buoy [%d/%d]%s%s ', state.floating.current_buf, #state.floating.bufs, mode_str, command_str)
end

local function update_window_title()
  if vim.api.nvim_win_is_valid(state.floating.win) then
    vim.api.nvim_win_set_config(state.floating.win, {
      title = get_window_title(),
      title_pos = 'left',
    })
  end
end

--[[ Window Management ]]
local function create_floating_window(opts)
  opts = opts or {}
  local width = opts.width or math.floor(vim.o.columns * 0.8)
  local height = opts.height or math.floor(vim.o.lines * 0.8)

  -- Calculate center position
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  -- Window configuration
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

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, win_config)

  return { win = win, buf = buf }
end

--[[ Terminal Management ]]
local function init_terminal_buffer(buf_index)
  local buf_config = state.floating.bufs[buf_index]

  if not vim.api.nvim_buf_is_valid(buf_config.buf) or vim.bo[buf_config.buf].buftype ~= 'terminal' then
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    if buf_config.command then
      buf_config.buf = buf
      vim.fn.termopen(buf_config.command)
    else
      vim.cmd.terminal()
      buf_config.buf = buf
    end
  end

  return buf_config.buf
end

local function switch_to_buffer(buf_number)
  if buf_number >= 1 and buf_number <= #state.floating.bufs then
    state.floating.current_buf = buf_number
    if not vim.api.nvim_win_is_valid(state.floating.win) then
      local result = create_floating_window()
      state.floating.win = result.win
    end
    local buf = init_terminal_buffer(buf_number)
    vim.api.nvim_win_set_buf(state.floating.win, buf)
    update_window_title()
  end
end

local function toggle_terminal()
  if not vim.api.nvim_win_is_valid(state.floating.win) then
    local result = create_floating_window()
    state.floating.win = result.win
    local buf = init_terminal_buffer(state.floating.current_buf)
    vim.api.nvim_win_set_buf(state.floating.win, buf)
  else
    vim.api.nvim_win_hide(state.floating.win)
  end
end

local function kill_current_buffer()
  if vim.api.nvim_win_is_valid(state.floating.win) then
    local current_buf_config = state.floating.bufs[state.floating.current_buf]
    local buf_to_delete = current_buf_config.buf

    vim.api.nvim_win_hide(state.floating.win)

    if vim.api.nvim_buf_is_valid(buf_to_delete) then
      vim.api.nvim_buf_delete(buf_to_delete, { force = true })
    end
    current_buf_config.buf = -1
  end
end

--[[ Key Mappings and Commands ]]
-- Terminal mode escape
vim.keymap.set('t', '<esc><esc>', '<c-\\><c-n>')

-- Toggle terminal
vim.api.nvim_create_user_command('Buoy', toggle_terminal, {})
vim.keymap.set('n', '<leader>bb', toggle_terminal, { desc = 'Toggle Buoy terminal' })

-- Buffer switching
vim.keymap.set('n', '<leader>b1', function()
  switch_to_buffer(1)
end, { desc = 'Switch to terminal buffer 1' })
vim.keymap.set('n', '<leader>b2', function()
  switch_to_buffer(2)
end, { desc = 'Switch to terminal buffer 2' })
vim.keymap.set('n', '<leader>b3', function()
  switch_to_buffer(3)
end, { desc = 'Switch to terminal buffer 3' })
vim.keymap.set('n', '<leader>bg', function()
  switch_to_buffer(4)
end, { desc = 'Switch to Lazygit' })

-- Buffer management
vim.keymap.set('n', '<leader>bk', kill_current_buffer, { desc = 'Kill current buoy buffer' })

--[[ Autocommands ]]
vim.api.nvim_create_autocmd({ 'ModeChanged' }, {
  callback = function()
    -- Only update title if we're in the Buoy window
    if vim.api.nvim_get_current_win() == state.floating.win then
      update_window_title()
    end
  end,
})
