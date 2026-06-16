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

-- Draw window to get user parameters.
local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)
local width, height = 500, 450

-- Gather timelines from the current bin before showing the UI
resolve = Resolve()
projectManager = resolve:GetProjectManager()
project = projectManager:GetCurrentProject()
media_pool = project:GetMediaPool()
num_timelines = project:GetTimelineCount()
selected_bin = media_pool:GetCurrentFolder()

-- Build a mapping of timeline name -> timeline object
project_timelines = {}
for timeline_idx = 1, num_timelines do
    local t = project:GetTimelineByIndex(timeline_idx)
    project_timelines[t:GetName()] = t
end

-- Collect timelines in the current bin
bin_timelines = {}
for _, media_pool_item in pairs(selected_bin:GetClipList()) do
    if type(media_pool_item) ~= "nil" and type(media_pool_item) ~= "number" then
        if media_pool_item:GetClipProperty("Type") == "Timeline" then
            local name = media_pool_item:GetName()
            if project_timelines[name] ~= nil then
                bin_timelines[#bin_timelines + 1] = name
            end
        end
    end
end

print("Found timelines in current bin:")
print_table(bin_timelines)

-- Build list text for display
local timeline_list_text = table.concat(bin_timelines, "\n")
if timeline_list_text == "" then
    timeline_list_text = "(no timelines in current bin)"
end

-- Seed defaults from the first timeline in the bin
local default_width = "1920"
local default_height = "1080"
if bin_timelines[1] ~= nil then
    local first_tl = project_timelines[bin_timelines[1]]
    default_width = first_tl:GetSetting("timelineResolutionWidth")
    default_height = first_tl:GetSetting("timelineResolutionHeight")
end

win = disp:AddWindow({
    ID = "MyWin",
    WindowTitle = "Update Timeline Resolution",
    Geometry = {100, 100, width, height},
    Spacing = 10,
    ui:VGroup{
        ID = "root",
        ui:Label{
            ID = "TimelinesLabel",
            Text = "Timelines to update:"
        },
        ui:TextEdit{
            ID = "TimelinesList",
            Text = timeline_list_text,
            ReadOnly = true
        },
        ui:HGroup{
            ID = "widthGroup",
            ui:Label{
                ID = "WidthLabel",
                Text = "Width"
            },
            ui:TextEdit{
                ID = "WidthText",
                Text = default_width,
                PlaceholderText = "1920"
            }
        },
        ui:HGroup{
            ID = "heightGroup",
            ui:Label{
                ID = "HeightLabel",
                Text = "Height"
            },
            ui:TextEdit{
                ID = "HeightText",
                Text = default_height,
                PlaceholderText = "1080"
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
                Text = "Go"
            }
        }
    }
})

itm = win:GetItems()

function win.On.MyWin.Close(ev)
    disp:ExitLoop()
end

function win.On.cancelButton.Clicked(ev)
    print("Cancel Clicked")
    disp:ExitLoop()
end

function win.On.goButton.Clicked(ev)
    print("Go Clicked")

    local width_str = itm.WidthText.PlainText
    local height_str = itm.HeightText.PlainText

    assert(width_str ~= nil and width_str ~= "", "Width cannot be empty")
    assert(height_str ~= nil and height_str ~= "", "Height cannot be empty")
    assert(tonumber(width_str) ~= nil, "Width must be a number")
    assert(tonumber(height_str) ~= nil, "Height must be a number")

    failed_timelines = {}
    for _, name in ipairs(bin_timelines) do
        local tl = project_timelines[name]
        local ok_w = tl:SetSetting("timelineResolutionWidth", width_str)
        local ok_h = tl:SetSetting("timelineResolutionHeight", height_str)
        if ok_w and ok_h then
            print("Updated resolution for timeline: " .. name .. " --> " .. width_str .. "x" .. height_str)
        else
            print("WARNING: Failed to set resolution for timeline: " .. name)
            failed_timelines[#failed_timelines + 1] = name
        end
    end

    print("Done!")
    disp:ExitLoop()
end

win:Show()
disp:RunLoop()
win:Hide()

if #failed_timelines > 0 then
    local failed_text = table.concat(failed_timelines, "\n")
    local err_win = disp:AddWindow({
        ID = "ErrWin",
        WindowTitle = "Failed Timelines",
        Geometry = {120, 120, 500, 300},
        Spacing = 10,
        ui:VGroup{
            ui:Label{
                Text = "The following timelines failed to update:"
            },
            ui:TextEdit{
                ID = "FailedList",
                Text = failed_text,
                ReadOnly = true
            },
            ui:Button{
                ID = "okButton",
                Text = "OK"
            }
        }
    })

    function err_win.On.ErrWin.Close(ev)
        disp:ExitLoop()
    end

    function err_win.On.okButton.Clicked(ev)
        disp:ExitLoop()
    end

    err_win:Show()
    disp:RunLoop()
    err_win:Hide()
end
