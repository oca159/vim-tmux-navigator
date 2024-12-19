-- Ensure this script does not load in unsupported environments
if vim.g.loaded_tmux_navigator or vim.o.cp or vim.version().minor < 7 then
  return
end
vim.g.loaded_tmux_navigator = 1

-- Helper function for navigating within Vim
local function vim_navigate(direction)
  local ok = pcall(vim.cmd, "wincmd " .. direction)
  if not ok then
    vim.api.nvim_echo({{"E11: Invalid in command-line window; <CR> executes, CTRL-C quits: wincmd " .. direction, "ErrorMsg"}}, true, {})
  end
end

-- Check if tmux exists
local is_tmux = vim.env.TMUX ~= nil

-- Helper function to execute a tmux command
local function tmux_command(cmd)
  local socket = vim.split(vim.env.TMUX, ",")[1]
  local tmux_exec = vim.env.TMUX:match("tmate") and "tmate" or "tmux"
  local full_cmd = string.format("%s -S %s %s", tmux_exec, socket, cmd)
  return vim.fn.system(full_cmd)
end

-- Determine if the active tmux pane is zoomed
local function is_tmux_pane_zoomed()
  return tmux_command("display-message -p '#{window_zoomed_flag}'"):match("1")
end

-- Determine if there is a tmux pane in a specific direction
local function has_tmux_pane(direction)
  local position = {h = "left", l = "right"}
  return tmux_command(string.format("display-message -p '#{pane_at_%s}'", position[direction])):match("1")
end

-- Switch to next or previous tmux window
local function switch_tmux_window(direction)
  local cmd = direction == "h" and "select-window -p" or "select-window -n"
  tmux_command(cmd)
end

-- Forward navigation to tmux if necessary
local function tmux_or_vim_navigate(direction)
  local current_win = vim.fn.winnr()
  vim_navigate(direction)
  local at_tab_edge = current_win == vim.fn.winnr()

  if is_tmux and at_tab_edge then
    if direction == "h" or direction == "l" then
      if not has_tmux_pane(direction) then
        -- Switch to next/previous tmux window
        switch_tmux_window(direction)
        return
      end
    end

    local tmux_direction = {h = "L", j = "D", k = "U", l = "R"}
    local cmd = string.format("select-pane -%s", tmux_direction[direction])
    if vim.g.tmux_navigator_preserve_zoom == 1 then
      cmd = cmd .. " -Z"
    end
    tmux_command(cmd)
  end
end

-- Key mappings
if vim.g.tmux_navigator_no_mappings == nil then
  local opts = {silent = true}
  vim.keymap.set("n", "<C-h>", function() tmux_or_vim_navigate("h") end, opts)
  vim.keymap.set("n", "<C-j>", function() tmux_or_vim_navigate("j") end, opts)
  vim.keymap.set("n", "<C-k>", function() tmux_or_vim_navigate("k") end, opts)
  vim.keymap.set("n", "<C-l>", function() tmux_or_vim_navigate("l") end, opts)
  vim.keymap.set("n", "<C-\\>", function() tmux_or_vim_navigate("p") end, opts)
end

-- Save buffers on navigation if enabled
if vim.g.tmux_navigator_save_on_switch then
  vim.api.nvim_create_autocmd("WinLeave", {
    callback = function()
      if vim.g.tmux_navigator_save_on_switch == 1 then
        pcall(vim.cmd, "update")
      elseif vim.g.tmux_navigator_save_on_switch == 2 then
        pcall(vim.cmd, "wall")
      end
    end,
  })
end
