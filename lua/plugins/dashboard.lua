return {
  'nvimdev/dashboard-nvim',
  event = 'VimEnter',
  config = function()
    require('dashboard').setup {
      theme = 'hyper',
      config = {
        week_header = {
          enable = true,
        },
        shortcut = {
          {
            icon = ' ',
            icon_hl = '@variable',
            desc = 'Files',
            group = 'Label',
            action = 'Telescope find_files',
            key = 'f',
          },
        },
        packages = { enable = true },
        project = { enable = true, limit = 6, icon = '󰉋', label = ' Projects', action = 'Telescope find_files cwd=' },
        mru = { enable = true, limit = 10, icon = '󰈔', label = ' Recent Files', cwd_only = false },
      },
    }
  end,
  dependencies = { { 'nvim-tree/nvim-web-devicons' } },
}
