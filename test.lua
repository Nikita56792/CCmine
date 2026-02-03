local mon = peripheral.find("monitor")
if not mon then
  error("Монитор не найден. Подключи монитор (peripheral 'monitor') к компьютеру.")
end

-- Переключаем вывод на монитор
local nativeTerm = (term.current and term.current()) or term.native()
term.redirect(mon)

-- Пытаемся поставить самый мелкий масштаб текста для “больше пикселей”
pcall(function() mon.setTextScale(0.5) end)

-- Чистим экран
mon.setBackgroundColor(colors.black)
mon.clear()

local W, H = mon.getSize()

-- Размер блока (в “пикселях”-символах). Для 1x1 обычно хорошо 6..8.
local s = 6

-- Габариты изометрического блока:
-- ширина  = 3*s - 1
-- высота  = 2*s
local cubeW = 3 * s - 1
local cubeH = 2 * s

-- Центрирование
local x0 = math.floor((W - cubeW) / 2) + 1
local y0 = math.floor((H - cubeH) / 2) + 1

-- Рисование одного “пикселя” (ячейка символа) цветом фона
local function px(x, y, c)
  if x < 1 or y < 1 or x > W or y > H then return end
  mon.setCursorPos(x, y)
  mon.setBackgroundColor(c)
  mon.write(" ")
end

-- Небольшая “текстура” через псевдо-шум (без math.random, чтобы было стабильно)
local function noise(x, y, m)
  return (x * 17 + y * 31) % m
end

-- Цвета “травы”
local function grassColor(x, y)
  local k = noise(x, y, 11)
  if k == 0 then return colors.yellow end
  if k < 4 then return colors.lime end
  return colors.green
end

-- Цвета “земли” (левая грань)
local function dirtLeftColor(x, y)
  local k = (x * 19 + y * 23) % 10
  if k == 0 then return colors.orange end
  if k < 3 then return colors.red end
  return colors.brown
end

-- Цвета “земли” (правая грань чуть темнее/иначе)
local function dirtRightColor(x, y)
  local k = (x * 29 + y * 11) % 10
  if k == 0 then return colors.orange end
  if k < 4 then return colors.brown end
  return colors.red
end

-- Верхняя грань (параллелограмм): высота s, ширина 2*s, сдвиг влево по 1 на строку вниз
for r = 0, s - 1 do
  local sy = y0 + r
  local sx = x0 + (s - 1 - r)
  for dx = 0, 2 * s - 1 do
    px(sx + dx, sy, grassColor(sx + dx, sy))
  end
end

-- Боковые грани: высота s
-- Левая грань шириной s, уходит вправо по 1 каждый ряд
-- Правая грань шириной s, начинается с середины и тоже уходит вправо
for r = 0, s - 1 do
  local sy = y0 + s + r

  -- Левая грань
  local lx = x0 + r
  for dx = 0, s - 1 do
    local c
    -- первые 2 ряда боковины делаем “травяной кромкой”
    if r < 2 then
      c = grassColor(lx + dx, sy)
    else
      c = dirtLeftColor(lx + dx, sy)
    end
    px(lx + dx, sy, c)
  end

  -- Правая грань
  local rx = x0 + s + r
  for dx = 0, s - 1 do
    local c
    if r < 2 then
      c = grassColor(rx + dx, sy)
    else
      c = dirtRightColor(rx + dx, sy)
    end
    px(rx + dx, sy, c)
  end
end

-- Возвращаем вывод обратно в терминал компьютера
term.redirect(nativeTerm)
