return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        {
            "nvim-telescope/telescope-live-grep-args.nvim",
            version = "^1.0.0",
        },
    },
    keys = {
        {
            "<leader>/",
            function()
                require("telescope").extensions.live_grep_args.live_grep_args()
            end,
            desc = "Grep (Root Dir)",
        },
    },
    opts = function(_, opts)
        local lga_actions = require("telescope-live-grep-args.actions")
        opts.extensions = opts.extensions or {}
        opts.extensions.live_grep_args = {
            auto_quoting = true,
            mappings = {
                i = {
                    ["<C-k>"] = lga_actions.quote_prompt(),
                    ["<C-i>"] = lga_actions.quote_prompt({ postfix = " --iglob " }),
                    ["<C-f>"] = lga_actions.quote_prompt({ postfix = " -t " }),
                },
            },
        }
    end,
    config = function(_, opts)
        local telescope = require("telescope")
        telescope.setup(opts)
        telescope.load_extension("live_grep_args")
    end,
}
