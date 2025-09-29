function print_table(t, indentation)
    if indentation == nil then
        indentation = 0
    end
    local outer_prefix = string.rep("    ", indentation)
    local inner_prefix = string.rep("    ", indentation + 1)
    print(outer_prefix, "{")
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(inner_prefix, k, ": ")
            print_table(v, indentation + 1)
        elseif type(v) == "string" then
            print(inner_prefix, k, string.format([[: "%s"]], v))
        else
            print(inner_prefix, k, ": ", v)
        end
    end
    print(outer_prefix, "}")
end

function frame_to_timecode(frames, fps)
    print(frames)
    print(fps)
    local h = math.floor(frames / (fps * 3600))
    local m = math.floor(frames / (fps * 60)) % 60
    local s = math.floor((frames % (fps * 60)) / fps)
    local f = math.floor(frames % (fps * 60)) % fps

    local function zfill(num)
        return string.format("%02d", num)
    end

    return string.format("%s:%s:%s:%s", zfill(h), zfill(m), zfill(s), zfill(f))
end

-- Draw window to get user parameters.
local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)
local width, height = 500, 250

local is_windows = package.config:sub(1, 1) ~= "/"

win = disp:AddWindow({
    ID = "MyWin",
    WindowTitle = "Rename Timelines",
    Geometry = {100, 100, width, height},
    Spacing = 10,
    ui:VGroup{
        ID = "root",
        ui:HGroup{
            ui:Label{
                ID = "NameFilterLabel",
                Text = "Name Filter"
            },
            ui:TextEdit{
                ID = "NameFilterText",
                Text = "",
                PlaceholderText = "enter substring of marker name"
            }
        },
        ui:HGroup{
            ID = "marker_color",
            ui:Label{
                ID = "MarkerColorLabel",
                Text = "Marker Color"
            },
            ui:ComboBox{
                ID = "MarkerColorCombo",
                Text = "Marker Color",
            }
        },
        ui:HGroup{
            ID = "buttons",
            ui:Button{
                ID = "cancelButton",
                Text = "Cancel"
            },
            ui:Button{
                ID = "goButton",
                Text = "Grab Stills"
            }
        }
    }
})

-- Add your GUI element based event functions here:
itm = win:GetItems()

-- The window was closed
function win.On.MyWin.Close(ev)
    disp:ExitLoop()
end

function win.On.cancelButton.Clicked(ev)
    print("Cancel Clicked")
    disp:ExitLoop()
end

 -- Get timelines
resolve = Resolve()
projectManager = resolve:GetProjectManager()
project = projectManager:GetCurrentProject()
curr_timeline = project:GetCurrentTimeline()
all_markers = curr_timeline:GetMarkers()


curr_framerate = curr_timeline:GetSetting("timelineFrameRate")
print("Current framerate: ", curr_framerate)

print_table(all_markers)

all_colors = {}

itm.MarkerColorCombo:AddItem("Any")
for frame_id, marker in pairs(all_markers) do
    if marker.color and not all_colors[marker.color] then
        all_colors[marker.color] = true
        itm.MarkerColorCombo:AddItem(marker.color)
    end
end


function win.On.goButton.Clicked(ev)
    print("Go Clicked")
    -- Get text from all fields
    name_filter = itm.NameFilterText.PlainText
    marker_color = itm.MarkerColorCombo.CurrentText
    script_initial_timecode = curr_timeline:GetCurrentTimecode()
    print("starting_timecode: ", script_initial_timecode)

    timeline_start_timecode = curr_timeline:GetStartTimecode()
    curr_timeline:SetStartTimecode("00:00:00:00")


    for frame_id, marker in pairs(all_markers) do
        if (name_filter == "" or (marker.name and string.find(marker.name, name_filter))) and
           (marker_color == "Any" or (marker.color and marker.color == marker_color)) then
            print(string.format("Grabbing still for marker at frame %d, name: %s, color: %s", frame_id, marker.name or "", marker.color or ""))
            marker_timecode = frame_to_timecode(frame_id, curr_framerate)
            print("Computed timecode for frame: ", marker_timecode)
            curr_timeline:SetCurrentTimecode(marker_timecode)
            curr_timeline:GrabStill(frame_id)
        end
    end

    curr_timeline:SetStartTimecode(timeline_start_timecode)
    curr_timeline:SetCurrentTimecode(script_initial_timecode)
    print("Done!")
end


win:Show()
disp:RunLoop()
win:Hide()
