-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    -- disable spell checking
    vim.opt_local.spell = false

    -- if you also want diagnostics gone
    vim.diagnostic.disable(0)
  end,
})

local function apply_transparent_ui()
  local groups = {
    -- Core floating UI
    "NormalFloat",
    "FloatBorder",
    "FloatTitle",
    "FloatFooter",
    "Pmenu",
    "PmenuSbar",
    "PmenuThumb",
    -- Snacks UI (picker/explorer/popups)
    "SnacksNormal",
    "SnacksNormalNC",
    "SnacksWinBar",
    "SnacksWinBarNC",
    "SnacksWinSeparator",
    "SnacksBackdrop",
    "SnacksPicker",
    "SnacksPickerBorder",
    "SnacksPickerInput",
    "SnacksPickerInputBorder",
    "SnacksPickerPreview",
    "SnacksPickerPreviewBorder",
    "SnacksInputNormal",
    "SnacksInputBorder",
    -- Common sidebars/popups from other plugins
    "NeoTreeNormal",
    "NeoTreeNormalNC",
    "NeoTreeFloatBorder",
    "NvimTreeNormal",
    "NvimTreeNormalNC",
    "NvimTreeEndOfBuffer",
    "TroubleNormal",
    "TroubleNormalNC",
    "TroubleFloatBorder",
  }

  for _, group in ipairs(groups) do
    vim.api.nvim_set_hl(0, group, { bg = "NONE" })
  end
end

local function apply_transparent_ui_passes()
  apply_transparent_ui()
  for _, ms in ipairs({ 20, 80, 180, 360 }) do
    vim.defer_fn(apply_transparent_ui, ms)
  end
end

local transparent_ui_group = vim.api.nvim_create_augroup("transparent_ui", { clear = true })

vim.api.nvim_create_autocmd("ColorScheme", {
  group = transparent_ui_group,
  callback = function()
    vim.schedule(apply_transparent_ui_passes)
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  group = transparent_ui_group,
  callback = function()
    vim.schedule(apply_transparent_ui_passes)
  end,
})

-- LazyVim loads some UI plugins on/after VeryLazy. Re-apply transparency once they have initialized.
vim.api.nvim_create_autocmd("User", {
  group = transparent_ui_group,
  pattern = { "VeryLazy", "LazyVimStarted" },
  callback = function()
    vim.schedule(apply_transparent_ui_passes)
  end,
})

-- `nvim` (without args) often opens snacks_dashboard, which sets highlights late.
vim.api.nvim_create_autocmd("FileType", {
  group = transparent_ui_group,
  pattern = { "snacks_*" },
  callback = function()
    vim.schedule(apply_transparent_ui_passes)
  end,
})
