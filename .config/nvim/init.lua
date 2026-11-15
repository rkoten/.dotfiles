vim.loader.enable()  -- enable Neovim's Lua module cache

vim.g.mapleader = ' '

vim.o.autoindent = true
vim.o.cursorline = true
vim.o.expandtab = true
vim.o.number = true
vim.o.relativenumber = true
vim.o.smartindent = true
vim.o.smarttab = false
vim.o.softtabstop = -1  -- follow shiftwidth
vim.o.tabstop = 4
vim.o.timeout = true
vim.o.timeoutlen = 500  -- ms

vim.pack.add({
    -- adjusts 'shiftwidth' and 'expandtab' heuristically based on the current file
    'https://github.com/tpope/vim-sleuth',
})

vim.pack.add({
    { src = 'https://github.com/folke/which-key.nvim', version = vim.version.range('3.x') },
})

local wk = require('which-key')
wk.setup({ preset = 'classic' })
vim.keymap.set(
    'n',
    '<leader>?',
    function()
	wk.show({ global = false })
    end,
    { desc = 'Buffer local keymaps (which-key)' }
)
