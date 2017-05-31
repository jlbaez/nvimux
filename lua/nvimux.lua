nvimux = {}
nvimux.debug = {}
nvimux.config = {}
nvimux.bindings = {}
nvimux.term = {}
nvimux.term.prompt = {}

--[[
Nvimux: Neovim as a terminal multiplexer.

This is the lua reimplementation of VimL.
--]]


-- [ Private variables and tables
local nvim = vim.api
local consts = {
  terminal_quit = '<C-\\><C-n>',
  esc = '<ESC>',
}

local fns = {}
local nvim_proxy = {
  __index = function(table, key)
    key_ = 'nvimux_' .. key
    val = nil
    if fns.exists(key_) then
      val = nvim.nvim_get_var(key_)
      table[key] = val
    end
    return val
  end
}

local vars = {
  prefix = '<C-b>',
  vertical_split = ':NvimuxVerticalSplit',
  horizontal_split = ':NvimuxHorizontalSplit',
  quickterm_scope = 'g',
  quickterm_direction = 'botright',
  quickterm_orientation = 'vertical',
  quickterm_size = '',
  new_term = 'term',
  close_term = ':x'
}

vars.split_type = function(t)
  return t.quickterm_direction .. ' ' .. t.quickterm_orientation .. ' ' .. t.quickterm_size .. 'split'
end

-- [[ Table of default bindings
local bindings = {
  mappings = {
    ['<C-r>']  = {nvi  = {':so $MYVIMRC'}},
    ['!']      = {nvit = {':tabe %'}},
    ['%']      = {nvit = {function() return vars.vertical_split end} },
    ['"']      = {nvit = {function() return vars.horizontal_split end}},
    ['q']      = {nvit = {':NvimuxToggleTerm'}},
    ['w']      = {nvit = {':tabs'}},
    ['o']      = {nvit = {'<C-w>w'}},
    ['n']      = {nvit = {'gt'}},
    ['p']      = {nvit = {'gT'}},
    ['x']      = {nvi  = {':bd %'},
                  t    = {function() return vars.close_term end}},
    ['X']      = {nvi  = {':enew \\| bd #'}},
    ['h']      = {nvit = {'<C-w><C-h>'}},
    ['j']      = {nvit = {'<C-w><C-j>'}},
    ['k']      = {nvit = {'<C-w><C-k>'}},
    ['l']      = {nvit = {'<C-w><C-l>'}},
    [':']      = {t    = {':'}},
    ['[']      = {t    = {''}},
    [']']      = {nvit = {':NvimuxTermPaste'}},
    [',']      = {t    = {'', nvimux.term.prompt.rename}},
  },
  map_table    = {}
}

-- ]]

local defaults = {unpack(vars)}

setmetatable(vars, nvim_proxy)

-- ]

-- [ Private functions
-- [[ keybind commands
fns.bind_fn = function(options)
  return function(key, command)
    suffix = string.sub(command, 1, 1) == ':' and '<CR>' or ''
    prefix = options.prefix  or ''
    mode = options.mode
    nvim.nvim_command(mode .. 'noremap <silent> ' .. vars.prefix .. key .. ' ' .. prefix .. command .. suffix)
  end
end

fns.bind = {
  t = fns.bind_fn{mode = 't', prefix = consts.terminal_quit},
  i = fns.bind_fn{mode = 'i', prefix = consts.esc},
  n = fns.bind_fn{mode = 'n'},
  v = fns.bind_fn{mode = 'v'}
}

fns.bind._ = function(key, mapping, modes)
  for _, mode in ipairs(modes) do
    fns.bind[mode](key, mapping)
  end
end
-- ]]

-- [[ Commands and helper functions
fns.split = function(str)
  p = {}
  for i=1, #str do
    table.insert(p, str:sub(i, i))
  end
  return p
end

fns.exists = function(var)
  return nvim.nvim_call_function('exists', {var}) == 1
end

fns.defn = function(var, val)
  if fns.exists(var) then
    nvim.nvim_set_var(var, val)
    return val
  else
    return nvim.nvim_get_var(var)
  end
end

fns.prompt = function(message)
  nvim.nvim_call_function('inputsave', {})
  ret = nvim.nvim_call_function('input', {message})
  nvim.nvim_call_function('inputrestore', {})
  return ret
end
-- ]]
-- ]

