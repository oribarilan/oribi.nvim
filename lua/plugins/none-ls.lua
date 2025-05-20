return {
  'nvimtools/none-ls.nvim',
  dependencies = {
    'nvimtools/none-ls-extras.nvim',
  },
  config = function()
    local null_ls = require 'null-ls'
    null_ls.setup {
      sources = {
        null_ls.builtins.formatting.prettier.with { filetypes = { 'json', 'yaml', 'markdown' } },
        null_ls.builtins.formatting.stylua,
        require('none-ls.formatting.ruff').with { extra_args = { '--extend-select', 'I' } },
        require 'none-ls.formatting.ruff_format',
      },
    }
    vim.keymap.set('n', '<leader>gf', vim.lsp.buf.format, {})
  end,
}
