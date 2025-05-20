return {
  'nvimtools/none-ls.nvim',
  dependencies = {
    'nvimtools/none-ls-extras.nvim',
  },
  config = function()
    local null_ls = require 'null-ls'
    null_ls.setup {
      sources = {
        -- Use prettier for json, yaml, and markdown formatting
        null_ls.builtins.formatting.prettier.with {
          filetypes = { 'json', 'yaml', 'markdown' },
          extra_args = {
            '--print-width',
            '100',
            '--prose-wrap',
            'always',
          },
        },
        -- Lua formatting with stylua
        null_ls.builtins.formatting.stylua.with {
          extra_args = { '--indent-type', 'Spaces', '--indent-width', '2' },
        },
        -- Python formatting with Ruff
        null_ls.builtins.formatting.ruff_format,
      },
    }
    vim.keymap.set('n', '<leader>gf', vim.lsp.buf.format, {})
  end,
}
