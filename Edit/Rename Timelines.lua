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
    WindowTitle = "Generate All Clips Timeline",
    Geometry = { 100, 100, width, height },
    Spacing = 10,
    ui:VGroup{
        ID = "root",
        ui:HGroup{
            ID = "dst",
            ui:Label{ID = "FindLabel", Text = "Find String"},
            ui:TextEdit{ID = "FindText", Text = "", PlaceholderText = "find",}
        },
        ui:HGroup{
            ID = "dst",
            ui:Label{ID = "ReplaceLabel", Text = "Replace String"},
            ui:TextEdit{ID = "ReplaceText", Text = "", PlaceholderText = "replace",}
        },
        ui:HGroup{
            ID = "buttons",
            ui:Button{ID = "cancelButton", Text = "Cancel"},
            ui:Button{ID = "goButton", Text = "Replace"},
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

win:Show()
disp:RunLoop()
win:Hide()

if run_export then
    assert(itm.FindText.PlainText ~= nil and itm.FindText.PlainText ~= "", "Found empty New Timeline Name! Refusing to run")
    find_text = itm.FindText.PlainText
    replace_text = itm.ReplaceText.PlainText

    -- Get timelines
    resolve = Resolve()
    projectManager = resolve:GetProjectManager()
    project = projectManager:GetCurrentProject()
    media_pool = project:GetMediaPool()
    num_timelines = project:GetTimelineCount()
    selected_bin = media_pool:GetCurrentFolder()

    -- Iterate through timelines, figure out what clips we need and what frames are required.
    -- We'll make a table where the key is a clip identifier and the value is a clipinfo.
    local clips = {}
    local idx = 0

    -- Mapping of timeline name to timeline object
    project_timelines = {}
    for timeline_idx = 1, num_timelines do
        runner_timeline = project:GetTimelineByIndex(timeline_idx)
        project_timelines[runner_timeline:GetName()] = runner_timeline
    end

     -- Iterate through timelines in the current folder.
     for _, media_pool_item in pairs(selected_bin:GetClipList()) do
        -- Check if it's a timeline
        if type(media_pool_item) == nil or type(media_pool_item) == "number" then
            print("Skipping", media_pool_item)
        elseif media_pool_item:GetClipProperty("Type") == "Timeline" then
            desired_timeline_name = media_pool_item:GetName()
            curr_timeline = project_timelines[desired_timeline_name]
            curr_name = curr_timeline:GetName()
            new_name = string.gsub(curr_name, find_text, replace_text)
            curr_timeline:SetName(new_name)
            print("Renaming Timeline: ", curr_name, " --> ", new_name)
        end
    end

    print("Done!")
end
