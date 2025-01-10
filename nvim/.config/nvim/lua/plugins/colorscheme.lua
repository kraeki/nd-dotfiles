return {
  {
    "dracula/vim",
    name = "dracula",
    lazy = false, -- Load immediately
    priority = 1000, -- Ensure it loads before other plugins
    config = function()
      -- Apply the Dracula theme
      vim.cmd.colorscheme("dracula")

      -- Override the background color
      vim.cmd("highlight Normal guibg=#1E1F29")
    end,
  },
}