-- [ Public API
-- [[ Public, but non-preferred
nvimux._reset = function()
  for key, value in pairs(defaults) do
    nvimux.config.set(key, value)
  end
end

nvimux._refresh = function()
  for key, _ in pairs(vars) do
    vars[key] = nvim.nvim_get_var('nvimux_' .. key)
  end
end
-- ]]

-- [[ Config-handling commands
nvimux.config.set = function(options)
  vars[options.key] = options.value
  nvim.nvim_set_var('nvimux_' .. options.key, options.value)
end

nvimux.config.set_all = function(options)
  for key, value in pairs(options) do
    nvimux.config.set{['key'] = key, ['value'] = value}
  end
end
-- ]]

-- [[ Quickterm
nvimux.term.new_toggle = function()
  split_type = vars:split_type()
  nvim.nvim_command(split_type .. ' | enew | ' .. vars.new_term)
  buf_nr = nvim.nvim_call_function('bufnr', {'%'})
  nvim.nvim_set_option('wfw', true)
  nvim.nvim_buf_set_var(buf_nr, 'nvimux_buf_orientation', split_type)
  -- TODO Allow quickterm_scope
  nvimux.config.set{key = 'last_buffer_id', value = buf_nr}
end

nvimux.term.toggle = function()
  -- TODO Allow external commands
  if vars.last_buffer_id == nil then
    nvimux.term.new_toggle()
  else
    buf_nr = vars.last_buffer_id
    window = nvim.nvim_call_function('bufwinnr', {buf_nr})
    if window == -1 then
      if nvim.nvim_call_function('bufname', {buf_nr}) == '' then
        nvimux.term.new_toggle()
      else
        split_type = nvim.nvim_buf_get_var(buf_nr, 'nvimux_buf_orientation')
        nvim.nvim_command(split_type .. ' | b' .. buf_nr)
      end
    else
      nvim.nvim_command(window .. ' wincmd w | q | stopinsert')
    end
  end
end

nvimux.term.prompt.rename = function()
  nvimux.term_only{
    cmd = fns.prompt('nvimux > New term name: '),
    action = function(k) nvim.nvim_command('file term://' .. k) end
  }
end
-- ]]

-- [[ Top-level commands
nvimux.debug.vars = function()
  for k, v in pairs(vars) do
    print(k, v)
  end
end

nvimux.debug.bindings = function()
  for k, v in pairs(bindings.mappings) do
    print(k, v)
  end
  print('')
  for k, v in pairs(bindings.map_table) do
    print(k, v)
  end
end

nvimux.term_only = function(options)
  action = options.action or nvim.nvim_command
  if nvim.nvim_buf_get_option('%', 'buftype') == 'terminal' then
    action(options.cmd)
  else
    print("Not on terminal")
  end
end

nvimux.bindings.bind = function(options)
  if fns.exists('nvimux_override_' .. options.key) then
    options.value = nvim.nvim_get_var('nvimux_override_' .. var)
  end
  fns.bind._(options.key, options.value, options.modes)
end

nvimux.bindings.bind_all = function(options)
  for _, bind in ipairs(bindings) do
    fns.bind._(unpack(bind))
  end
end

nvimux.mapped = function(options)
  mapping = bindings.map_table[options.key]
  action = mapping.action or nvim.nvim_command
  if type(mapping.arg) == 'function' then
    arg = mapping.arg()
  else
    arg = mapping.arg
  end
  action(arg)
end
 -- ]]
-- ]

-- [ Runtime and warmup
for key, cmd in pairs(defaults) do
  if type(cmd) == "string" then
    if fns.exist('nvimux_'..key) then
      vars[key] = nvim.nvim_get_var('nvimux_'..key)
    else
      nvimux.config.set(key, cmd)
    end
  end
end

if fns.exists('nvimux_open_term_by_default') then
  bindings.mappings['c'] = { nvit = {function() return ':tabe | ' .. vars.new_term end}}
  bindings.mappings['t'] = { nvit = {':tabe'}}
else
  bindings.mappings['c'] = { nvit = {':tabe'}}
end

for i=1, 9 do
  bindings.mappings[i] = { nvit = {i .. 'gt'}}
end

for key, cmd in pairs(bindings.mappings) do
  for modes, data in pairs(cmd) do
    modes = fns.split(modes)
    arg, action = unpack(data)
    if type(arg) == 'function' or action ~= nil then
      bindings.map_table[key] = {['arg'] = arg, ['action'] = action}
      command = ':lua nvimux.mapped{key = "' .. key .. '"}'
    else
      command = arg
    end
    nvimux.bindings.bind{
      ['key'] = key,
      ['value'] = command,
      ['modes'] = modes,
    }
  end
end
-- ]