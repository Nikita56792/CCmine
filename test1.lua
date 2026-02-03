-- CC Remote Agent for ComputerCraft/CC:Tweaked (advanced computer)
-- Connects to a websocket server and allows remote file operations and program launch.

local CONFIG = {
  -- Example: "ws://192.168.0.10:8765/cc"
  server_url = "ws://192.168.1.227:8765/cc",
  auto_discover = true,
  reconnect_delay = 3,
  auth_token = "", -- optional shared token
  client_name = nil, -- optional name override
  discovery = {
    enabled = true,
    port = 8765,
    path = "/cc",
    timeout = 0.6,
    batch_size = 24,
    host_min = 1,
    host_max = 254,
    subnets = { "192.168.0.", "192.168.1.", "10.0.0.", "10.0.1.", "172.16.0." },
    last_url_file = "/.cc-remote-last-url",
  },
  monitor = {
    enabled = true,
    side = nil, -- set to "left"/"right"/... to force a specific monitor
    text_scale = 0.5,
    lock_file = "/.cc-remote-monitor.lock",
    poll_interval = 2,
  },
}

if not http or not http.websocket then
  print("HTTP/WebSocket API is not available. Enable http in ComputerCraft config.")
  return
end

local unpack = table.unpack or unpack

local function json_encode(tbl)
  return textutils.serializeJSON(tbl)
end

local function json_decode(str)
  return textutils.unserializeJSON(str)
