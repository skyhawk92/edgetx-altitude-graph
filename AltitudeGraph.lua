-- AvailableWidth = 128
-- LcdHeight = 64

LogDirectory = "/LOGS"
SelectedLogFilename = ""
LogFiles = {}
SelectedFileDisplayIndex = 0
DisplayFileNameIndexFrom = 0
DisplayFileNameIndexTo = 4

TimeIncrement = 0
TimeColumn = nil
AltitudeColumn = nil
AltitudeData = {}

SelectorPosition = 100
CurrentPage = 1
AllPages = 1
MaxHeight = 50

local function logSelector()
  
end


local function drawGraph()
  local x1, y1 = 20, 20
  local x2, y2 = 100, 50
  local x3, y3 = 50, 100

  lcd.drawLine(5,5,5,55,SOLID, 0)
  lcd.drawLine(5,55,125,55,SOLID, 0)
  lcd.drawText(0,1, MaxHeight .. '(m)', SMLSIZE)
end

local function drawXsectors()
  local x=5
  for i=1,13 do
    lcd.drawLine(x,56,x,56,SOLID, 0)
    x = x + 10
  end
end

local function drawYsectors()
  local y=55
  for i=1,10 do
    lcd.drawLine(4,y,4,y,SOLID, 0)
    y = y - 5
  end
end

local function drawSelector()
  lcd.drawText(82, 1, "Page " .. CurrentPage .. "/" .. AllPages, SMLSIZE)
  local selectedAltidudeValuePosition = SelectorPosition + (CurrentPage - 1)*120
  local selectedAltitudeValue = AltitudeData[selectedAltidudeValuePosition]

  -- Draws line with offset to the right
  lcd.drawLine(SelectorPosition + 6, 10, SelectorPosition + 6, 55, SOLID, 0) 

  if selectedAltitudeValue == nil then
    selectedAltitudeValue = 0
  end

  if(SelectorPosition > 90) then
    lcd.drawText(SelectorPosition - 20, 10, selectedAltitudeValue .. "(m)", SMLSIZE)
  else
    lcd.drawText(SelectorPosition + 8, 10, selectedAltitudeValue .. '(m)', SMLSIZE)
  end

  local allSeconds = (selectedAltidudeValuePosition * TimeIncrement) / 1000
  local minutes = math.floor(allSeconds / 60)
  local seconds = math.floor((allSeconds % 60) + 0.5)
  if(SelectorPosition > 90) then
    lcd.drawText(SelectorPosition - 20, 58, minutes .. "m" .. seconds .. "s", SMLSIZE)
  else
    lcd.drawText(SelectorPosition + 8, 58, minutes .. 'm' .. seconds .. "s", SMLSIZE)
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
local function initialCSVread(fileName)
  local csv_table = {}

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

  TimeIncrement = timeRef2 - timeRef1 --Time increment is in miliseconds
  --print("TIME INCREMENT IS: " .. TimeIncrement)

  if not file then
    print("Error: Could not open file " .. fileName)
    return nil
  end

  io.close(file)
end

local function readCSValtitude(fileName)
  local file = io.open(fileName, 'r')

  -- TODO Possibly ignore first n lines when flight did not start yet
  local flightStarted = false 

-- Read lines from the file
  local altitudeDataIndex = 0
  local lineCount = 1
  local allLinesRead = false

  while not allLinesRead do
    local line = ""
    local char = io.read(file, 1)
    
    while char and char ~= "\n" do
      line = line .. char
      if line == "" then 
        allLinesRead = true
        break
      end
      char = io.read(file, 1)
    end

    if lineCount > 1 and not allLinesRead then
      local splittedLine = split(line)

      for key, value in pairs(splittedLine) do
        if key == AltitudeColumn then
          AltitudeData[altitudeDataIndex] = math.ceil(value)
        end
      end
      altitudeDataIndex = altitudeDataIndex + 1
    end

    lineCount = lineCount + 1
  end

  if not file then
    print("Error: Could not open file " .. fileName)
    return nil
  end

  io.close(file)

  AllPages = math.ceil((altitudeDataIndex - 1)/120 + 1)
  LogFileRead = true
end

