-- lua/mytheme/init.lua
-- The actual theme implementation. Called by colors/mytheme.lua.
--
-- HOW HIGHLIGHT GROUPS WORK:
--   vim.api.nvim_set_hl(0, "GroupName", { fg = "#rrggbb", bg = "#rrggbb", bold = true, ... })
--   The 0 means "global namespace" — always use 0.
--   Attributes: bold, italic, underline, undercurl, underdouble, underdotted,
--               underdashed, strikethrough, reverse, nocombine, link = "OtherGroup"
--   "link" makes one group inherit another, which keeps things DRY.

local M = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- PALETTE
-- Define all your raw colors here. Give them semantic names so the highlight
-- definitions below read like intent rather than hex soup.
-- ─────────────────────────────────────────────────────────────────────────────
local p = {
  -- Backgrounds (darkest → lightest)
  bg0       = "#1a1b26", -- Primary editor background (Normal bg)
  bg1       = "#24253a", -- Slightly raised surface: cursorline, selected items
  bg2       = "#2e2f4a", -- Floating windows, popups (NormalFloat bg)
  bg3       = "#383960", -- Borders, inactive separators
  bg4       = "#444470", -- Subtle UI accents, column rulers

  -- Foregrounds (brightest → dimmest)
  fg0       = "#e0e2f0", -- Primary text (Normal fg)
  fg1       = "#c0c2d8", -- Secondary text: comments feel too bright at fg0
  fg2       = "#9094b0", -- Muted text: line numbers, inactive statusline
  fg3       = "#606480", -- Very dim: fold markers, end-of-buffer tildes

  -- Accent colors — used for syntax and UI highlights
  red       = "#f7768e", -- Errors, deletions, keywords like `return`/`break`
  orange    = "#ff9e64", -- Numbers, constants, warnings
  yellow    = "#e0af68", -- Strings (warm tone), TODO comments
  green     = "#9ece6a", -- Added lines in diffs, successful diagnostics
  teal      = "#2ac3de", -- Built-in types, special identifiers
  cyan      = "#7dcfff", -- Function calls, member access
  blue      = "#7aa2f7", -- Keywords, statements, links
  purple    = "#bb9af7", -- Types, constructors, attributes/decorators
  magenta   = "#ff007c", -- Search matches, flash/jump labels (high contrast)

  -- Git status colors
  git_add   = "#449dab", -- Added file / line
  git_mod   = "#6183bb", -- Modified file / line
  git_del   = "#914c54", -- Deleted file / line

  -- Diagnostic severity colors (map to LSP severity levels)
  diag_err  = "#db4b4b", -- Error   (severity 1)
  diag_warn = "#e0af68", -- Warning (severity 2)
  diag_info = "#0db9d7", -- Info    (severity 3)
  diag_hint = "#1abc9c", -- Hint    (severity 4)

  -- Special
  none      = "NONE",    -- Transparent background — use when you want the
                         -- terminal background to show through instead of a
                         -- solid color (useful for bg0 if you use a terminal
                         -- with a background image).
}

