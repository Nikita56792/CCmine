----------------------СТАРТОВЫЕ ПРЕЛЕССССТИ-------------------------
 
local XSize, YSize = term.getSize()
local Selector = 1
local zaderzhka = 0.1
local progressBarWidth = 20
local ColorGray = colors.gray
local ColorLightGray = colors.lightGray
local ColorDownloadBack = colors.gray
local ColorDownloadFront = colors.lightGray
 
-----------СМЕНА ЦВЕТОВОЙ ПАЛИТРЫ, ЕСЛИ МОНИТОР ЧЕРНО-БЕЛЫЙ---------
 
if not term.isColor() then
    ColorGray = colors.black
    ColorLightGray = colors.black
    ColorDownloadBack = colors.white
    ColorDownloadFront = colors.black
end
 
-----------МАССИВ СО ДАННЫМИ О КАЖДОЙ ПРОГРАММЕ НА ПАСТЕБИНЕ--------
 
local Data = {
    --АПИ
    {["paste"]="vjs77QA6",["path"]="System/API/cluster",["type"]="API",["category"]="APIs"},
    {["paste"]="LAKBDeQt",["path"]="System/API/zip",["type"]="API",["category"]="APIs"},
    {["paste"]="TRUJgUme",["path"]="System/API/context",["type"]="API",["category"]="APIs"},
    {["paste"]="Z2kWNQaJ",["path"]="System/API/config",["type"]="API",["category"]="APIs"},
    {["paste"]="6gTj9LxN",["path"]="System/API/image",["type"]="API",["category"]="APIs"},
    {["paste"]="JPYBYVTd",["path"]="System/API/filemanager",["type"]="API",["category"]="APIs"},
    {["paste"]="D1QiSj9L",["path"]="System/API/windows",["type"]="API",["category"]="APIs"},
    {["paste"]="2M3z7Ycf",["path"]="System/API/xml",["type"]="API",["category"]="APIs"},
    {["paste"]="kWNeNPn5",["path"]="System/API/encryptor.cfg",["type"]="API",["category"]="APIs"},
    {["paste"]="CpTj9QHL",["path"]="System/API/encryptor",["type"]="API",["category"]="APIs"},
    {["paste"]="ApGP6e6x",["path"]="System/API/syntax",["type"]="API",["category"]="APIs"},
    --СИСТЕМА
    {["paste"]="1KJcUxPU",["path"]="OS",["type"]="other",["category"]="OS"},
    {["paste"]="HQ5zT3vG",["path"]="System/OS/Icons/default.png",["type"]="other",["category"]="OS"},
    {["paste"]="Be0DWVWX",["path"]="System/OS/Icons/folder.png",["type"]="other",["category"]="OS"},
    {["paste"]="90rS8nxX",["path"]="System/OS/Icons/image.png",["type"]="other",["category"]="OS"},
    {["paste"]="EupZQv59",["path"]="System/OS/Icons/config.png",["type"]="other",["category"]="OS"},
    {["paste"]="PhCccHT4",["path"]="System/OS/Icons/os.png",["type"]="other",["category"]="OS"},
    {["paste"]="eWMNUsb6",["path"]="System/OS/Icons/zip.png",["type"]="other",["category"]="OS"},
    {["paste"]="0rMSM2x2",["path"]="System/OS/Icons/disk.png",["type"]="other",["category"]="OS"},
    --ДОПОЛНЕНИЯ К ПРИЛОЖЕНИЯМ
    {["paste"]="J4tPebM0",["path"]="System/MineCode/logo.png",["type"]="other",["category"]="MineCode IDE"},
    {["paste"]="kAjvzgRN",["path"]="System/MineCode/syntax_colors.cfg",["type"]="other",["category"]="MineCode IDE"},
    {["paste"]="yT9eRQu9",["path"]="System/Photoshop/pslogo.png",["type"]="other",["category"]="Photoshop"},
    --ОБЫЧНЫЕ ПРИЛОЖЕНИЯ
    {["paste"]="qDczAPkV",["path"]="Applications/Cobblestone",["type"]="other",["category"]="applications"},
    {["paste"]="dkvshvvL",["path"]="Applications/RednetSpy",["type"]="other",["category"]="applications"},
    --{["paste"]="hUVMQFGU",["path"]="Applications/RednetSend",["type"]="other",["category"]="applications"},
    --{["paste"]="QqpHrszL",["path"]="Applications/View",["type"]="other",["category"]="applications"},
    {["paste"]="x824frsu",["path"]="Applications/Transfer",["type"]="other",["category"]="applications"},
    {["paste"]="pMSt4K2K",["path"]="Applications/Reactor",["type"]="other",["category"]="applications"},
    {["paste"]="W7ucXtTm",["path"]="Applications/Mine",["type"]="other",["category"]="applications"},
    {["paste"]="Sexqhkdq",["path"]="Applications/Grief",["type"]="other",["category"]="applications"},
    {["paste"]="Bsv3iBiN",["path"]="Applications/CBPaint",["type"]="other",["category"]="applications"},
    {["paste"]="HJg7u7ui",["path"]="Applications/Calibrate",["type"]="other",["category"]="applications"},
    {["paste"]="Xn8THcUC",["path"]="Applications/About",["type"]="other",["category"]="applications"},
    --{["paste"]="uQCTsyd6",["path"]="Applications/MenuDemo1",["type"]="other",["category"]="applications"},
    --{["paste"]="8PL6sQf7",["path"]="Applications/MenuDemo2",["type"]="other",["category"]="applications"},
    --{["paste"]="g0VdnK3X",["path"]="Applications/FileDemo",["type"]="other",["category"]="applications"},
    --НОВЫЕ СУПЕР-ХИТРОЖОПЫЕ ПРИЛОЖЕНИЯ
 
 
    {["paste"]="iDuJCAPS",["icon"]="LVeGQ7pU",["path"]="AirDrop",["type"]="Application",["category"]="applications"},
    {["paste"]="sXj77Y2B",["icon"]="764jWGZX",["path"]="NewsTicker",["type"]="Application",["category"]="applications"},
    {["paste"]="sfY8Hwwb",["icon"]="rc2sddVB",["path"]="Pastebin",["type"]="Application",["category"]="applications"},
    {["paste"]="gt9f7EfZ",["icon"]="sj5uhGUz",["path"]="BSOD",["type"]="Application",["category"]="applications"},
    {["paste"]="D8hSLB2L",["icon"]="DZjpMD68",["path"]="CodeDoor",["type"]="Application",["category"]="applications"},
    {["paste"]="4nFps3sF",["icon"]="PA9HFXnX",["path"]="MineCode",["type"]="Application",["category"]="applications"},
    {["paste"]="CBvTqxRj",["icon"]="hm1jMLhc",["path"]="Photoshop",["type"]="Application",["category"]="applications"},
    {["paste"]="hHum7Qqb",["icon"]="mMhJSh7x",["path"]="Graph",["type"]="Application",["category"]="applications"},
}
 
