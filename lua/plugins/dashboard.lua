return {
  'nvimdev/dashboard-nvim',
  event = 'VimEnter',
  config = function()
    require('dashboard').setup {
      theme = 'hyper',
      config = {
        -- week_header = {
        --   enable = true,
        -- },
        header = {
          '────────────────────────────────',
          '───────────────██████████───────',
          '──────────────████████████──────',
          '──────────────██────────██──────',
          '──────────────██▄▄▄▄▄▄▄▄▄█──────',
          '──────────────██▀███─███▀█──────',
          '█─────────────▀█────────█▀──────',
          '██──────────────────█───────────',
          '─█──────────────██──────────────',
          '█▄────────────████─██──████─────',
          '─▄███████████████──██──██████ ──',
          '────█████████████──██──█████████',
          '─────────────████──██─█████──███',
          '──────────────███──██─█████──███',
          '──────────────███─────█████████─',
          '──────────────██─────████████▀──',
          '────────────────██████████──────',
          '────────────────██████████──────',
          '─────────────────████████───────',
          '──────────────────██████████▄▄──',
          '────────────────────█████████▀──',
          '─────────────────────████──███──',
          '────────────────────▄████▄──██──',
          '────────────────────██████───▀──',
          '────────────────────▀▄▄▄▄▀──────',
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
          {
            icon = ' ',
            icon_hl = '@variable',
            desc = 'Nvim config',
            group = 'Label',
            action = function()
              vim.cmd 'cd ~/.config/nvim' -- change global cwd
              require('telescope.builtin').find_files { cwd = vim.fn.getcwd() }
            end,
            key = 'c',
          },
          {
            icon = ' ',
            icon_hl = '@variable',
            desc = 'zshrc',
            group = 'Label',
            action = 'edit ~/.config/zsh/',
            key = 'z',
          },
          {
            icon = '󱀺 ',
            icon_hl = '@variable',
            desc = 'dotfiles',
            group = 'Label',
            action = 'edit ~/.config/dotfiles/',
            key = 'd',
          },
          {
            icon = ' ',
            icon_hl = '@variable',
            desc = 'Port.Inference',
            group = 'Label',
            action = function()
              vim.cmd 'cd ~/repos/mde/Port.Inference' -- change global cwd
              require('telescope.builtin').find_files { cwd = vim.fn.getcwd() }
            end,
            key = 'i',
          },
        },
        packages = { enable = true },
        project = { enable = true, limit = 6, icon = '󰉋', label = ' Projects', action = 'Telescope find_files cwd=' },
        mru = { enable = true, limit = 10, icon = '󰈔', label = ' Recent Files', cwd_only = false },
        footer = {
          '',
          '',
          '"Everybody has a plan, until they get hit in the face." - Mike Tyson 🥊',
        },
      },
    }
  end,
  dependencies = { { 'nvim-tree/nvim-web-devicons' } },
}
