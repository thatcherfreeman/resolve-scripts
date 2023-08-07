
function print_table(t)
    for k, v in pairs(t) do
        print(k, ": ", v)
    end
end

function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

function remove_file_extension(fn)
    local out = string.match(fn, "^(.+)%..-$")
    if out == nil then
        return fn
    else
        return out
    end
end

function lines_from(file)
    if not file_exists(file) then return {} end
    local lines = {}
    for line in io.lines(file) do
        lines[#lines + 1] = line
    end
    return lines
end

function write_cdl(cdl, overwrite)
    if overwrite == false then
        if file_exists(cdl["fn"]..".cdl") == true then
            print(string.format("File %s already exists! Skipping cdl...", cdl["fn"]..".cdl"))
            return
        end
    end
    cdl_content = string.format([[
<?xml version="1.0" encoding="UTF-8"?>
<ColorDecisionList xmlns="urn:ASC:CDL:v1.01">
    <ColorDecision>
        <ColorCorrection>
            <SOPNode>
                <Description>%s</Description>
                <Slope>%s</Slope>
                <Offset>%s</Offset>
                <Power>%s</Power>
            </SOPNode>
            <SATNode>
                <Saturation>%s</Saturation>
            </SATNode>
        </ColorCorrection>
    </ColorDecision>
</ColorDecisionList>]], cdl["name"], cdl["slope"], cdl["offset"], cdl["power"], cdl["sat"])
    file = io.open(cdl["fn"]..".cdl", "w")
    file:write(cdl_content)
    file:close()
end

function write_cdls(cdl_list, overwrite)
    for i, cdl in pairs(cdl_list) do
        if cdl["skip"] == false then
            print(string.format("\nWriting CDL %s to %s.cdl", cdl["name"], cdl["fn"]))
            print_table(cdl)
            write_cdl(cdl, overwrite)
        end
    end
end

function write_cc(cdl, overwrite)
    if overwrite == false then
        if file_exists(cdl["fn"]..".cc") == true then
            print(string.format("File %s already exists! Skipping cc...", cdl["fn"]..".cc"))
            return
        end
    end
    cc_content = string.format([[
<?xml version="1.0" encoding="UTF-8"?>
<ColorCorrection id="%s">
    <SOPNode>
        <Slope>%s</Slope>
        <Offset>%s</Offset>
        <Power>%s</Power>
    </SOPNode>
    <SatNode>
        <Saturation>%s</Saturation>
    </SatNode>
</ColorCorrection>]], cdl["name"], cdl["slope"], cdl["offset"], cdl["power"], cdl["sat"])
    file = io.open(cdl["fn"]..".cc", "w")
    file:write(cc_content)
    file:close()
end

function write_ccs(cdl_list, overwrite)
    for i, cdl in pairs(cdl_list) do
        if cdl["skip"] == false then
            print(string.format("\nWriting CC %s to %s.cc", cdl["name"], cdl["fn"]))
            print_table(cdl)
            write_cc(cdl, overwrite)
        end
    end
end

function write_ccc(cdl_list, fn, overwrite)
    if overwrite == false then
        if file_exists(fn..".ccc") == true then
            print(string.format("File %s already exists! Skipping ccc...", fn..".ccc"))
            return
        end
    end
    out = [[<ColorCorrectionCollection xmlns="urn:ASC:CDL:v1.2">]]
    for i, cdl in pairs(cdl_list) do
        if cdl["skip"] == false then
            print_table(cdl)
            cc_content = string.format([[
    <ColorCorrection id="%s">
        <SOPNode>
            <Slope>%s</Slope>
            <Offset>%s</Offset>
            <Power>%s</Power>
        </SOPNode>
        <SatNode>
            <Saturation>%s</Saturation>
        </SatNode>
    </ColorCorrection>]], cdl["name"], cdl["slope"], cdl["offset"], cdl["power"], cdl["sat"])
            out = out.."\n"..cc_content
        end
    end
    out = out.."\n".."</ColorCorrectionCollection>"
    print("Writing to file: ", fn..".ccc")
    file = io.open(fn..".ccc", "w")
    file:write(out)
    file:close()
end

function edl_id_to_num(edl_id)
    return tonumber(edl_id)
end

function clip_id_to_name(timeline, attribute)
    timelineItems = timeline:GetItemListInTrack("video", 1)
    names = {}
    for i, item in pairs(timelineItems) do
        if i ~= "__flags" then
            if item:GetMediaPoolItem() ~= nil then
                if attribute == "Reel Name" then
                    clipname = item:GetMediaPoolItem():GetClipProperty("Reel Name")
                    if clipname == nil or clipname == "" then
                        clipname = item:GetMediaPoolItem():GetClipProperty("File Name")
                    end
                elseif attribute == "File Name" then
                    clipname = item:GetMediaPoolItem():GetClipProperty("File Name")
                end
                name = remove_file_extension(clipname)
            else
                name = "NO_MEDIA_POOL_ITEM"
            end
            table.insert(names, i, name)
        end
    end
    print("\nClip Names:")
    print_table(names)
    return names
end

-- Draw window to get user parameters.
local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)
local width,height = 500,200