----------------------ОБЪЯВЛЕНИЕ ФУНКЦИЙ-----------------------
 
--ЗАГРУЗКА ФАЙЛОВ С ПАСТЕБИНА
local function pastebin(paste,path)
        local file = http.get("http://pastebin.com/raw.php?i="..paste)
    if file then
            file = file.readAll()
            h=fs.open(path,"w")
            h.write(file)
            h.close()
    else
        error("Pastebin server is not aviable.")
    end
end
 
--ЗАГРУЗИТЬ КОНКРЕТНОЕ ПРИЛОЖЕНИЕ
local function downloadApp(pasteApp,pasteIcon,path)
    fs.delete(path..".app")
    pastebin(pasteApp,path..".app/main")
    pastebin(pasteIcon,path..".app/Resources/icon.png")
end
 
--ПРОСТАЯ ЗАЛИВКА ЭКРАНА ЦВЕТОМ
local function clearScreen(color)
    term.setBackgroundColor(color)
    term.clear()
end
 
--ПЛАВНОЕ ВКЛЮЧЕНИЕ ЭКРАНА
local function fadeIn(time)
    clearScreen(ColorGray)
    sleep(time)
    clearScreen(ColorLightGray)
    sleep(time)
    clearScreen(colors.white)
    sleep(time)
