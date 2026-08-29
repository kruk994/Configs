return {
  "Diogo-ss/42-header.nvim",
  -- Wczytuj od razu: przy lazy-loadingu (tylko cmd/keys) autocmd od `auto_update`
  -- rejestruje sie dopiero po pierwszym uzyciu, wiec zapis pliku go nie odpala.
  event = "VeryLazy",
  cmd = { "Stdheader" },
  keys = { "<F1>" },
  init = function()
    -- Klasyczny 42header (stdheader.vim) czyta te zmienne zamiast $USER/$MAIL.
    vim.g.user42 = "jnandzik"
    vim.g.mail42 = "jnandzik@student.42warsaw.pl"
    -- Awaryjnie, gdyby wtyczka i tak siegala po srodowisko: odkomentuj te dwie linie.
    -- Dotyczy tylko procesu nvim (`:terminal`, `:!`), nie zmienia konta w systemie.
    vim.env.USER = "jnandzik"
    vim.env.MAIL = "jnandzik@student.42warsaw.pl"
  end,
  opts = {
    default_map = true, -- Default mapping <F1> in normal mode.
    auto_update = true, -- Update header when saving.
    user = "jnandzik", -- Your user.
    mail = "jnandzik@student.42warsaw.pl", -- Your mail.
    ---Max header size (not recommended change).
    --length = 80,
    ---Header margin (not recommended change).
    --margin = 5,
    ---ASCII art.
    --asciiart = { "---", "---", ... },
    ---Git config.
    git = {
      ---Enable Git support.  <- wylaczone: inaczej login idzie z `git config user.name`
      enabled = false,
      ---PATH to the Git binary.
      bin = "git",
      ---Use global user.name, otherwise use local user.name.
      user_global = false,
      ---Use global user.email, otherwise use local user.email.
      email_global = false,
    },
  },
  config = function(_, opts)
    require("42header").setup(opts)
  end,
}
