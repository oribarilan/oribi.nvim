-- Managing tab/space indentation and linting in Neovim:
-- a. treesitter - responsible for identifying indentation
-- b. nvim - vim.options to define what happens in real time when you code
-- c. formatters (e.g., conform) - for applying the indentation in practice after an explicit format command (on save, on keymap, on insert-exit event, etc.)
return {
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_fallback = true }
        end,
        mode = '',
        desc = 'Format buffer',
      },
    },
    opts = {
      formatters_by_ft = {
        -- brew install stylua
        lua = { 'stylua' },
        -- pip install ruff
        python = { 'ruff_format' },
        -- npm install -g prettier
        json = { 'prettier' },
        yaml = { 'prettier' },
        markdown = { 'prettier' },
        -- dotnet tool isntall -g dotnet-format
        cs = { 'dotnet_format' },
      },
      formatters = {
        prettier = {
          prepend_args = {
            '--print-width',
            '100',
            '--prose-wrap',
            'always',
            '--use-tabs',
            'false',
            '--tab-width',
            '2',
          },
        },
        stylua = {
          prepend_args = { '--indent-type', 'Spaces', '--indent-width', '2' },
        },
        ruff_format = {
          command = 'ruff',
          args = { 'format', '--stdin-filename', '%filepath', '-' },
          stdin = true,
        },
        dotnet_format = {
          command = 'dotnet',
          args = {
            'format',
            '--include',
            '$FILENAME',
            '--no-restore',
            '--verbosity',
            'quiet'
          },
          stdin = false,
          cwd = require('conform.util').root_file({ '*.csproj', '*.sln' }),
        },
      },
    },
  },
  {
    'mfussenegger/nvim-lint',
    event = { 'BufWritePost', 'BufReadPost', 'InsertLeave' },
    config = function()
      local lint = require 'lint'
      lint.linters_by_ft = {
        python = { 'ruff' },
      }

      vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost', 'InsertLeave' }, {
        callback = function()
          require('lint').try_lint()
        end,
      })
    end,
  },
}
