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
local width,height = 500,200

local is_windows = package.config:sub(1,1) ~= "/"

win = disp:AddWindow({
    ID = "MyWin",
    WindowTitle = "Copy Timeline Settings",
    Geometry = { 100, 100, width, height },
    Spacing = 10,
    ui:VGroup{
        ID = "root",
        ui:HGroup{
            ID = "dst",
            ui:Label{ID = "SourceAttributes", Text = "Copy Attributes From:"},
            ui:ComboBox{ID = "SourceTimeline", Text = "Source Timeline:"},
        },
        ui:HGroup{
            ID = "buttons",
            ui:Button{ID = "cancelButton", Text = "Cancel"},
            ui:Button{ID = "goButton", Text = "Copy Timeline Settings to Current Bin"},
        },
    },
})

-- The window was closed
function win.On.MyWin.Close(ev)
    disp:ExitLoop()
    run_code = false
end

function win.On.cancelButton.Clicked(ev)
    print("Cancel Clicked")
    disp:ExitLoop()
    run_code = false
end

function win.On.goButton.Clicked(ev)
    print("Go Clicked")
    disp:ExitLoop()
    run_code = true
end

-- Add your GUI element based event functions here:
itm = win:GetItems()

-- Get timelines
resolve = Resolve()
projectManager = resolve:GetProjectManager()
project = projectManager:GetCurrentProject()
media_pool = project:GetMediaPool()
num_timelines = project:GetTimelineCount()
selected_bin = media_pool:GetCurrentFolder()

-- Mapping of timeline name to timeline object
project_timelines = {}
timeline_names_alphabetical = {}
for timeline_idx = 1, num_timelines do
    runner_timeline = project:GetTimelineByIndex(timeline_idx)
    project_timelines[runner_timeline:GetName()] = runner_timeline
    timeline_names_alphabetical[#timeline_names_alphabetical+1] = runner_timeline:GetName()
end

table.sort(timeline_names_alphabetical)
for _, timeline_name in pairs(timeline_names_alphabetical) do
    itm.SourceTimeline:AddItem(timeline_name)
end

win:Show()
disp:RunLoop()
win:Hide()

function copy_all_settings(source_timeline, target_timeline)
    source_timeline_settings = source_timeline:GetSetting()
    for setting_name, setting_value in pairs(source_timeline_settings) do
        result = target_timeline:SetSetting(setting_name, setting_value)
    end
    -- Do it again because the order apparently matters lol
    for setting_name, setting_value in pairs(source_timeline_settings) do
        result = target_timeline:SetSetting(setting_name, setting_value)
        if result then
            print("Successfully Set ", setting_name, " to ", setting_value)
        else
            print("Failed to    Set ", setting_name, " to ", setting_value)
        end
    end
end

if run_code then
    source_timeline_name = itm.SourceTimeline.CurrentText
    source_timeline = project_timelines[source_timeline_name]

    -- Iterate through timelines in the current folder.
    for _, media_pool_item in pairs(selected_bin:GetClipList()) do
        -- Check if it's a timeline
        if type(media_pool_item) == nil or type(media_pool_item) == "number" then
            print("Skipping", media_pool_item)
        elseif media_pool_item:GetClipProperty("Type") == "Timeline" then
            curr_timeline_name = media_pool_item:GetName()
            curr_timeline = project_timelines[curr_timeline_name]
            print("\n\nCopying settings from timeline ", source_timeline_name, " --> ", curr_timeline_name)
            copy_all_settings(source_timeline, curr_timeline)
        end
    end
    print("Done!")
end
