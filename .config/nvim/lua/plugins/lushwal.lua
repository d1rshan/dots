return {
  {
    "oncomouse/lushwal.nvim",
    cmd = { "LushwalCompile" },
    init = function()
      vim.g.lushwal_configuration = {
        transparent_background = true,
        wal_path = vim.fn.expand("~/.cache/wal/colors.json"),
      }
    end,
    dependencies = {
      { "rktjmp/lush.nvim" },
      { "rktjmp/shipwright.nvim" },
    },
    lazy = false,
  },
}
