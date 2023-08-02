
function print_table(t)
    for k, v in pairs(t) do
        print(k, ": ", v)
    end
end

function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

function lines_from(file)
    if not file_exists(file) then return {} end
    local lines = {}
    for line in io.lines(file) do
        lines[#lines + 1] = line
    end
    return lines
end

function write_cdl(fn, cdl, overwrite)
    if overwrite == false then
        if file_exists(fn) == true then
            print(string.format("File %s already exists! skipping cdl...", fn))
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
</ColorDecisionList>]], cdl['description'], cdl['slope'], cdl['offset'], cdl['power'], cdl['sat'])
    file = io.open(fn, 'w')
    file:write(cdl_content)
    file:close()
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
    ID = 'MyWin',
    WindowTitle = 'Export CDLs',
    Geometry = { 100, 100, width, height },
    Spacing = 10,
    ui:VGroup{
        ID = 'root',
        ui:HGroup{
            ID = 'dst',
            ui:Label{ID = 'DstLabel', Text = 'Location to write EDL and CDLs to:'},
            ui:TextEdit{ID = 'DstPath', Text = '', PlaceholderText = placeholder_text,}
        },
        ui:CheckBox{ID = 'overwriteFiles', Text = 'Overwrite Files'},
        ui:HGroup{
            ID = 'buttons',
            ui:Button{ID = 'cancelButton', Text = 'Cancel'},
            ui:Button{ID = 'goButton', Text = 'Go'},
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
    print('Cancel Clicked')
    disp:ExitLoop()
    run_export = false
end

function win.On.goButton.Clicked(ev)
    print('Go Clicked')
    disp:ExitLoop()
    run_export = true
end

-- Add your GUI element based event functions here:
itm = win:GetItems()

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
    if overwrite == false and file_exists(output_fn) == true then
        print("Won't overwrite file ", output_fn)
        return
    end
    timeline:Export(output_fn, resolve.EXPORT_EDL, resolve.EXPORT_CDL)

    local edl = lines_from(output_fn)
    print_table(edl)

    curr_cdl = {}
    for i, line in pairs(edl) do
        if string.match(line, "^(%d+)[%s%a]+.*$") ~= nil then
            curr_cdl = {}
            curr_cdl['name'] = string.match(line, "^(%d+)[%s%a]+.*$")
            curr_cdl['description'] = string.format("Timeline %s Clip %s", timeline:GetName(), curr_cdl['name'])
        elseif string.match(line, "^*ASC_SOP") ~= nil then
            cols = {'slope', 'offset', 'power'}
            index = 1
            for nums in string.gmatch(line,"%(([%-%d%.]+%s[%-%d%.]+%s[%-%d%.]+)%)") do
                assert(nums ~= nil, string.format("Couldn't parse nums from line: %s", line))
                curr_cdl[cols[index]] = nums
                index = index + 1
            end
        elseif string.match(line, "^%*ASC_SAT") ~= nil then
            curr_cdl['sat'] = string.match(line, "([%-%.%d]+)")

            -- This line is always last, so let's write it to a file.
            cdl_fn = string.format("%s%s%s_%s.cdl", dstPath, separator, timeline:GetName(), curr_cdl['name'])
            print(string.format("Writing clip %s to file %s", curr_cdl['name'], cdl_fn))
            print_table(curr_cdl)
            write_cdl(cdl_fn, curr_cdl, overwrite)
        else
            -- do nothing
        end
    end
    print("Done!")
end
