-- display.lua

local text = "Hey"   -- <-- тут поменяй надпись

-- Найти подключенный монитор
local mon = peripheral.find("monitor")
if not mon then
  error("Монитор не найден. Подключи monitor как peripheral.")
end

-- Для 1x1 обычно лучше мелкий масштаб, чтобы влезало больше символов
mon.setTextScale(0.5)

-- Очистка и оформление (можно убрать, если не нужно)
mon.setBackgroundColor(colors.black)
mon.setTextColor(colors.white)
mon.clear()

-- Размер экрана монитора в символах
local w, h = mon.getSize()

-- Центрирование текста
local x = math.floor((w - #text) / 2) + 1
local y = math.floor(h / 2)

mon.setCursorPos(x, y)
mon.write(text)
