vim.loader.enable()  -- enable Neovim's Lua module cache

vim.g.mapleader = ' '

vim.o.autoindent = true
vim.o.cursorline = true
vim.o.number = true
vim.o.relativenumber = true
vim.o.shiftwidth = 4
vim.o.smartindent = true
vim.o.smarttab = true
vim.o.timeout = true
vim.o.timeoutlen = 500  -- ms

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
