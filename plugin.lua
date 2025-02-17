-- LazyMapper v1.0 (updated 15 Mar 2021)
-- created by kloi34
---------------------------------------------------------------------------------------------------

-- Creates the plugin window
function draw()
    applyStyle()
    svMenu()
end

---------------------------------------------------------------------------------------------------
-- Global constants
---------------------------------------------------------------------------------------------------

SAMELINE_SPACING = 5                   -- value determining spacing between GUI items on the same row
DEFAULT_WIDGET_HEIGHT = 26             -- value determining the height of GUI widgets
DEFAULT_WIDGET_WIDTH = 150             -- value determining the width of GUI widgets
DEFAULT_BEAT_SNAPS = { 2, 3, 4, 6, 8 } -- common beat snap values

---------------------------------------------------------------------------------------------------
-- Menus and Tabs
---------------------------------------------------------------------------------------------------

function svMenu()
    imgui.Begin("LazyMapper", imgui_window_flags.AlwaysAutoResize)
    state.IsWindowHovered = imgui.IsWindowHovered()
    imgui.BeginTabBar("function_selection")
    basic()
    advanced()
    imgui.End()
end

function basic()
    if imgui.BeginTabItem("Basic") then
        local menuID = "basic"
        local vars = {
            randomPlacement = 0,
            keyMode = 4,
            beatSnap = 2,
            patternLength = 4,
            rows = 64,
            notesInRow = { 3, 2, 2, 2, 0, 0, 0, 0 }
        }
        retrieveStateVariables(menuID, vars)
        vars.keyMode = getKeyMode()

        section("Place notes in...", true)
        _, vars.randomPlacement = imgui.RadioButton("Random columns", vars.randomPlacement, 0)
        _, vars.randomPlacement = imgui.RadioButton("Random, but different columns each row", vars.randomPlacement, 1)
        _, vars.randomPlacement = imgui.RadioButton("Random, better", vars.randomPlacement, 2)
        spacing()

        section("Beat snap")
        for i = 1, #DEFAULT_BEAT_SNAPS do
            _, vars.beatSnap = imgui.RadioButton("1/" .. DEFAULT_BEAT_SNAPS[i], vars.beatSnap, DEFAULT_BEAT_SNAPS[i])
            if (i ~= #DEFAULT_BEAT_SNAPS) then
                imgui.SameLine(0, SAMELINE_SPACING)
            end
        end
        separator()
        spacing()

        imgui.PushItemWidth(DEFAULT_WIDGET_WIDTH)
        _, vars.rows = imgui.InputInt("Rows", vars.rows)
        vars.rows = mathClamp(vars.rows, 1, 5000)

        _, vars.patternLength = imgui.InputInt("Pattern Length", vars.patternLength)
        vars.patternLength = mathClamp(vars.patternLength, 1, 8)


        section("Notes in...")
        for i = 1, vars.patternLength do
            _, vars.notesInRow[i] = imgui.DragInt("Row " .. i, vars.notesInRow[i], 0.03, 0, vars.keyMode)
            vars.notesInRow[i] = mathClamp(vars.notesInRow[i], 0, vars.keyMode)
        end
        imgui.PopItemWidth()

        separator()
        spacing()

        if imgui.Button("Place Notes At Current Time") then
            local notes = {}
            if vars.randomPlacement == 0 then
                notes = generateRandomNotes(vars.keyMode, vars.beatSnap, vars.patternLength, vars.rows, vars.notesInRow)
            elseif vars.randomPlacement == 1 then
                notes = generateSemiRandomNotes(vars.keyMode, vars.beatSnap, vars.patternLength, vars.rows,
                    vars.notesInRow)
            else
                notes = generateBetterRandomNotes(vars.keyMode, vars.beatSnap, vars.patternLength, vars.rows,
                    vars.notesInRow)
            end
            actions.PlaceHitObjectBatch(notes)
        end
        saveStateVariables(menuID, vars)
        imgui.endTabItem()
    end
end

function advanced()
    if imgui.BeginTabItem("Advanced") then
        local menuID = "advanced"
        local vars = {
            notesInRow = {}
        }
        retrieveStateVariables(menuID, vars)

        saveStateVariables(menuID, vars)
        imgui.endTabItem()
    end
end

---------------------------------------------------------------------------------------------------
-- Calculation/helper functions
---------------------------------------------------------------------------------------------------

-- Retrieves variables from the state
-- Parameters
--    menuID    : name of the tab menu that the variables are from (String)
--    variables : table that contains variables and values (Table)
function retrieveStateVariables(menuID, variables)
    for key, value in pairs(variables) do
        variables[key] = state.GetValue(menuID .. key) or value
    end
end

-- Saves variables to the state
-- Parameters
--    menuID    : name of the tab menu that the variables are from (String)
--    variables : table that contains variables and values (Table)
function saveStateVariables(menuID, variables)
    for key, value in pairs(variables) do
        state.SetValue(menuID .. key, value)
    end
end

-- Restricts a number to be within a closed interval
-- Parameters
--    number     : the number to keep within the interval
--    lowerBound : the lower bound of the interval
--    upperBound : the upper bound of the interval
function mathClamp(number, lowerBound, upperBound)
    if (number < lowerBound) then
        return lowerBound
    elseif (number > upperBound) then
        return upperBound
    else
        return number
    end
end

-- Returns a random set of unique integers of a set size within a given interval
-- Parameters
--    min     : minimum integer of the interval
--    max     : maximum integer of the interval
--    size    : size of the set of integers
--    exclude : numbers to exclude if possible
--    excludeAll : whether to exclude all numbers on the list or not
function randomSetOfUniqueInts(min, max, size, exclude, excludeAll)
    local ints = {}
    local totalNumsAvailable = max - min + 1
    if (totalNumsAvailable >= size) then
        for i = min, max do
            table.insert(ints, i)
        end
        if (totalNumsAvailable - #exclude < size) then
            for j = #exclude, (totalNumsAvailable - size + 1), -1 do
                table.remove(exclude, math.random(1, j))
            end
        end
        if excludeAll then
            for i = #exclude, 1, -1 do
                table.remove(ints, exclude[i])
            end
        end
        totalNums = #ints
        for i = totalNums, size + 1, -1 do
            table.remove(ints, math.random(1, i))
        end
    end
    return ints
end

function generateRandomNotes(keyMode, beatSnap, patternLength, rows, notesInRow)
    local notes = {}
    local time = state.SongTime
    for i = 1, rows do
        columns = randomSetOfUniqueInts(1, keyMode, notesInRow[(i - 1) % patternLength + 1], {}, false)
        for j = 1, #columns do
            table.insert(notes, utils.CreateHitObject(math.floor(time + 0.5), columns[j]))
        end
        time = time + 60000 / map.GetTimingPointAt(time).Bpm / beatSnap
    end
    return notes
end

function generateSemiRandomNotes(keyMode, beatSnap, patternLength, rows, notesInRow)
    local notes = {}
    local oldColumns = {}
    local time = state.SongTime
    for i = 1, rows do
        newColumns = randomSetOfUniqueInts(1, keyMode, notesInRow[(i - 1) % patternLength + 1], oldColumns, true)
        oldColumns = newColumns
        for j = 1, #newColumns do
            table.insert(notes, utils.CreateHitObject(math.floor(time + 0.5), newColumns[j]))
        end
        time = time + 60000 / map.GetTimingPointAt(time).Bpm / beatSnap
    end
    return notes
end

function generateBetterRandomNotes(keyMode, beatSnap, patternLength, rows, notesInRow)
    local notes = {}
    local oldColumns = {}
    local better = true
    local time = state.SongTime
    for i = 1, rows do
        newColumns = randomSetOfUniqueInts(1, keyMode, notesInRow[(i - 1) % patternLength + 1], oldColumns, better)

        if #newColumns + #oldColumns >= keyMode - ((keyMode - 7) / 3) then
            if math.random(1, 4) >= 2 then
                better = false
            else
                better = true
            end
        end
        oldColumns = newColumns
        for j = 1, #newColumns do
            table.insert(notes, utils.CreateHitObject(math.floor(time + 0.5), newColumns[j]))
        end
        time = time + 60000 / map.GetTimingPointAt(time).Bpm / beatSnap
    end
    return notes
end

function getKeyMode()
    if tonumber(map.Mode) == 1 then
        return 4
    else
        return 7
    end
end

---------------------------------------------------------------------------------------------------
-- GUI elements
---------------------------------------------------------------------------------------------------

function applyStyle()
    -- Plugin Styles
    local rounding = 10

    imgui.PushStyleVar(imgui_style_var.WindowPadding, { 8, 10 })
    imgui.PushStyleVar(imgui_style_var.FramePadding, { 8, 4 })
    imgui.PushStyleVar(imgui_style_var.ItemSpacing, { DEFAULT_WIDGET_HEIGHT / 2 - 1, 4 })
    imgui.PushStyleVar(imgui_style_var.ItemInnerSpacing, { SAMELINE_SPACING, 6 })
    imgui.PushStyleVar(imgui_style_var.WindowBorderSize, 1)
    imgui.PushStyleVar(imgui_style_var.WindowRounding, rounding)
    imgui.PushStyleVar(imgui_style_var.ChildRounding, rounding)
    imgui.PushStyleVar(imgui_style_var.FrameRounding, rounding)
    imgui.PushStyleVar(imgui_style_var.ScrollbarRounding, rounding)
    imgui.PushStyleVar(imgui_style_var.TabRounding, rounding)

    -- Plugin Colors
    imgui.PushStyleColor(imgui_col.Text, { 1.00, 1.00, 1.00, 1.00 })
    imgui.PushStyleColor(imgui_col.WindowBg, { 0.00, 0.00, 0.20, 1.00 })
    imgui.PushStyleColor(imgui_col.FrameBg, { 0.38, 0.45, 0.64, 1.00 })
    imgui.PushStyleColor(imgui_col.FrameBgHovered, { 0.48, 0.55, 0.74, 1.00 })
    imgui.PushStyleColor(imgui_col.FrameBgActive, { 0.28, 0.35, 0.54, 1.00 })
    imgui.PushStyleColor(imgui_col.TitleBg, { 0.00, 0.00, 0.20, 1.00 })
    --imgui.PushStyleColor(   imgui_col.TitleBgActive,           { 0.42, 0.46, 0.59, 1.00 })
    imgui.PushStyleColor(imgui_col.TitleBgCollapsed, { 0.00, 0.00, 0.20, 1.00 })
    --imgui.PushStyleColor(   imgui_col.ScrollbarGrab,           { 0.44, 0.44, 0.44, 1.00 })
    --imgui.PushStyleColor(   imgui_col.ScrollbarGrabHovered,    { 0.75, 0.73, 0.73, 1.00 })
    --imgui.PushStyleColor(   imgui_col.ScrollbarGrabActive,     { 0.99, 0.99, 0.99, 1.00 })
    imgui.PushStyleColor(imgui_col.CheckMark, { 1.00, 1.00, 1.00, 1.00 })
    imgui.PushStyleColor(imgui_col.Button, { 0.18, 0.35, 0.54, 1.00 })
    imgui.PushStyleColor(imgui_col.ButtonHovered, { 0.28, 0.45, 0.64, 1.00 })
    imgui.PushStyleColor(imgui_col.ButtonActive, { 0.08, 0.25, 0.44, 1.00 })
    --imgui.PushStyleColor(   imgui_col.Tab,                     { 0.40, 0.41, 0.42, 1.00 })
    --imgui.PushStyleColor(   imgui_col.TabHovered,              { 0.60, 0.61, 0.62, 0.80 })
    --imgui.PushStyleColor(   imgui_col.TabActive,               { 0.70, 0.71, 0.72, 0.80 })
    --imgui.PushStyleColor(   imgui_col.SliderGrab,              { 0.55, 0.56, 0.57, 1.00 })
    --imgui.PushStyleColor(   imgui_col.SliderGrabActive,        { 0.45, 0.46, 0.47, 1.00 })
end

-- Adds vertical blank space on the GUI
-- Parameters
--    height : value determining the height of the vertical blank space
function spacing()
    imgui.Dummy({ 0, 1 })
end

-- Adds a thin horizontal line separator on the GUI
function separator()
    spacing()
    imgui.Separator()
end

-- Creates a section heading
-- Parameters
--    title         : title of the section/heading (String)
--    skipSeparator : whether or not to skip the horizontal separator above the heading (Boolean)
function section(title, skipSeparator)
    if not skipSeparator then
        spacing()
        imgui.Separator()
    end
    spacing()
    imgui.Text(title)
    spacing()
end
