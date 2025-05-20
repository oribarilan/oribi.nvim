vim.keymap.set('n', '<leader>tn', function()
  require('neotest').run.run()
end, { desc = 'Run nearest test' })

vim.keymap.set('n', '<leader>tf', function()
  require('neotest').run.run(vim.fn.expand '%')
end, { desc = 'Run all tests in file' })

vim.keymap.set('n', '<leader>ts', function()
  require('neotest').summary.toggle()
end, { desc = 'Toggle test summary' })

vim.keymap.set('n', '<leader>to', function()
  require('neotest').output.open { enter = true }
end, { desc = 'Open test output' })

vim.keymap.set('n', '<leader>td', function()
  require('neotest').run.run { strategy = 'dap' }
end, { desc = 'Debug nearest test' })

vim.keymap.set('n', '<leader>tp', function()
  require('neotest').output_panel.open { enter = true }
end, { desc = 'Open and enter Neotest output panel' })

vim.keymap.set('n', '<leader>ts', function()
  require('neotest').summary.toggle()
end, { desc = 'Toggle Neotest test summary' })

return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',
    'nvim-neotest/neotest-python',
  },
  config = function()
    require('neotest').setup {
      adapters = {
        require 'neotest-python' {
          dap = { justMyCode = false },
        },
      },
    }
  end,
}