-- ─────────────────────────────────────────────────────────────────────────────
-- SYNTAX STYLES
-- Pre-composed attribute configs for syntax and treesitter highlight groups.
-- Each entry describes a semantic role in source code.
--
-- HOW DERIVATION WORKS (Lua's equivalent of JS spread):
--   JavaScript:  { ...base, bold: true }
--   Lua:         vim.tbl_extend("force", base, { bold = true })
--   "force" means the right-hand table wins on key conflicts.
--   `ext` below is a local shorthand for this pattern.
--
-- Only `s.plain` is truly comprehensive — every visual attribute listed
-- explicitly. All derived entries inherit the full set via tbl_extend,
-- so every style implicitly carries every attribute.
-- ─────────────────────────────────────────────────────────────────────────────
local ext = function(base, overrides)
  return vim.tbl_extend("force", base, overrides)
end

local s = {}

-- ── plain ─────────────────────────────────────────────────────────────────────
-- The root style. Every other style derives from this.
-- Primary foreground, transparent background, no decorations.
s.plain = {
  fg            = p.fg0,
  bg            = p.none,
  sp            = p.none,       -- special color: tints undercurl/underline strokes
  bold          = false,
  italic        = false,
  reverse       = false,
  nocombine     = false,
  underline     = false,
  undercurl     = false,        -- wavy stroke (diagnostics, spell check)
  underdouble   = false,        -- double underline
  underdotted   = false,        -- dotted underline
  underdashed   = false,        -- dashed underline
  strikethrough = false,
}

-- ── Tonal variants: foreground brightness only ────────────────────────────────
s.faded = ext(s.plain, { fg = p.fg2 })  -- secondary text (unchecked items, blockquotes)
s.muted = ext(s.plain, { fg = p.fg3 })  -- near-invisible (ignored text, placeholders)

-- ── keyword ───────────────────────────────────────────────────────────────────
-- Control flow, storage modifiers, imports: if, for, const, import, static…
s.keyword = ext(s.plain, { fg = p.blue })

-- ── intrinsic ─────────────────────────────────────────────────────────────────
-- Language-defined built-ins, operators, and special punctuation.
-- Things the language ships: built-in functions/types/modules, keyword-operators
-- (and, or, not), preprocessor directives, regex patterns.
s.intrinsic       = ext(s.plain,     { fg = p.teal })
s.intrinsicItalic = ext(s.intrinsic, { italic = true })  -- built-in attrs, link URLs

-- ── literal ───────────────────────────────────────────────────────────────────
-- Numeric/boolean values, named constants, and function parameters.
-- Parameters share this color intentionally: they are value-like bindings
-- at the call site, conceptually adjacent to constants.
s.literal     = ext(s.plain,   { fg = p.orange })
s.literalBold = ext(s.literal, { bold = true })   -- @constant.builtin: nil, null, true, false

-- ── str ───────────────────────────────────────────────────────────────────────
-- String and character literals.
s.str    = ext(s.plain, { fg = p.yellow })
s.strDoc = ext(s.str,   { italic = true })  -- docstrings: readable, slightly softer

-- ── func ──────────────────────────────────────────────────────────────────────
-- Function/method names (definitions and calls), member field access.
-- Member access shares this color: it is the "callable/accessible surface"
-- of an object, visually grouped with the things you invoke on it.
s.func = ext(s.plain, { fg = p.cyan })

-- ── type ──────────────────────────────────────────────────────────────────────
-- Type names, constructors, macros, and decorators/attributes.
s.type     = ext(s.plain, { fg = p.purple })
s.typeDef  = ext(s.type,  { bold = true })    -- definition site: `type Foo = …`
s.typeAttr = ext(s.type,  { italic = true })  -- decorators: @dataclass, #[derive(…)]

-- ── danger ────────────────────────────────────────────────────────────────────
-- Keywords and tokens that signal control disruption or failure:
-- return, break, throw, raise, try/catch, syntax errors, debug statements.
-- Also HTML/JSX tag names (red is a widely-adopted convention there).
s.danger       = ext(s.plain,  { fg = p.red })
s.dangerBold   = ext(s.danger, { bold = true })    -- hard syntax errors, FIXME badges
s.dangerItalic = ext(s.danger, { italic = true })  -- @variable.builtin: self, this, super

-- ── punctuation ───────────────────────────────────────────────────────────────
-- Delimiters, brackets, tag syntax: , ; . : ( ) [ ] { } < > /
-- Slightly dimmed so they don't compete visually with the tokens they separate.
s.punctuation = ext(s.plain, { fg = p.fg1 })

-- ── comment ───────────────────────────────────────────────────────────────────
-- Inline and block comments. Italic conventionally signals "not executable code".
s.comment    = ext(s.plain,   { fg = p.fg2, italic = true })
s.docComment = ext(s.comment, { fg = p.fg1 })  -- brighter: doc comments are API surface

-- ── commentWarn ───────────────────────────────────────────────────────────────
-- WARNING/HACK/WARN annotations inside comments. Colored text, no background.
s.commentWarn = ext(s.plain, { fg = p.yellow, bold = true })

-- ── badge ─────────────────────────────────────────────────────────────────────
-- Inverted-color inline blocks for high-visibility comment annotations.
-- Dark text on colored background. Background varies by type, so each
-- variant is defined separately rather than as a single derived entry.
s.badgeTodo = ext(s.plain, { fg = p.bg0, bg = p.yellow, bold = true })  -- TODO, WIP
s.badgeNote = ext(s.plain, { fg = p.bg0, bg = p.teal,   bold = true })  -- NOTE, INFO, HINT

-- ── markup formatting ─────────────────────────────────────────────────────────
-- Markdown/AsciiDoc inline decorations. No color override — typographic only.
s.markupBold      = ext(s.plain, { bold = true })
s.markupItalic    = ext(s.plain, { italic = true })
s.markupStrike    = ext(s.plain, { strikethrough = true })
s.markupUnderline = ext(s.plain, { underline = true })

-- ── heading ───────────────────────────────────────────────────────────────────
-- Section headings in markup. All bold; color steps down by heading level.
s.heading1 = ext(s.plain,    { fg = p.blue,   bold = true })
s.heading2 = ext(s.heading1, { fg = p.purple })
s.heading3 = ext(s.heading1, { fg = p.cyan })

-- ── link ──────────────────────────────────────────────────────────────────────
-- Hyperlink label text in markup: the [visible part] of [text](url).
-- The URL itself uses s.intrinsicItalic (teal + italic).
s.link = ext(s.plain, { fg = p.blue, underline = true })

-- ─────────────────────────────────────────────────────────────────────────────
-- HIGHLIGHT HELPER
-- ─────────────────────────────────────────────────────────────────────────────
local function hi(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SETUP
-- ─────────────────────────────────────────────────────────────────────────────
function M.setup()

  -- ───────────────────────────────────────────────────────────────────────────
  -- 1. BASE UI
  -- These are the foundational groups that everything else builds on.
  -- ───────────────────────────────────────────────────────────────────────────

  -- The default text and background for the entire editor.
  -- Every uncolored piece of text falls back to this.
  hi("Normal",       { fg = p.fg0, bg = p.bg0 })

  -- Non-current (unfocused) windows. Slightly dimmed to guide the eye.
  hi("NormalNC",     { fg = p.fg2, bg = p.bg0 })

  -- Floating windows: hover documentation, LSP signature help, diagnostics popup.
  -- LazyVim uses floats heavily — Telescope, noice, cmp all open them.
  hi("NormalFloat",  { fg = p.fg0, bg = p.bg2 })

  -- Border of floating windows (the box-drawing chars around the float).
  hi("FloatBorder",  { fg = p.bg3, bg = p.bg2 })

  -- Title bar text inside a float (e.g. "Documentation", "Definition").
  hi("FloatTitle",   { fg = p.blue, bg = p.bg2, bold = true })

  -- ── Cursor & Selection ────────────────────────────────────────────────────

  -- The line the cursor sits on. A subtle bg tint helps track position.
  hi("CursorLine",   { bg = p.bg1 })
  hi("CursorColumn", { bg = p.bg1 })

  -- The cursor itself. "reverse" flips fg/bg so it's always visible.
  hi("Cursor",       { reverse = true })
  hi("CursorIM",     { reverse = true }) -- Cursor in input-method mode.

  -- Visual-mode selection.
  hi("Visual",       { bg = p.bg3 })
  hi("VisualNOS",    { bg = p.bg3 }) -- Visual when Neovim doesn't own the selection.

  -- ── Line Numbers & Gutter ─────────────────────────────────────────────────

  -- Line numbers (the numbers in the left margin).
  hi("LineNr",       { fg = p.fg3 })

  -- The line number on the cursor's line — often bold/bright to stand out.
  hi("CursorLineNr", { fg = p.yellow, bold = true })

  -- Sign column: the narrow strip left of line numbers.
  -- Gitsigns and LSP diagnostics draw their icons here.
  hi("SignColumn",   { fg = p.fg3, bg = p.none })

  -- Fold-related gutter markers.
  hi("FoldColumn",   { fg = p.fg3, bg = p.none })

  -- The text shown for a closed fold, e.g. "+-- 14 lines: function foo ---".
  hi("Folded",       { fg = p.fg2, bg = p.bg1, italic = true })

  -- ── Statusline ────────────────────────────────────────────────────────────
  -- NOTE: LazyVim uses lualine, which manages its own colors via its own
  -- theming system (see lua/plugins/lualine.lua). These groups are used as
  -- fallback by Neovim's built-in statusline if lualine is not active.

  -- Active window's statusline bar.
  hi("StatusLine",   { fg = p.fg0, bg = p.bg2 })

  -- Inactive window statuslines (all windows that are not focused).
  hi("StatusLineNC", { fg = p.fg2, bg = p.bg1 })

  -- ── Tabline ───────────────────────────────────────────────────────────────
  -- LazyVim uses bufferline.nvim for tabs, but these are Neovim's built-in
  -- tabline groups (bufferline has its own BufferLine* groups further below).

  hi("TabLine",      { fg = p.fg2, bg = p.bg1 })    -- Inactive tab
  hi("TabLineSel",   { fg = p.fg0, bg = p.bg0, bold = true }) -- Active tab
  hi("TabLineFill",  { bg = p.bg1 })                -- Empty space in the tabline

  -- ── WinBar (breadcrumb bar above each window) ─────────────────────────────
  -- LazyVim enables the winbar for LSP context (e.g. "MyClass > myMethod").
  hi("WinBar",       { fg = p.fg0, bg = p.bg0 })
  hi("WinBarNC",     { fg = p.fg2, bg = p.bg0 })

  -- ── Window Separators ─────────────────────────────────────────────────────

  -- The vertical bar between side-by-side splits.
  hi("WinSeparator", { fg = p.bg3 })

  -- ── Search & Replace ──────────────────────────────────────────────────────

  -- All matches for the last search pattern (after pressing Enter).
  hi("Search",       { fg = p.bg0, bg = p.yellow })

  -- The match currently under the cursor (while typing in / or ?).
  hi("IncSearch",    { fg = p.bg0, bg = p.magenta, bold = true })

  -- In Neovim 0.9+, CurSearch specifically highlights the *current* match
  -- when there are multiple results (distinct from other matches in Search).
  hi("CurSearch",    { fg = p.bg0, bg = p.magenta, bold = true })

  -- `:s/old/new/` substitute preview highlight.
  hi("Substitute",   { fg = p.bg0, bg = p.red })

  -- Matching bracket/parenthesis highlight (when cursor is on one).
  hi("MatchParen",   { fg = p.orange, bold = true, underline = true })

  -- ── Misc UI ───────────────────────────────────────────────────────────────

  -- The column ruler (`:set colorcolumn=80`).
  hi("ColorColumn",  { bg = p.bg1 })

  -- Concealed text (e.g. markdown link URLs hidden by the conceal feature).
  hi("Conceal",      { fg = p.fg3 })

  -- The "~" symbols that fill space below the last line of a buffer.
  hi("EndOfBuffer",  { fg = p.bg3 })

  -- Non-printable characters when `:set list` is enabled (tabs, trailing spaces).
  hi("NonText",      { fg = p.bg4 })
  hi("SpecialKey",   { fg = p.bg4 })
  hi("Whitespace",   { fg = p.bg4 })

  -- Popup menu (`:` command completion, omnicompletion).
  -- nvim-cmp and LazyVim's completion override this with CmpItem* groups,
  -- but these matter for `:` wildmenu and vim's built-in completion.
  hi("Pmenu",        { fg = p.fg0, bg = p.bg2 })
  hi("PmenuSel",     { fg = p.bg0, bg = p.blue, bold = true })
  hi("PmenuSbar",    { bg = p.bg3 })   -- Popup scrollbar track
  hi("PmenuThumb",   { bg = p.fg2 })   -- Popup scrollbar thumb

  -- The command line at the bottom of the screen (noice.nvim overrides this).
  hi("ModeMsg",      { fg = p.green, bold = true })   -- Current mode indicator (INSERT, VISUAL…)
  hi("MsgArea",      { fg = p.fg0 })                  -- Message area background
  hi("MoreMsg",      { fg = p.green })                -- "-- More --" prompt
  hi("Question",     { fg = p.blue })                 -- Yes/no prompts
  hi("WarningMsg",   { fg = p.yellow })               -- Warning messages
  hi("ErrorMsg",     { fg = p.red })                  -- Error messages

  -- Current item in the quickfix / location list.
  hi("QuickFixLine", { bg = p.bg1, bold = true })

  -- Titles in :help and command output.
  hi("Title",        { fg = p.blue, bold = true })

  -- Directory names in file listings (netrw, :e path completion).
  hi("Directory",    { fg = p.blue })

  -- ── Diff ──────────────────────────────────────────────────────────────────
  -- Used by :diffthis, fugitive, gitsigns, and LazyVim's lazygit integration.

  hi("DiffAdd",      { fg = p.green, bg = p.bg0 })  -- Added lines
  hi("DiffChange",   { fg = p.blue,  bg = p.bg0 })  -- Changed lines
  hi("DiffDelete",   { fg = p.red,   bg = p.bg0 })  -- Deleted lines
  hi("DiffText",     { fg = p.bg0,   bg = p.blue })  -- Changed text within a changed line

  -- ── Spell Check ───────────────────────────────────────────────────────────

  hi("SpellBad",     { undercurl = true, sp = p.red })     -- Unrecognized word
  hi("SpellCap",     { undercurl = true, sp = p.yellow })  -- Should be capitalized
  hi("SpellLocal",   { undercurl = true, sp = p.blue })    -- Wrong region
  hi("SpellRare",    { undercurl = true, sp = p.purple })  -- Rare word

  -- ───────────────────────────────────────────────────────────────────────────
  -- 2. LEGACY SYNTAX GROUPS
  -- These have been in Vim for decades. Treesitter grammars link their capture
  -- groups to these as a fallback, so they still matter for any language that
  -- lacks a treesitter parser and for plugins that haven't moved to TS yet.
  -- ───────────────────────────────────────────────────────────────────────────

  hi("Comment",       s.comment)         -- // comments, -- comments, # comments

  hi("Constant",      s.literal)         -- MY_CONSTANT, nil, true, false (generic constants)
  hi("String",        s.str)             -- "string literals"
  hi("Character",     s.str)             -- 'c' (single characters)
  hi("Number",        s.literal)         -- 42, 0xff
  hi("Boolean",       s.literal)         -- true, false
  hi("Float",         s.literal)         -- 3.14

  hi("Identifier",    s.plain)           -- Variable names (generic)
  hi("Function",      s.func)            -- Function and method names

  hi("Statement",     s.keyword)         -- Generic statement keyword
  hi("Conditional",   s.keyword)         -- if, else, switch
  hi("Repeat",        s.keyword)         -- for, while, do
  hi("Label",         s.keyword)         -- case, default, goto labels
  hi("Operator",      s.intrinsic)       -- +, -, *, /, &&, ||
  hi("Keyword",       s.keyword)         -- Other keywords (import, return, etc.)
  hi("Exception",     s.danger)          -- try, catch, throw, raise

  hi("PreProc",       s.intrinsic)       -- Generic preprocessor
  hi("Include",       s.keyword)         -- #include, import, require
  hi("Define",        s.type)            -- #define
  hi("Macro",         s.type)            -- Macro invocations
  hi("PreCondit",     s.intrinsic)       -- #if, #ifdef

  hi("Type",          s.type)            -- int, string, MyClass (type names)
  hi("StorageClass",  s.keyword)         -- static, const, public, private
  hi("Structure",     s.type)            -- struct, class, interface, enum
  hi("Typedef",       s.type)            -- type aliases

  hi("Special",       s.intrinsic)       -- Generic special token
  hi("SpecialChar",   s.intrinsic)       -- Escape sequences: \n, \t, \u0041
  hi("Tag",           s.keyword)         -- HTML/XML tag names
  hi("Delimiter",     s.punctuation)     -- Punctuation: , ; . ( ) [ ] { }
  hi("SpecialComment",s.intrinsicItalic) -- Special annotations inside comments
  hi("Debug",         s.danger)          -- Debug statements

  hi("Underlined",    s.markupUnderline) -- Text that should be underlined
  hi("Ignore",        s.muted)           -- Hidden / irrelevant text
  hi("Error",         s.dangerBold)      -- Syntax errors
  hi("Todo",          s.badgeTodo)       -- TODO, FIXME, HACK in comments

  -- ───────────────────────────────────────────────────────────────────────────
  -- 3. TREESITTER CAPTURE GROUPS  (@-prefixed)
  -- Treesitter parsers produce a concrete syntax tree and tag each node with
  -- one of these captures. They are more precise than legacy groups.
  -- If a capture is not defined here, Neovim falls back to its linked legacy
  -- group (the fallbacks are defined in neovim's runtime/lua/vim/treesitter/).
  -- You only need to override captures where you want a different look.
  -- ───────────────────────────────────────────────────────────────────────────

  -- ── Variables ─────────────────────────────────────────────────────────────
  hi("@variable",           s.plain)         -- Local/global variable names
  hi("@variable.builtin",   s.dangerItalic)  -- self, this, super, cls
  hi("@variable.parameter", s.literal)       -- Function parameter names (value-like at call site)
  hi("@variable.member",    s.func)          -- Struct/object field access: obj.field

  -- ── Constants ─────────────────────────────────────────────────────────────
  hi("@constant",         s.literal)         -- MY_CONST, MAX_SIZE
  hi("@constant.builtin", s.literalBold)     -- nil, null, true, false, undefined
  hi("@constant.macro",   s.literal)         -- Macro-defined constants

  -- ── Modules / Namespaces ──────────────────────────────────────────────────
  hi("@module",         s.plain)             -- Module/namespace names (Math, os, std)
  hi("@module.builtin", s.intrinsic)         -- Built-in modules (io, string in Lua)

  -- ── Strings ───────────────────────────────────────────────────────────────
  hi("@string",               s.str)         -- "hello world"
  hi("@string.documentation", s.strDoc)      -- Docstrings (Python, Rust)
  hi("@string.regexp",        s.intrinsic)   -- /regex patterns/
  hi("@string.escape",        ext(s.plain, { fg = p.magenta })) -- \n, \t, \uXXXX (unique: magenta)
  hi("@string.special",       s.intrinsic)   -- Special string content (URLs in strings)
  hi("@character",            s.str)         -- 'c' character literals
  hi("@character.special",    s.intrinsic)   -- Special chars like \0

  -- ── Numbers ───────────────────────────────────────────────────────────────
  hi("@boolean",      s.literal)             -- true, false
  hi("@number",       s.literal)             -- 42, 0xff, 0b1010
  hi("@number.float", s.literal)             -- 3.14, 1e10

  -- ── Types ─────────────────────────────────────────────────────────────────
  hi("@type",            s.type)             -- User-defined type names: MyStruct, Result
  hi("@type.builtin",    s.intrinsic)        -- Built-in types: int, string, bool
  hi("@type.definition", s.typeDef)          -- Type alias/definition sites

  -- ── Attributes / Decorators ───────────────────────────────────────────────
  hi("@attribute",         s.typeAttr)       -- @decorator (Python), #[attr] (Rust)
  hi("@attribute.builtin", s.intrinsicItalic) -- Built-in attributes

  -- ── Functions ─────────────────────────────────────────────────────────────
  hi("@function",             s.func)        -- Function definitions
  hi("@function.builtin",     s.intrinsic)   -- Built-in functions: print, len, typeof
  hi("@function.call",        s.func)        -- Function call sites: foo()
  hi("@function.macro",       s.intrinsic)   -- Macro calls: vec![], println!
  hi("@function.method",      s.func)        -- Method definitions inside a class
  hi("@function.method.call", s.func)        -- Method call sites: obj.method()
  hi("@constructor",          s.type)        -- Constructor calls: MyClass(), new Foo()

  -- ── Keywords ──────────────────────────────────────────────────────────────
  hi("@keyword",                     s.keyword)   -- Generic keywords
  hi("@keyword.coroutine",           s.keyword)   -- async, await, yield
  hi("@keyword.function",            s.keyword)   -- function, def, fn, fun
  hi("@keyword.operator",            s.intrinsic) -- and, or, not, in, is
  hi("@keyword.import",              s.keyword)   -- import, require, use, from
  hi("@keyword.storage",             s.keyword)   -- static, const, let, var, mut
  hi("@keyword.repeat",              s.keyword)   -- for, while, loop, do
  hi("@keyword.return",              s.danger)    -- return (signals exit, grouped with disruption)
  hi("@keyword.debug",               s.danger)    -- debugger, breakpoint
  hi("@keyword.exception",           s.danger)    -- try, catch, throw, raise, rescue
  hi("@keyword.conditional",         s.keyword)   -- if, else, elif, unless, switch
  hi("@keyword.conditional.ternary", s.intrinsic) -- ? and : in ternary expressions
  hi("@keyword.directive",           s.intrinsic) -- #pragma, %directive
  hi("@keyword.directive.define",    s.intrinsic) -- #define, #undef

  -- ── Punctuation ───────────────────────────────────────────────────────────
  hi("@punctuation.delimiter", s.punctuation) -- , ; . :: (separators)
  hi("@punctuation.bracket",   s.punctuation) -- ( ) [ ] { } (matched brackets)
  hi("@punctuation.special",   s.intrinsic)   -- ... $ # (special punctuation)

  -- ── Labels ────────────────────────────────────────────────────────────────
  hi("@label",    s.keyword)                  -- goto labels, case labels, loop labels

  -- ── Operators ─────────────────────────────────────────────────────────────
  hi("@operator", s.intrinsic)               -- +, -, *, /, =, ==, !=, +=

  -- ── Comments ──────────────────────────────────────────────────────────────
  hi("@comment",               s.comment)    -- Regular comments
  hi("@comment.documentation", s.docComment) -- /// or /** doc comments
  hi("@comment.error",         s.dangerBold) -- FIXME, BUG, ERROR in comments
  hi("@comment.warning",       s.commentWarn) -- WARNING, WARN, HACK in comments
  hi("@comment.todo",          s.badgeTodo)  -- TODO, WIP
  hi("@comment.note",          s.badgeNote)  -- NOTE, INFO, HINT

  -- ── Markup (Markdown, AsciiDoc, etc.) ─────────────────────────────────────
  hi("@markup.heading",           s.heading1)        -- # Heading (generic fallback)
  hi("@markup.heading.1",         s.heading1)        -- # H1
  hi("@markup.heading.2",         s.heading2)        -- ## H2
  hi("@markup.heading.3",         s.heading3)        -- ### H3
  hi("@markup.quote",             s.comment)         -- > blockquote (reads like a comment)
  hi("@markup.math",              s.str)             -- $math$ inline, $$math$$ block
  hi("@markup.link",              s.link)            -- [link text](url) — the visible label
  hi("@markup.link.label",        s.func)            -- Reference-style link label [label]
  hi("@markup.link.url",          s.intrinsicItalic) -- The URL itself
  hi("@markup.raw",               s.intrinsic)       -- `inline code`
  hi("@markup.raw.block",         ext(s.intrinsic, { bg = p.bg1 })) -- fenced code block + bg tint
  hi("@markup.list",              s.keyword)         -- - bullet or 1. numbered item marker
  hi("@markup.list.checked",      ext(s.plain, { fg = p.green })) -- - [x] checked item
  hi("@markup.list.unchecked",    s.faded)           -- - [ ] unchecked item
  hi("@markup.strong",            s.markupBold)      -- **bold text**
  hi("@markup.italic",            s.markupItalic)    -- *italic text*
  hi("@markup.strikethrough",     s.markupStrike)    -- ~~strikethrough~~
  hi("@markup.underline",         s.markupUnderline) -- __underlined__ (AsciiDoc etc.)

  -- ── HTML / XML / JSX Tags ─────────────────────────────────────────────────
  hi("@tag",           s.danger)      -- <div>, <Component> (red: conventional for tag names)
  hi("@tag.attribute", s.str)         -- class="foo", onClick={...} (attr values are string-like)
  hi("@tag.delimiter", s.punctuation) -- < > / in tag syntax

  -- ───────────────────────────────────────────────────────────────────────────
  -- 4. LSP DIAGNOSTICS
  -- These are shown as: virtual text after the line, underlines in the code,
  -- signs in the sign column, and highlights in floating windows.
  -- ───────────────────────────────────────────────────────────────────────────

  -- Base diagnostic text (virtual text appended at end of line)
  hi("DiagnosticError", { fg = p.diag_err })
  hi("DiagnosticWarn",  { fg = p.diag_warn })
  hi("DiagnosticInfo",  { fg = p.diag_info })
  hi("DiagnosticHint",  { fg = p.diag_hint })
  hi("DiagnosticOk",    { fg = p.green })

  -- Virtual text (the inline annotations after lines with issues)
  hi("DiagnosticVirtualTextError", { fg = p.diag_err,  bg = "#2d202a" }) -- bg = subtle tint
  hi("DiagnosticVirtualTextWarn",  { fg = p.diag_warn, bg = "#2d2a1e" })
  hi("DiagnosticVirtualTextInfo",  { fg = p.diag_info, bg = "#1a2b32" })
  hi("DiagnosticVirtualTextHint",  { fg = p.diag_hint, bg = "#1a2b2b" })

  -- Underlines drawn under the problematic token in source code
  hi("DiagnosticUnderlineError", { undercurl = true, sp = p.diag_err })
  hi("DiagnosticUnderlineWarn",  { undercurl = true, sp = p.diag_warn })
  hi("DiagnosticUnderlineInfo",  { underdotted = true, sp = p.diag_info })
  hi("DiagnosticUnderlineHint",  { underdotted = true, sp = p.diag_hint })

  -- Diagnostics inside floating windows (hover, line diagnostics popup)
  hi("DiagnosticFloatingError", { fg = p.diag_err })
  hi("DiagnosticFloatingWarn",  { fg = p.diag_warn })
  hi("DiagnosticFloatingInfo",  { fg = p.diag_info })
  hi("DiagnosticFloatingHint",  { fg = p.diag_hint })

  -- Sign column icons (requires matching DiagnosticSign* in your LSP config)
  hi("DiagnosticSignError", { fg = p.diag_err, bg = p.none })
  hi("DiagnosticSignWarn",  { fg = p.diag_warn, bg = p.none })
  hi("DiagnosticSignInfo",  { fg = p.diag_info, bg = p.none })
  hi("DiagnosticSignHint",  { fg = p.diag_hint, bg = p.none })

  -- LSP reference highlights: when cursor is on a symbol, all references glow.
  hi("LspReferenceText",  { bg = p.bg3 })  -- The occurrence under cursor
  hi("LspReferenceRead",  { bg = p.bg3 })  -- Read references of that symbol
  hi("LspReferenceWrite", { bg = p.bg2, bold = true }) -- Write references (mutations)

  -- Inlay hints: the grey annotations LSP inserts (parameter names, inferred types)
  hi("LspInlayHint", { fg = p.fg3, bg = p.bg1, italic = true })

  -- Code lens: actionable annotations above functions (run tests, show references)
  hi("LspCodeLens",          { fg = p.fg3, italic = true })
  hi("LspCodeLensSeparator", { fg = p.bg3 })

  -- ───────────────────────────────────────────────────────────────────────────
  -- 5. PLUGIN HIGHLIGHTS
  -- LazyVim bundles a standard set of plugins. Define their groups here.
  -- ───────────────────────────────────────────────────────────────────────────

  -- ── gitsigns.nvim ─────────────────────────────────────────────────────────
  -- Signs in the gutter showing git diff status for each line.
  hi("GitSignsAdd",    { fg = p.git_add, bg = p.none })   -- New line (not in HEAD)
  hi("GitSignsChange", { fg = p.git_mod, bg = p.none })   -- Modified line
  hi("GitSignsDelete", { fg = p.git_del, bg = p.none })   -- Deleted line marker

  -- Inline blame text (shown at end of line with :Gitsigns toggle_current_line_blame)
  hi("GitSignsCurrentLineBlame", { fg = p.fg3, italic = true })

  -- Preview window for hunks (the diff popup opened by gitsigns)
  hi("GitSignsAddPreview",    { fg = p.git_add })
  hi("GitSignsDeletePreview", { fg = p.git_del })

  -- ── Telescope ─────────────────────────────────────────────────────────────
  -- Telescope is LazyVim's fuzzy finder. It has three panes:
  -- prompt (where you type), results (list), and preview (file content).
  hi("TelescopeNormal",         { fg = p.fg0, bg = p.bg0 })
  hi("TelescopeBorder",         { fg = p.bg3, bg = p.bg0 })

  hi("TelescopePromptNormal",   { fg = p.fg0, bg = p.bg1 })
  hi("TelescopePromptBorder",   { fg = p.bg3, bg = p.bg1 })
  hi("TelescopePromptTitle",    { fg = p.bg0, bg = p.blue, bold = true })
  hi("TelescopePromptPrefix",   { fg = p.blue })     -- The > prefix before your query

  hi("TelescopeResultsNormal",  { fg = p.fg0, bg = p.bg0 })
  hi("TelescopeResultsBorder",  { fg = p.bg3, bg = p.bg0 })
  hi("TelescopeResultsTitle",   { fg = p.fg0, bg = p.bg0 })

  hi("TelescopePreviewNormal",  { fg = p.fg0, bg = p.bg0 })
  hi("TelescopePreviewBorder",  { fg = p.bg3, bg = p.bg0 })
  hi("TelescopePreviewTitle",   { fg = p.bg0, bg = p.green, bold = true })

  hi("TelescopeMatching",       { fg = p.yellow, bold = true }) -- Characters matching your query
  hi("TelescopeSelection",      { fg = p.fg0, bg = p.bg2, bold = true }) -- Highlighted result row
  hi("TelescopeSelectionCaret", { fg = p.blue, bg = p.bg2 })  -- The > arrow on the selected row
  hi("TelescopeMultiSelection", { fg = p.purple })             -- Multi-selected items (<Tab>)

  -- ── neo-tree.nvim ─────────────────────────────────────────────────────────
  -- The file explorer sidebar (opened with <leader>e in LazyVim).
  hi("NeoTreeNormal",           { fg = p.fg0, bg = p.bg0 })
  hi("NeoTreeNormalNC",         { fg = p.fg1, bg = p.bg0 })
  hi("NeoTreeEndOfBuffer",      { fg = p.bg0, bg = p.bg0 })
  hi("NeoTreeRootName",         { fg = p.blue, bold = true }) -- The repo root directory label
  hi("NeoTreeDirectoryName",    { fg = p.fg0 })
  hi("NeoTreeDirectoryIcon",    { fg = p.blue })
  hi("NeoTreeFileName",         { fg = p.fg0 })
  hi("NeoTreeFileIcon",         { fg = p.blue })
  hi("NeoTreeIndentMarker",     { fg = p.bg3 })          -- Tree branch lines │
  hi("NeoTreeExpander",         { fg = p.fg2 })          -- ▶ / ▼ fold arrows
  hi("NeoTreeSymbolicLinkTarget",{ fg = p.teal, italic = true })
  hi("NeoTreeTitleBar",         { fg = p.bg0, bg = p.blue }) -- "Neo-tree" header bar

  -- Git status decorations in neo-tree (right-side letter badges)
  hi("NeoTreeGitAdded",     { fg = p.git_add })
  hi("NeoTreeGitModified",  { fg = p.git_mod })
  hi("NeoTreeGitDeleted",   { fg = p.git_del })
  hi("NeoTreeGitConflict",  { fg = p.red, bold = true })
  hi("NeoTreeGitIgnored",   { fg = p.fg3 })
  hi("NeoTreeGitUnstaged",  { fg = p.yellow })
  hi("NeoTreeGitUntracked", { fg = p.orange })
  hi("NeoTreeGitStaged",    { fg = p.git_add })

  -- ── nvim-cmp ──────────────────────────────────────────────────────────────
  -- The completion dropdown. LazyVim uses blink.cmp by default in recent
  -- versions, but these are the standard cmp groups if you use nvim-cmp.
  hi("CmpItemAbbr",          { fg = p.fg0 })                -- Non-matching text in completion item
  hi("CmpItemAbbrDeprecated",{ fg = p.fg3, strikethrough = true }) -- Deprecated items
  hi("CmpItemAbbrMatch",     { fg = p.blue, bold = true })  -- Matching characters in the item
  hi("CmpItemAbbrMatchFuzzy",{ fg = p.cyan, bold = true })  -- Fuzzy-matching characters
  hi("CmpItemMenu",          { fg = p.fg3, italic = true }) -- [LSP], [Buffer] source label
  hi("CmpDocumentation",     { fg = p.fg0, bg = p.bg2 })   -- Documentation float
  hi("CmpDocumentationBorder",{ fg = p.bg3, bg = p.bg2 })  -- Documentation float border

  -- Completion item kind icons (each LSP symbol kind gets its own color)
  hi("CmpItemKindFunction",  { fg = p.cyan })
  hi("CmpItemKindMethod",    { fg = p.cyan })
  hi("CmpItemKindConstructor",{ fg = p.purple })
  hi("CmpItemKindClass",     { fg = p.purple })
  hi("CmpItemKindInterface", { fg = p.teal })
  hi("CmpItemKindStruct",    { fg = p.purple })
  hi("CmpItemKindEnum",      { fg = p.orange })
  hi("CmpItemKindEnumMember",{ fg = p.orange })
  hi("CmpItemKindModule",    { fg = p.blue })
  hi("CmpItemKindKeyword",   { fg = p.blue })
  hi("CmpItemKindVariable",  { fg = p.fg0 })
  hi("CmpItemKindField",     { fg = p.cyan })
  hi("CmpItemKindProperty",  { fg = p.cyan })
  hi("CmpItemKindValue",     { fg = p.orange })
  hi("CmpItemKindConstant",  { fg = p.orange })
  hi("CmpItemKindSnippet",   { fg = p.yellow })
  hi("CmpItemKindText",      { fg = p.fg1 })
  hi("CmpItemKindUnit",      { fg = p.orange })
  hi("CmpItemKindFile",      { fg = p.blue })
  hi("CmpItemKindFolder",    { fg = p.blue })
  hi("CmpItemKindColor",     { fg = p.red })
  hi("CmpItemKindReference", { fg = p.teal })
  hi("CmpItemKindOperator",  { fg = p.teal })
  hi("CmpItemKindTypeParameter",{ fg = p.purple })
  hi("CmpItemKindCopilot",   { fg = p.teal })  -- GitHub Copilot suggestions

  -- ── which-key.nvim ────────────────────────────────────────────────────────
  -- The key-binding popup that appears after pressing <leader> or other prefixes.
  hi("WhichKey",          { fg = p.blue })    -- The key itself (<leader>, g, d…)
  hi("WhichKeyGroup",     { fg = p.purple })  -- Group names (+git, +lsp, +find…)
  hi("WhichKeyDesc",      { fg = p.fg0 })     -- Description of what the key does
  hi("WhichKeySeparator", { fg = p.fg3 })     -- The → between key and description
  hi("WhichKeyNormal",    { fg = p.fg0, bg = p.bg2 }) -- Background of the popup
  hi("WhichKeyBorder",    { fg = p.bg3, bg = p.bg2 }) -- Border of the popup
  hi("WhichKeyTitle",     { fg = p.blue, bold = true }) -- Title at top of popup

  -- ── noice.nvim ────────────────────────────────────────────────────────────
  -- Replaces the command line, messages area, and notification system.
  -- The cmdline popup appears when you press : / ? in normal mode.
  hi("NoiceCmdline",            { fg = p.fg0, bg = p.bg1 })
  hi("NoiceCmdlineIcon",        { fg = p.blue })         -- : icon for normal command
  hi("NoiceCmdlineIconSearch",  { fg = p.yellow })        -- / icon for search
  hi("NoiceCmdlinePopup",       { fg = p.fg0, bg = p.bg2 })
  hi("NoiceCmdlinePopupBorder", { fg = p.bg3, bg = p.bg2 })
  hi("NoiceCmdlinePopupTitle",  { fg = p.blue })

  -- Notification popups (top-right corner messages)
  hi("NoiceMini",      { fg = p.fg0, bg = p.bg1 })  -- Inline mini-message at bottom
  hi("NoicePopup",     { fg = p.fg0, bg = p.bg2 })
  hi("NoicePopupBorder",{ fg = p.bg3, bg = p.bg2 })

  -- ── indent-blankline.nvim ─────────────────────────────────────────────────
  -- Vertical guide lines that show indentation levels.
  hi("IblIndent", { fg = p.bg3 })              -- Inactive indent guides
  hi("IblScope",  { fg = p.blue })             -- The indent guide for the current scope

  -- ── mini.indentscope ──────────────────────────────────────────────────────
  -- An alternative scope highlighter also included in LazyVim.
  hi("MiniIndentscopeSymbol",   { fg = p.blue })    -- The animated scope line
  hi("MiniIndentscopePrefix",   { nocombine = true }) -- Prevents flicker artifact

  -- ── flash.nvim ────────────────────────────────────────────────────────────
  -- Jump-motion plugin activated by s/S in LazyVim (like leap/hop).
  hi("FlashBackdrop", { fg = p.fg3 })           -- Dims all non-jump text
  hi("FlashMatch",    { fg = p.fg0, bg = p.bg3 }) -- Other jump candidates
  hi("FlashCurrent",  { fg = p.bg0, bg = p.yellow, bold = true }) -- The match under cursor
  hi("FlashLabel",    { fg = p.bg0, bg = p.magenta, bold = true }) -- The jump label letters
  hi("FlashPrompt",   { fg = p.fg0, bg = p.bg2 })  -- Search prompt
  hi("FlashCursor",   { reverse = true })           -- Cursor during flash

  -- ── bufferline.nvim ───────────────────────────────────────────────────────
  -- The tab bar at the top showing open buffers.
  hi("BufferLineBackground",        { fg = p.fg2, bg = p.bg1 })  -- Inactive tabs
  hi("BufferLineBufferSelected",    { fg = p.fg0, bg = p.bg0, bold = true }) -- Active tab
  hi("BufferLineBufferVisible",     { fg = p.fg1, bg = p.bg0 })  -- Visible but unfocused
  hi("BufferLineSeparator",         { fg = p.bg1, bg = p.bg1 })  -- Divider between tabs
  hi("BufferLineSeparatorSelected", { fg = p.bg0, bg = p.bg0 })
  hi("BufferLineIndicatorSelected", { fg = p.blue, bg = p.bg0 }) -- Colored underline on active tab
  hi("BufferLineModified",          { fg = p.yellow, bg = p.bg1 }) -- Dot for unsaved changes
  hi("BufferLineModifiedSelected",  { fg = p.yellow, bg = p.bg0 })

  -- ── nvim-notify ───────────────────────────────────────────────────────────
  -- Standalone notification toasts (also used by noice).
  hi("NotifyERRORBorder", { fg = p.diag_err })
  hi("NotifyWARNBorder",  { fg = p.diag_warn })
  hi("NotifyINFOBorder",  { fg = p.diag_info })
  hi("NotifyDEBUGBorder", { fg = p.fg3 })
  hi("NotifyTRACEBorder", { fg = p.purple })
  hi("NotifyERRORIcon",   { fg = p.diag_err })
  hi("NotifyWARNIcon",    { fg = p.diag_warn })
  hi("NotifyINFOIcon",    { fg = p.diag_info })
  hi("NotifyDEBUGIcon",   { fg = p.fg3 })
  hi("NotifyTRACEIcon",   { fg = p.purple })
  hi("NotifyERRORTitle",  { fg = p.diag_err, bold = true })
  hi("NotifyWARNTitle",   { fg = p.diag_warn, bold = true })
  hi("NotifyINFOTitle",   { fg = p.diag_info, bold = true })
  hi("NotifyDEBUGTitle",  { fg = p.fg3, bold = true })
  hi("NotifyTRACETitle",  { fg = p.purple, bold = true })

  -- ── todo-comments.nvim ────────────────────────────────────────────────────
  -- Highlights TODO/FIXME/NOTE/etc. in comments with badges.
  hi("TodoBgTODO",  { fg = p.bg0, bg = p.yellow, bold = true })
  hi("TodoFgTODO",  { fg = p.yellow })
  hi("TodoBgFIXME", { fg = p.bg0, bg = p.red, bold = true })
  hi("TodoFgFIXME", { fg = p.red })
  hi("TodoBgNOTE",  { fg = p.bg0, bg = p.teal, bold = true })
  hi("TodoFgNOTE",  { fg = p.teal })
  hi("TodoBgHACK",  { fg = p.bg0, bg = p.orange, bold = true })
  hi("TodoFgHACK",  { fg = p.orange })
  hi("TodoBgWARN",  { fg = p.bg0, bg = p.diag_warn, bold = true })
  hi("TodoFgWARN",  { fg = p.diag_warn })
  hi("TodoBgPERF",  { fg = p.bg0, bg = p.purple, bold = true })
  hi("TodoFgPERF",  { fg = p.purple })

end

return M