local function drawAltitudeData()
  local timeXaxis = 6
  local dataPageOffset = (CurrentPage - 1) * 120 
  local dataTo = #AltitudeData

  if((CurrentPage * 120) < #AltitudeData) then
    dataTo = (CurrentPage * 120)
  end

  --TODO Account for different timeIncrement options here(1s, 0,25s etc...)

  local heightDivider = 1
  local tmpMaxHeight = 0

  for i = (0 + dataPageOffset), dataTo do
    local height = AltitudeData[i]
    if height > tmpMaxHeight then
      tmpMaxHeight = height
    end
  end

  if tmpMaxHeight > 50 then
    MaxHeight = 100
    heightDivider = 2
  elseif tmpMaxHeight > 100 then
    MaxHeight = 150
    heightDivider = 3
  else 
    MaxHeight = 50
    heightDivider = 1
  end

  --for i = 0, #AltitudeData do
  for i = (0 + dataPageOffset), dataTo do
    local height = math.ceil(AltitudeData[i]/heightDivider)
    lcd.drawLine(timeXaxis,54,timeXaxis,(54 - height),SOLID, 0)
    timeXaxis = timeXaxis + 1
  end
end

-- init is called once when model is loaded
local function init()
  print("Script init function executed")
  lcd.clear()

  local fileNameIndex = 0
  for fname in dir(LogDirectory) do
    LogFiles[fileNameIndex] = fname
    fileNameIndex = fileNameIndex + 1
  end
end
  
local function run(event, touchState)
  lcd.clear()

  if SelectedLogFilename == "" then
    lcd.drawText(28,1, 'SELECT LOG FILE', SMLSIZE)
    lcd.drawLine(0, 10, 128, 10, SOLID, 0)

    local rowSpacing = 13

    for i = DisplayFileNameIndexFrom, DisplayFileNameIndexTo do
      if i < #LogFiles then
        lcd.drawText(0,rowSpacing, LogFiles[i], SMLSIZE)
        rowSpacing = rowSpacing + 10
      end
    end

    lcd.drawFilledRectangle(0,(SelectedFileDisplayIndex+1) * 10, 128, 11, 0)

    if event ~= 0 then
      if event == EVT_ROT_RIGHT and SelectedFileDisplayIndex <= DisplayFileNameIndexTo then
        SelectedFileDisplayIndex = SelectedFileDisplayIndex + 1

       if SelectedFileDisplayIndex > DisplayFileNameIndexTo then
        SelectedFileDisplayIndex = 0
        DisplayFileNameIndexFrom = DisplayFileNameIndexFrom + 5
        DisplayFileNameIndexTo = DisplayFileNameIndexTo + 5
       end
      end

      if event == EVT_ROT_LEFT and SelectedFileDisplayIndex >= 0 then
        SelectedFileDisplayIndex = SelectedFileDisplayIndex - 1
        if DisplayFileNameIndexFrom > 0 and SelectedFileDisplayIndex < 0 then
          SelectedFileDisplayIndex = 4
          DisplayFileNameIndexFrom = DisplayFileNameIndexFrom - 5
          DisplayFileNameIndexTo = DisplayFileNameIndexTo - 5
        elseif DisplayFileNameIndexFrom == 0 and SelectedFileDisplayIndex < 0 then
          SelectedFileDisplayIndex = 0  
        end
      end

      if event == EVT_ROT_BREAK then
        lcd.clear()
        lcd.drawText(25,25, 'LOADING LOG FILE', SMLSIZE)
        SelectedLogFilename = LogDirectory .. "/" .. LogFiles[SelectedFileDisplayIndex]
      end
    end

    return 0
  else
    if not LogFileRead then
      initialCSVread(SelectedLogFilename)
      readCSValtitude(SelectedLogFilename)
    else
      drawGraph()
      drawXsectors()
      drawYsectors()
      drawAltitudeData()
      drawSelector()

      if event ~= 0 then
        if event == EVT_ROT_RIGHT and SelectorPosition < 118 then
          SelectorPosition = SelectorPosition + 1
        elseif SelectorPosition == 118 and CurrentPage < AllPages then
          CurrentPage = CurrentPage + 1
          SelectorPosition = 1
        end

        if event == EVT_ROT_LEFT and SelectorPosition > 0 then
          SelectorPosition = SelectorPosition - 1
        elseif SelectorPosition == 0 and CurrentPage > 1 then
          CurrentPage = CurrentPage - 1
          SelectorPosition = 117
        end

        if event == EVT_VIRTUAL_NEXT_PAGE and CurrentPage < AllPages then
          CurrentPage = CurrentPage + 1
        end

        if event == EVT_VIRTUAL_PREV_PAGE and CurrentPage > 1 then
          CurrentPage = CurrentPage - 1
        end
      end
    end

    if event == EVT_EXIT_BREAK then
      return 1
    end

    return 0
  end
end
return { run=run, init=init }