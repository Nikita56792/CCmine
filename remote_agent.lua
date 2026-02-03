-- CC Remote Agent for ComputerCraft/CC:Tweaked (advanced computer)
-- Connects to a websocket server and allows remote file operations and program launch.

local CONFIG = {
  -- Example: "ws://192.168.0.10:8765/cc"
  server_url = "ws://127.0.0.1:8765/cc",
  reconnect_delay = 3,
  auth_token = "", -- optional shared token
  client_name = nil, -- optional name override
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

local function connect()
  while true do
    local ok, result = pcall(function()
      return http.websocket(CONFIG.server_url)
    end)
    if ok and result then
      ws = result
      return true
    end
    print("Failed to connect. Retrying in " .. tostring(CONFIG.reconnect_delay) .. "s")
    sleep(CONFIG.reconnect_delay)
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

while true do
  connect()
  send_hello()
  send_event("log", { message = "Connected to server" })

  while true do
    local event, url, message = os.pullEvent()
    if event == "websocket_message" and url == CONFIG.server_url then
      handle_message(message)
    elseif event == "websocket_closed" and url == CONFIG.server_url then
      print("Disconnected")
      ws = nil
      break
    elseif event == "terminate" then
      if ws then ws.close() end
      return
    end
  end

  sleep(CONFIG.reconnect_delay)
end
