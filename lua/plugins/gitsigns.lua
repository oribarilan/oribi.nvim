return {
    {
        'lewis6991/gitsigns.nvim',
        opts = {
            current_line_blame = true, -- Enable blame by default
            current_line_blame_opts = {
                delay = 300,     -- Set the delay to 150ms
            },
            on_attach = function(bufnr)
                local gitsigns = require 'gitsigns'

                local function map(mode, l, r, opts)
                    opts = opts or {}
                    opts.buffer = bufnr
                    vim.keymap.set(mode, l, r, opts)
                end

                -- Hunk-specific operations
                map('n', '<leader>ghs', gitsigns.stage_hunk, { desc = 'git hunk [s]tage' })
                map('n', '<leader>ghr', gitsigns.reset_hunk, { desc = 'git hunk [r]eset' })
                -- Note: undo_stage_hunk is deprecated, use stage_hunk on staged signs instead
                map('n', '<leader>ghp', gitsigns.preview_hunk, { desc = 'git hunk [p]review' })

                -- Buffer-wide git operations
                map('n', '<leader>gs', gitsigns.stage_buffer, { desc = 'git [s]tage buffer' })
                map('n', '<leader>gr', gitsigns.reset_buffer, { desc = 'git [r]eset buffer' })
                map('n', '<leader>gd', gitsigns.diffthis, { desc = 'git [d]iff against index' })
                map('n', '<leader>gD', function()
                    gitsigns.diffthis '@'
                end, { desc = 'git [D]iff against last commit' })
            end,
        },
    },
}