end
 
--ПЛАВНОЕ ЗАТУХАНИЕ ЭКРАНА
local function fadeOut(time)
    clearScreen(ColorLightGray)
    sleep(time)
    clearScreen(ColorGray)
    sleep(time)
    clearScreen(colors.black)
    sleep(time)
    term.setCursorPos(1,1)
    term.setTextColor(colors.white)
end
 
--УНИВЕРСАЛЬНАЯ ФУНКЦИЯ ДЛЯ ОТОБРАЖЕНИЯ ТЕКСТА ПО ЦЕНТРУ ЭКРАНА
local function centerText(how,coord,text,textColor,backColor)
    term.setTextColor(textColor)
    term.setBackgroundColor(backColor)
    if how == "xy" then
        term.setCursorPos(math.floor(XSize/2-#text/2),math.floor(YSize/2))
    elseif how == "x" then
        term.setCursorPos(math.floor(XSize/2-#text/2),coord)
    elseif how == "y" then
        term.setCursorPos(coord,math.floor(YSize/2))
    end
    term.write(text)
end
 
--НАРИСОВАТЬ ГОРЗОНТАЛЬНУЮ ЛИНИЮ УКАЗАННОЙ ДЛИНЫ И ЦВЕТА
local function horisontalBar(x,y,width,color)
    for i=x,(x+width-1) do
        paintutils.drawPixel(i,y,color)
    end
end
 
--ОТОБРАЖЕНИЕ ШКАЛЫ ЗАГРУЗКИ С ПРОГРЕССОМ В ПРОЦЕНТАХ
local function progressBar(size,action,percent)
    local doneSize = math.ceil(percent/100*size)
    local startingY = math.floor(YSize/2-1)
    local startingX = math.floor(XSize/2-size/2)
    horisontalBar(1,startingY,XSize,colors.white)
    centerText("x",startingY,"Installing "..action,ColorGray,colors.white)
    horisontalBar(startingX,startingY+2,size,ColorDownloadBack)
    horisontalBar(startingX,startingY+2,doneSize,ColorDownloadFront)
    sleep(zaderzhka)
end
 
--ЗАГРУЗИТЬ ВСЕ ФАЙЛЫ С ПАСТЕБИНА
local function downloadAll()
    clearScreen(colors.white)
    progressBar(progressBarWidth,"started",0)
 
    fs.makeDir("Applications")
    fs.makeDir("System")
    --fs.makeDir("Documents")
    --fs.makeDir("Images")
    --fs.makeDir("Documents/MineCode")
 
    local oneFileIsHowMuchPercent = 1/#Data*100
 
    for i=1,#Data do
        if Data[i]["type"] == "Application" then
            downloadApp(Data[i]["paste"],Data[i]["icon"],Data[i]["path"])
        else
            pastebin(Data[i]["paste"],Data[i]["path"])
        end
        progressBar(progressBarWidth,Data[i]["category"],i*oneFileIsHowMuchPercent)
    end
 
    clearScreen(colors.white)
    centerText("x",math.floor(YSize/2),"Done.",ColorLightGray,colors.white)
    os.pullEvent("key")
end
 
--ЗАГРУЗИТЬ ВСЕ АПИ
local function downloadAPIs()
    for i=1,#Data do
        if Data[i]["type"] == "API" then
            pastebin(Data[i]["paste"],Data[i]["path"])
        end
    end
end
 
--УДАЛИТЬ ВСЕ МОИ ФАЙЛЫ
local function deleteOld()
    fs.delete("Applications")
    fs.delete("Documents")
    fs.delete("Images")
    fs.delete("System")
    fs.delete("OS")
    fs.delete("MineCode")
    fs.delete("startup")
    fs.delete("Startup")
end
 
--УДАЛИТЬ ВООБЩЕ ВСЕ ФАЙЛЫ
local function deleteAll()
    local fileList = fs.list("")
    for i=1,#fileList do
        if not fs.isReadOnly(fileList[i]) then
            fs.delete(fileList[i])
        end
    end
end
 
--НАРИСОВАТЬ СЕЛЕКТОР ДЛЯ ВЫБОРА ПРИ СТАРТЕ ПРОГРАММЫ
local function drawSelection(y,text,id)
    if id == Selector then
        horisontalBar(math.floor(XSize/2-8),y,16,ColorLightGray)
        centerText("x",y,text,colors.white,ColorLightGray)
    else
        horisontalBar(math.floor(XSize/2-8),y,16,colors.white)
        centerText("x",y,text,ColorLightGray,colors.white)
    end
end
 
--ОТОБРАЖЕНИЕ СТАРТОВОГО ИНТЕРФЕЙСА
local function gui()
    local startingY = math.floor(YSize/2-2)
    centerText("x",startingY,"Welcome to ECS installer",ColorGray,colors.white)
 
    drawSelection(startingY+2,"Install OS",1)
    drawSelection(startingY+3,"Clear computer",2)
    drawSelection(startingY+4,"Download API",3)
    drawSelection(startingY+5,"Exit",4)
end
 
-----------------------СТАРТ ПРОГРАММЫ-----------------------
 
fadeIn(0)
gui()
 
while true do
    --ОТСЛЕЖИВАНИЕ КЛАВИШ СТРЕЛОК И ENTER
    local event, scancode = os.pullEvent("key")
    --ПЕРЕМЕСТИТЬСЯ ВЫШЕ
    if scancode == 200 then
        Selector = Selector-1
        if Selector<1 then Selector=1 end
        gui()
    --ПЕРЕМЕСТИТЬСЯ НИЖЕ
    elseif scancode == 208 then
        Selector = Selector+1
        if Selector>4 then Selector=4 end
        gui()
    --СКАЧАТЬ ВСЕ С ПАСТЕБИНА
    elseif scancode == 28 and Selector == 1 then
        --deleteOld()
        downloadAll()
        break
    --ОЧИСТИТЬ КОМП ОТ МОЕГО ГОВНА
    elseif scancode == 28 and Selector == 2 then
        deleteAll()
        clearScreen(colors.white)
        centerText("x",math.floor(YSize/2),"Filesystem was cleared.",ColorLightGray,colors.white)
        local event, scancode = os.pullEvent("key")
        fadeOut(0)
        os.reboot()
        break
    --СКАЧАТЬ ТОЛЬКО АПИ С ПАСТЕБИНА
    elseif scancode == 28 and Selector == 3 then
        fs.delete("System/API")
        clearScreen(colors.white)
        centerText("x",math.floor(YSize/2),"Downloading APIs",ColorLightGray,colors.white)
 
        --[[for i=1,11 do
            pastebin(Data[i]["paste"],Data[i]["path"])
        end]]
        downloadAPIs()
 
        clearScreen(colors.white)
        centerText("x",math.floor(YSize/2),"APIs installed in /System/API",ColorLightGray,colors.white)
        local event, scancode = os.pullEvent("key")
        break
    --ВЫЙТИ ИЗ ПРОГРАММЫ
    elseif scancode == 28 and Selector == 4 then
        break
    end
end
 
fadeOut(0)
term.setCursorPos(1,1)
