return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewFileHistory" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
    { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview File History" },
  },
  opts = {
    enhanced_diff_hl = true, -- Better highlighting
    hooks = {
      diff_buf_read = function(bufnr)
        -- Disable some features in diff buffers for better performance
        vim.opt_local.wrap = false
      end,
    },
  },
}