end

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64_encode(data)
  return ((data:gsub(".", function(x)
    local byte = string.byte(x)
    local bits = ""
    for i = 8, 1, -1 do
      bits = bits .. (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and "1" or "0")
    end
    return bits
  end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
    if #x < 6 then return "" end
    local c = 0
    for i = 1, 6 do
      if x:sub(i, i) == "1" then
        c = c + 2 ^ (6 - i)
      end
    end
    return b64chars:sub(c + 1, c + 1)
  end) .. ({"", "==", "="})[#data % 3 + 1])
end

local function base64_decode(data)
  data = data:gsub("[^" .. b64chars .. "=]", "")
  return (data:gsub(".", function(x)
    if x == "=" then return "" end
    local f = (b64chars:find(x) - 1)
    local bits = ""
    for i = 6, 1, -1 do
      bits = bits .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
    end
    return bits
  end):gsub("%d%d%d%d%d%d%d%d", function(x)
    local c = 0
    for i = 1, 8 do
      if x:sub(i, i) == "1" then
        c = c + 2 ^ (8 - i)
      end
    end
    return string.char(c)
  end))
end

local function clean_path(path)
  if not path or path == "" then return "" end
  return fs.combine("", path)
end

local ws = nil
local running = {}
local monitor = nil
local monitor_side = nil
local monitor_lines = {}
local monitor_timer = nil

local function time_label()
  if textutils and textutils.formatTime then
    return textutils.formatTime(os.time(), true)
  end
  return string.format("%.1f", os.clock())
end

local function render_monitor()
  if not monitor then return end
  local w, h = monitor.getSize()
  monitor.setBackgroundColor(colors.black)
  monitor.setTextColor(colors.white)
  monitor.clear()
  local start = math.max(1, #monitor_lines - h + 1)
  local row = 1
  for i = start, #monitor_lines do
    local line = monitor_lines[i]
    if #line > w then line = line:sub(1, w) end
    monitor.setCursorPos(1, row)
    monitor.write(line)
    row = row + 1
    if row > h then break end
  end
end

local function log_line(msg)
  local line = string.format("[%s] %s", time_label(), msg)
  print(line)
  if monitor then
    monitor_lines[#monitor_lines + 1] = line
    if #monitor_lines > 200 then
      table.remove(monitor_lines, 1)
    end
    render_monitor()
  end
end

local function read_lock(path)
  if not path or not fs.exists(path) then return nil end
  local handle = fs.open(path, "r")
  if not handle then return nil end
  local raw = handle.readAll()
  handle.close()
  if not raw or raw == "" then return nil end
  local ok, info = pcall(textutils.unserialize, raw)
  if ok and type(info) == "table" then
    return info
  end
  return nil
end

local function write_lock(path, info)
  local handle = fs.open(path, "w")
  if not handle then return false end
  handle.write(textutils.serialize(info))
  handle.close()
  return true
end

local function acquire_monitor()
  local cfg = CONFIG.monitor or {}
  if not cfg.enabled then return false end
  if cfg.lock_file and fs.exists(cfg.lock_file) then
    local info = read_lock(cfg.lock_file)
    if info and info.id ~= os.getComputerID() then
      return false
    end
    fs.delete(cfg.lock_file)
  end
  local sides = {}
  if cfg.side then
    sides = { cfg.side }
  else
    sides = peripheral.getNames()
  end
  for _, side in ipairs(sides) do
    if peripheral.getType(side) == "monitor" then
      monitor = peripheral.wrap(side)
      monitor_side = side
      if cfg.text_scale then
        pcall(function() monitor.setTextScale(cfg.text_scale) end)
      end
      if cfg.lock_file then
        write_lock(cfg.lock_file, {
          id = os.getComputerID(),
          side = side,
          label = os.getComputerLabel(),
          time = os.clock(),
        })
      end
      monitor_lines = {}
      render_monitor()
      log_line("Monitor attached on " .. side)
      return true
    end
  end
  return false
end

local function release_monitor()
  local cfg = CONFIG.monitor or {}
  if monitor then
    monitor = nil
    monitor_side = nil
  end
  if cfg.lock_file and fs.exists(cfg.lock_file) then
    local info = read_lock(cfg.lock_file)
    if not info or info.id == os.getComputerID() then
      fs.delete(cfg.lock_file)
    end
  end
end

local function maybe_acquire_monitor()
  if monitor then return end
  acquire_monitor()
end

local function pause(seconds)
  sleep(seconds)
  local poll = (CONFIG.monitor and CONFIG.monitor.poll_interval) or 2
  monitor_timer = os.startTimer(poll)
  maybe_acquire_monitor()
end

local function send_message(tbl)
  if ws then
    pcall(function()
      ws.send(json_encode(tbl))
    end)
  end
end

local function send_event(name, data)
  send_message({ type = "event", event = name, data = data or {} })
end

local function send_response(id, ok, data, err)
  send_message({ type = "resp", id = id, ok = ok, data = data, error = err })
end

local function cleanup_running()
  if multishell and multishell.getTitle then
    for tab, _ in pairs(running) do
      if multishell.getTitle(tab) == nil then
        running[tab] = nil
      end
    end
  end
end

local function can_open_tab()
  return shell and shell.openTab ~= nil
end

local function can_terminate_tab()
  if multishell and multishell.terminate then
    return true
  end
  if shell and shell.resolveProgram and shell.resolveProgram("kill") then
    return true
  end
  return false
end

local function terminate_tab(tab)
  if multishell and multishell.terminate then
    return multishell.terminate(tab)
  end
  if shell and shell.resolveProgram and shell.resolveProgram("kill") then
    shell.run("kill", tostring(tab))
    return true
  end
  return false
end

local function handle_request(req)
  local op = req.op
  local args = req.args or {}

  if op == "list" then
    local path = clean_path(args.path or "")
    if path ~= "" and not fs.exists(path) then
      return nil, "path_not_found"
    end
    if path ~= "" and not fs.isDir(path) then
      return nil, "not_a_directory"
    end
    local items = {}
    for _, name in ipairs(fs.list(path)) do
      local full = fs.combine(path, name)
      items[#items + 1] = {
        name = name,
        isDir = fs.isDir(full),
        size = fs.isDir(full) and 0 or fs.getSize(full),
      }
    end
    table.sort(items, function(a, b)
      if a.isDir ~= b.isDir then return a.isDir end
      return a.name:lower() < b.name:lower()
    end)
    return { path = path, items = items }
  end

  if op == "stat" then
    local path = clean_path(args.path or "")
    if path == "" then
      return { exists = true, isDir = true, size = 0 }
    end
    if not fs.exists(path) then
      return { exists = false }
    end
    return { exists = true, isDir = fs.isDir(path), size = fs.isDir(path) and 0 or fs.getSize(path) }
  end

  if op == "read" then
    local path = clean_path(args.path or "")
    if path == "" or not fs.exists(path) then
      return nil, "file_not_found"
    end
    if fs.isDir(path) then
      return nil, "is_directory"
    end
    local offset = tonumber(args.offset) or 0
    local size = tonumber(args.size)
    local handle = fs.open(path, "r")
    if not handle then
      return nil, "cannot_open"
    end
    if offset > 0 then
      handle.seek("set", offset)
    end
    local chunk = size and handle.read(size) or handle.readAll()
    handle.close()
    chunk = chunk or ""
    local total = fs.getSize(path)
    local eof = (offset + #chunk) >= total
    return { path = path, b64 = base64_encode(chunk), offset = offset, total = total, eof = eof }
  end

  if op == "write" then
    local path = clean_path(args.path or "")
    if path == "" then
      return nil, "invalid_path"
    end
    local mode = args.mode == "append" and "a" or "w"
    local dir = fs.getDir(path)
    if dir and dir ~= "" then
      fs.makeDir(dir)
    end
    local handle, err = fs.open(path, mode)
    if not handle then
      return nil, err or "cannot_open"
    end
    local data = base64_decode(args.b64 or "")
    handle.write(data)
    handle.close()
    return { path = path, bytes = #data }
  end

  if op == "delete" then
    local path = clean_path(args.path or "")
    if path == "" then
      return nil, "invalid_path"
    end
    if not fs.exists(path) then
      return nil, "not_found"
    end
    fs.delete(path)
    return { path = path }
  end

  if op == "mkdir" then
    local path = clean_path(args.path or "")
    if path == "" then
      return nil, "invalid_path"
    end
    fs.makeDir(path)
    return { path = path }
  end

  if op == "run" then
    local path = clean_path(args.path or "")
    if path == "" then
      return nil, "invalid_path"
    end
    if not can_open_tab() then
      return nil, "multishell_not_available"
    end
    local argv = args.args or {}
    local tab = shell.openTab(path, unpack(argv))
    running[tab] = { path = path, args = argv, started = os.clock() }
    if args.focus and shell.switchTab then
      shell.switchTab(tab)
    end
    return { tab = tab, path = path }
  end

  if op == "stop" then
    local tab = tonumber(args.tab)
    if not tab then
      return nil, "missing_tab"
    end
    if not can_terminate_tab() then
      return nil, "terminate_not_supported"
    end
    terminate_tab(tab)
    running[tab] = nil
    return { tab = tab }
  end

  if op == "restart" then
    local tab = tonumber(args.tab)
    local path = clean_path(args.path or "")
    if tab and can_terminate_tab() then
      terminate_tab(tab)
      running[tab] = nil
    elseif tab and not can_terminate_tab() then
      return nil, "terminate_not_supported"
    end
    if path == "" and tab and running[tab] then
      path = running[tab].path
    end
    if path == "" then
      return nil, "missing_path"
    end
    if not can_open_tab() then
      return nil, "multishell_not_available"
    end
    local argv = args.args or (running[tab] and running[tab].args) or {}
    local new_tab = shell.openTab(path, unpack(argv))
    running[new_tab] = { path = path, args = argv, started = os.clock() }
    return { tab = new_tab, path = path }
  end

  if op == "list_tasks" then
    cleanup_running()
    local tasks = {}
    for tab, info in pairs(running) do
      local title = (multishell and multishell.getTitle and multishell.getTitle(tab)) or info.path
      tasks[#tasks + 1] = { tab = tab, path = info.path, title = title }
    end
    table.sort(tasks, function(a, b) return a.tab < b.tab end)
    return { tasks = tasks }
  end

  return nil, "unknown_op"
end

local function url_host(url)
  if not url then return "" end
  return url:match("^wss?://([^/]+)") or url
end

local function url_is_loopback(url)
  local host = url_host(url)
  host = host:match("^[^:]+") or host
  return host == "127.0.0.1" or host == "localhost"
end

local function try_connect_async(url, timeout)
  if not http.websocketAsync then
    return nil, "no_async"
  end
  local ok = pcall(function() http.websocketAsync(url) end)
  if not ok then
    return nil, "async_failed"
  end
  local timer = os.startTimer(timeout or 1)
  while true do
    local event, p1, p2 = os.pullEvent()
    if event == "websocket_success" and p1 == url then
      return p2, nil
    elseif event == "websocket_failure" and p1 == url then
      return nil, p2
    elseif event == "timer" and p1 == timer then
      return nil, "timeout"
    elseif event == "terminate" then
      error("Terminated")
    end
  end
end

local function try_connect(url, timeout, allow_blocking)
  local ok, ws_or_err, err_msg = pcall(function()
    if timeout then
      return http.websocket({ url = url, timeout = timeout })
    end
    return http.websocket(url)
  end)
  if ok and ws_or_err then
    return ws_or_err, nil
  end
  local first_err = ok and err_msg or ws_or_err
  if timeout then
    local ws_async, err_async = try_connect_async(url, timeout)
    if ws_async then
      return ws_async, nil
    end
    if not allow_blocking then
      return nil, err_async or first_err
    end
  end
  if allow_blocking then
    local ok2, ws_or_err2, err_msg2 = pcall(function() return http.websocket(url) end)
    if ok2 and ws_or_err2 then
      return ws_or_err2, nil
    end
    if not ok2 then
      return nil, ws_or_err2
    end
    if ok2 and err_msg2 then
      return nil, err_msg2
    end
  end
  return nil, first_err
end

local function read_last_url()
  local file = CONFIG.discovery and CONFIG.discovery.last_url_file
  if not file or not fs.exists(file) then return nil end
  local handle = fs.open(file, "r")
  if not handle then return nil end
  local url = handle.readAll()
  handle.close()
  if url and url ~= "" then
    return url
  end
  return nil
end

local function write_last_url(url)
  local file = CONFIG.discovery and CONFIG.discovery.last_url_file
  if not file then return end
  local handle = fs.open(file, "w")
  if not handle then return end
  handle.write(url or "")
  handle.close()
end

local function build_candidates()
  local cfg = CONFIG.discovery or {}
  local candidates = {}
  local port = cfg.port or 8765
  local path = cfg.path or "/cc"
  local host_min = cfg.host_min or 1
  local host_max = cfg.host_max or 254
  local subnets = cfg.subnets or {}
  for _, subnet in ipairs(subnets) do
    for host = host_min, host_max do
      candidates[#candidates + 1] = ("ws://" .. subnet .. tostring(host) .. ":" .. tostring(port) .. path)
    end
  end
  return candidates
end

local function discover_server()
  local cfg = CONFIG.discovery or {}
  if not cfg.enabled then return nil end
  local timeout = cfg.timeout or 0.6
  local candidates = build_candidates()
  if #candidates == 0 then
    return nil
  end
  log_line("Searching server in LAN...")
  for _, url in ipairs(candidates) do
    local ws_try = try_connect(url, timeout, false)
    if ws_try then
      log_line("Discovered server: " .. url)
      return ws_try, url
    end
  end
  return nil
end

local function connect()
  while true do
    maybe_acquire_monitor()
    local tried = {}
    if CONFIG.server_url and CONFIG.server_url ~= "" then
      if not (CONFIG.auto_discover and url_is_loopback(CONFIG.server_url)) then
        tried[#tried + 1] = CONFIG.server_url
      end
    end
    local last = read_last_url()
    if last and last ~= "" and last ~= CONFIG.server_url then
      if not (CONFIG.auto_discover and url_is_loopback(last)) then
        tried[#tried + 1] = last
      end
    end
    local connected = false
    for _, url in ipairs(tried) do
      log_line("Connecting to " .. url_host(url))
      local result, err = try_connect(url, 3, true)
      if result then
        ws = result
        CONFIG.server_url = url
        write_last_url(url)
        connected = true
        break
      end
      if err then
        log_line("Connection failed: " .. url_host(url) .. " (" .. tostring(err) .. ")")
      else
        log_line("Connection failed: " .. url_host(url))
      end
    end
    if not connected and CONFIG.auto_discover then
      local ws_found, url_found = discover_server()
      if ws_found then
        ws = ws_found
        CONFIG.server_url = url_found
        write_last_url(url_found)
        connected = true
      end
    end
    if connected then
      return true
    end
    log_line("No server found. Retrying in " .. tostring(CONFIG.reconnect_delay) .. "s")
    pause(CONFIG.reconnect_delay)
  end
end

local function send_hello()
  local label = CONFIG.client_name or os.getComputerLabel() or ("cc-" .. tostring(os.getComputerID()))
  send_message({
    type = "hello",
    data = {
      label = label,
      computer_id = os.getComputerID(),
      os_version = os.version(),
      multishell = multishell ~= nil,
      token = CONFIG.auth_token or "",
    }
  })
end

local function handle_message(raw)
  local ok, msg = pcall(json_decode, raw)
  if not ok or type(msg) ~= "table" then
    send_event("log", { message = "Invalid JSON from server" })
    return
  end
  if msg.type == "req" then
    local ok_req, data, err = pcall(handle_request, msg)
    if ok_req then
      if err then
        send_response(msg.id, false, nil, err)
      else
        send_response(msg.id, true, data)
      end
    else
      send_response(msg.id, false, nil, data)
    end
    return
  end

  if msg.type == "ping" then
    send_message({ type = "pong", time = os.clock() })
  end
end

local poll = (CONFIG.monitor and CONFIG.monitor.poll_interval) or 2
monitor_timer = os.startTimer(poll)
maybe_acquire_monitor()
log_line("CC Remote Agent started")

while true do
  connect()
  send_hello()
  log_line("Connected to " .. url_host(CONFIG.server_url))
  send_event("log", { message = "Connected to server" })

  while true do
    local event, p1, p2 = os.pullEvent()
    if event == "websocket_message" and p1 == CONFIG.server_url then
      handle_message(p2)
    elseif event == "websocket_closed" and p1 == CONFIG.server_url then
      log_line("Disconnected")
      ws = nil
      break
    elseif event == "timer" and p1 == monitor_timer then
      maybe_acquire_monitor()
      local poll = (CONFIG.monitor and CONFIG.monitor.poll_interval) or 2
      monitor_timer = os.startTimer(poll)
    elseif event == "peripheral_detach" and p1 == monitor_side then
      release_monitor()
      log_line("Monitor detached: " .. tostring(p1))
    elseif event == "terminate" then
      if ws then ws.close() end
      release_monitor()
      return
    end
  end

  pause(CONFIG.reconnect_delay)
end
