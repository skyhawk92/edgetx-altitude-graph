-- AvailableWidth = 128
-- LcdHeight = 64

local fakeData = {30, 31, 31, 31, 32, 32, 31, 31, 30, 30, 29, 28, 27, 26, 25, 25, 25, 25, 24, 25, 26, 27, 27, 25, 25, 23, 22, 21, 21, 21, 21, 20, 19, 19, 19, 18, 18, 18, 18, 17, 17, 15, 15, 14, 13, 12, 12, 12, 12, 13 ,12, 13, 12, 11, 10 ,9 ,9 ,9, 8, 7, 6, 6, 6, 5, 5, 5, 4, 3, 2, 1, 1, 1, 0 ,0 ,0}

TimeIncrement = 0
TimeColumn = nil
AltitudeColumn = nil
AltitudeData = {}

SelectorPosition = 100
SelectorPositionPage = 1

local function drawGraph()
  local x1, y1 = 20, 20
  local x2, y2 = 100, 50
  local x3, y3 = 50, 100

  lcd.drawLine(5,5,5,55,SOLID, 0)
  lcd.drawLine(5,55,125,55,SOLID, 0)
  lcd.drawText(0,0, '50(m)', SMLSIZE)
  lcd.drawText(105,58, '1min', SMLSIZE)
end

local function drawXsectors()
  local x=5
  for i=1,13 do
    lcd.drawLine(x,56,x,58,SOLID, 0)
    x = x + 10
  end
end

local function drawYsectors()
  local y=55
  for i=1,10 do
    lcd.drawLine(4,y,2,y,SOLID, 0)
    y = y - 5
  end
end

local function drawSelector()
  local selectedAltitudeValue = AltitudeData[SelectorPosition]

  -- Draws line with offset to the right
  lcd.drawLine(SelectorPosition + 6, 10, SelectorPosition + 6, 55, SOLID, 0) 

  if(SelectorPosition > 90) then
    lcd.drawText(SelectorPosition - 20, 10, selectedAltitudeValue .. "(m)", SMLSIZE)
  else
    lcd.drawText(SelectorPosition + 8, 10, selectedAltitudeValue .. '(m)', SMLSIZE)
  end
end

-- Function to split a string based on a delimiter
local function split(str)
  local result = {}
  local word = ""

  -- Iterate over each character in the string
    for i = 1, #str do
      -- local char = str:sub(i, i) -- Get the character at position i
      local char = string.sub(str, i, i)

      -- If the character is not a comma, add it to the current word
      if char ~= "," then
          word = word .. char
      else
          -- If it's a comma, add the current word to the result and reset the word variable
          result[#result + 1] = word
          word = ""
      end
    end   

  -- Add the last word to the result (since there's no comma after the last word)
  result[#result + 1] = word

  return result
end

-- Retrieves time increment, and altitude column
local function initialCSVread()
  local csv_table = {}
  local fileName = nil

  for fname in dir("/LOGS") do
      print(fname)
      fileName = "/LOGS/" .. fname
  end

  local file = io.open(fileName, 'r')

  local timeRef1string = ""
  local timeRef2string = ""
  local timeRef1 = 0
  local timeRef2 = 0

-- Read lines from the file
  local lineCount = 0
  while lineCount < 10 do
    local line = ""
    local char = io.read(file, 1)

    while char and char ~= "\n" do
        line = line .. char
        char = io.read(file, 1)
    end

    if line == "" then 
      break 
    end

    local splittedLine = split(line)
    lineCount = lineCount + 1

    -- Get time and altitude columns
    if lineCount == 1 then
      for key, value in pairs(splittedLine) do
        print(key, value)
        if value == "Time" then
          TimeColumn = key
        end
        if value == "Alt(m)" then
          AltitudeColumn = key
        end
      end
    end

    -- Get telemetry capture time interval
    if lineCount > 2 and lineCount < 5 then
      for key, value in pairs(splittedLine) do
        if key == TimeColumn and lineCount == 3 then
          timeRef1string = string.gsub(value, "%.", "") or value
          print(timeRef1string)
          timeRef1string = string.gsub(timeRef1string, "%:", "")
          print(value)
          timeRef1 = tonumber(timeRef1string)
        end

        if key == TimeColumn and lineCount == 4 then
          timeRef2string = string.gsub(value, "%:", "")
          timeRef2string = string.gsub(timeRef2string, "%.", "")
          timeRef2 = tonumber(timeRef2string)
        end
      end
    end
  end

  TimeIncrement = timeRef2 - timeRef1
  print("TIME INCREMENT IS: " .. TimeIncrement)

  if not file then
    print("Error: Could not open file " .. fileName)
    return nil
  end

  io.close(file)
  return 1
end

local function readCSValtitude()
  local fileName = nil

  for fname in dir("/LOGS") do
      print(fname)
      fileName = "/LOGS/" .. fname
  end

  local file = io.open(fileName, 'r')

  -- TODO Ignore first n lines when flight did not start yet
  local flightStarted = false 


-- Read lines from the file
  local altitudeDataIndex = 0
  local lineCount = 1
  while true do
    local line = ""
    local char = io.read(file, 1)

    while char and char ~= "\n" do
        line = line .. char
        char = io.read(file, 1)
    end

    if line == "" then 
      break 
    end

    local splittedLine = split(line)

    -- TODO Curently this reads first actual minute of flight
    if lineCount > 330 and lineCount < 600 then
      for key, value in pairs(splittedLine) do
        if key == AltitudeColumn then
          AltitudeData[altitudeDataIndex] = math.ceil(value)
        end
      end
      altitudeDataIndex = altitudeDataIndex + 1
    elseif lineCount >= 450 then
      break
    end

    lineCount = lineCount + 1
  end

  if not file then
    print("Error: Could not open file " .. fileName)
    return nil
  end

  io.close(file)
  return 1
end

-- TODO align time with x axis markers
local function drawFakeData()
  local timeXaxis = 6
  for i = 1, #fakeData do
    local height = fakeData[i]
    lcd.drawLine(timeXaxis,54,timeXaxis,(54 - height),SOLID, 0)
    timeXaxis = timeXaxis + 1
  end
end

local function drawAltitudeData()
  local timeXaxis = 6

  for i = 0, #AltitudeData do
    local height = AltitudeData[i]
    lcd.drawLine(timeXaxis,54,timeXaxis,(54 - height),SOLID, 0)
    timeXaxis = timeXaxis + 1
  end
end

local function init()
  -- init is called once when model is loaded
  print("Script init function executed")
  initialCSVread()
  readCSValtitude()
end
  
local function run(event, touchState)
  -- code to execute
  lcd.clear()
  drawGraph()
  drawXsectors()
  drawYsectors()
  drawAltitudeData()
  -- drawFakeData()
  drawSelector()

  if event ~= 0 then
    if event == EVT_ROT_RIGHT and SelectorPosition < 118 then
      SelectorPosition = SelectorPosition + 1
    end
    if event == EVT_ROT_LEFT and SelectorPosition > 0 then
      SelectorPosition = SelectorPosition - 1
    end
  end

  if event == EVT_EXIT_BREAK then
    return 1
  end
  return 0
end
  
return { run=run, init=init }