return {
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      current_line_blame = true, -- Enable blame by default
      current_line_blame_opts = {
        delay = 300, -- Set the delay to 150ms
      },
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'git [s]tage hunk' })
        map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'git [r]eset hunk' })
        map('n', '<leader>hs', gitsigns.stage_buffer, { desc = 'git [s]tage buffer' })
        map('n', '<leader>hu', gitsigns.stage_hunk, { desc = 'git [u]ndo stage hunk' })
        map('n', '<leader>hr', gitsigns.reset_buffer, { desc = 'git [r]eset buffer' })
        map('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'git [p]review hunk' })
        map('n', '<leader>hd', gitsigns.diffthis, { desc = 'git [d]iff against index' })
        map('n', '<leader>hd', function()
          gitsigns.diffthis '@'
        end, { desc = 'git [d]iff against last commit' })
      end,
    },
  },
}