local is_windows = package.config:sub(1,1) ~= "/"
local placeholder_text = "/Users/yourname/Resolve Projects/"
if is_windows == true then
    placeholder_text = "C:/Users/yourname/Resolve Projects/"
end

win = disp:AddWindow({
    ID = "MyWin",
    WindowTitle = "Export CDLs",
    Geometry = { 100, 100, width, height },
    Spacing = 10,
    ui:VGroup{
        ID = "root",
        ui:HGroup{
            ID = "dst",
            ui:Label{ID = "DstLabel", Text = "Location to write files to:"},
            ui:TextEdit{ID = "DstPath", Text = "", PlaceholderText = placeholder_text,}
        },
        ui:HGroup{
            ui:Label{ID = "outputLabel", Text = "Output Format:"},
            ui:ComboBox{ID = "outputType", Text = "Output Format"},
        },
        ui:HGroup{
            ui:Label{ID = "outputFnLabel", Text = "Output File Name:"},
            ui:ComboBox{ID = "outputFnType", Text = "Output File Name"},
        },
        ui:CheckBox{ID = "overwriteFiles", Text = "Overwrite Color Files"},
        ui:HGroup{
            ID = "buttons",
            ui:Button{ID = "cancelButton", Text = "Cancel"},
            ui:Button{ID = "goButton", Text = "Go"},
        },
    },
})

run_export = false

-- The window was closed
function win.On.MyWin.Close(ev)
    disp:ExitLoop()
    run_export = false
end

function win.On.cancelButton.Clicked(ev)
    print("Cancel Clicked")
    disp:ExitLoop()
    run_export = false
end

function win.On.goButton.Clicked(ev)
    print("Go Clicked")
    disp:ExitLoop()
    run_export = true
end

-- Add your GUI element based event functions here:
itm = win:GetItems()
itm.outputType:AddItem('CDL')
itm.outputType:AddItem('CC')
itm.outputType:AddItem('CCC')
itm.outputFnType:AddItem('File Name')
itm.outputFnType:AddItem('Reel Name')

win:Show()
disp:RunLoop()
win:Hide()

if run_export then
    assert (itm.DstPath.PlainText ~= nil and itm.DstPath.PlainText ~= "", "Found empty destination path! Refusing to run")
    dstPath = itm.DstPath.PlainText
    overwrite = itm.overwriteFiles.Checked
    separator = package.config:sub(1,1)

    -- Make EDL via Export CDL button
    resolve = Resolve()
    projectManager = resolve:GetProjectManager()
    project = projectManager:GetCurrentProject()
    timeline = project:GetCurrentTimeline()
    output_fn = string.format("%s%s%s.edl", dstPath, separator, timeline:GetName())
    timeline:Export(output_fn, resolve.EXPORT_EDL, resolve.EXPORT_CDL)

    -- The EDL doesn't include clip names, so map from the ID to the clip name here.
    clip_names = clip_id_to_name(timeline, itm.outputFnType.CurrentText)

    -- Parse the EDL file.
    local edl = lines_from(output_fn)
    print_table(edl)

    cdl_list = {}
    curr_cdl = {}
    for i, line in pairs(edl) do
        if string.match(line, "^(%d+)[%s%a]+.*$") ~= nil then
            curr_cdl = {}
            edl_id = string.match(line, "^(%d+)[%s%a]+.*$")
            curr_cdl["name"] = clip_names[edl_id_to_num(edl_id)]
            curr_cdl["fn"] = string.format("%s%s%s", dstPath, separator, curr_cdl['name'])
            curr_cdl["skip"] = (curr_cdl["name"] == "NO_MEDIA_POOL_ITEM")
        elseif string.match(line, "^*ASC_SOP") ~= nil then
            cols = {"slope", "offset", "power"}
            index = 1
            for nums in string.gmatch(line,"%(([%-%d%.]+%s[%-%d%.]+%s[%-%d%.]+)%)") do
                assert(nums ~= nil, string.format("Couldn't parse nums from line: %s", line))
                curr_cdl[cols[index]] = nums
                index = index + 1
            end
        elseif string.match(line, "^%*ASC_SAT") ~= nil then
            curr_cdl["sat"] = string.match(line, "([%-%.%d]+)")
            -- This line is always last, so let's save this CDL.
            table.insert(cdl_list, curr_cdl)
        else
            -- do nothing
        end
    end

    -- Write all CDLs to file(s)
    if itm.outputType.CurrentText == "CDL" then
        write_cdls(cdl_list, overwrite)
    elseif itm.outputType.CurrentText == "CC" then
        write_ccs(cdl_list, overwrite)
    elseif itm.outputType.CurrentText == "CCC" then
        write_ccc(cdl_list, string.format("%s%s%s", dstPath, separator, timeline:GetName()), overwrite)
    else
        print("Unknown file type: ", itm.outputType.CurrentText)
    end

    if #cdl_list ~= #clip_names then
        print(string.format("WARNING: Names extracted from Track 1 of the timeline do not match the clips found in the timeline EDL. Found %d clip names and the edl had %d entries.", #clip_names, #cdl_list))
        print_table(clip_names)
    end

    print("Done!")
end
