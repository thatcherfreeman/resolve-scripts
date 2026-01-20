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

-- Get all selected media pool items
resolve = Resolve()
projectManager = resolve:GetProjectManager()
project = projectManager:GetCurrentProject()
curr_timeline = project:GetCurrentTimeline()

-- Draw window to get user parameters.
local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)
local width, height = 500, 400 -- Increased height to ensure all elements are visible

local is_windows = package.config:sub(1, 1) ~= "/"
local win = disp:AddWindow({
    ID = "MyWin",
    WindowTitle = "Update Version Numbers",
    Geometry = {100, 33, width, height},
    Spacing = 10,
    ui:HGroup{
        ID = "root",
        ui:VGroup{ui:Button{
            ID = "go_button",
            Text = "Go"
        }, ui:Button{
            ID = "closeButton",
            Text = "Close"
        }}
    }
})

-- Add your GUI element based event functions here:
itm = win:GetItems()

-- The window was closed
function win.On.MyWin.Close(ev)
    disp:ExitLoop()
end

function win.On.closeButton.Clicked(ev)
    print("Close Clicked")
    disp:ExitLoop()
end

local blacklist = {"Noise Reduction", "Qualifier Shrink", "Power Windows", "Blur, Sharpen & Mist", "Sizing"}

function win.On.go_button.Clicked(ev)
    print(curr_timeline:GetName())

    curr_item = curr_timeline:GetCurrentVideoItem()
    clip_graph = curr_item:GetNodeGraph(1)
    if clip_graph ~= nil then
        for node_idx = 1, clip_graph:GetNumNodes() do
            node_tools = clip_graph:GetToolsInNode(node_idx)
            if node_tools ~= nil then
                print("Node ID:", node_idx)
                print_table(node_tools)
            end
        end
    end

    clip_group = curr_item:GetColorGroup()
    if clip_group ~= nil then
        print("Group: ", clip_group:GetName())
        print("Pre clip graph:")
        pre_clip_graph = clip_group:GetPreClipNodeGraph()
        if pre_clip_graph ~= nil then
            for node_idx = 1, pre_clip_graph:GetNumNodes() do
                node_tools = pre_clip_graph:GetToolsInNode(node_idx)
                if node_tools ~= nil then
                    print("Pre-Clip Node ID:", node_idx)
                    print_table(node_tools)
                end
            end
        end

        post_clip_graph = clip_group:GetPostClipNodeGraph()
        print("Post clip graph:")
        if post_clip_graph ~= nil then
            for node_idx = 1, post_clip_graph:GetNumNodes() do
                node_tools = post_clip_graph:GetToolsInNode(node_idx)
                if node_tools ~= nil then
                    print("Post-Clip Node ID:", node_idx)
                    print_table(node_tools)
                end
            end
        end
    end

    timeline_graph = curr_timeline:GetNodeGraph()
    print("Timeline graph:")
    if timeline_graph ~= nil then
        for node_idx = 1, timeline_graph:GetNumNodes() do
            node_tools = timeline_graph:GetToolsInNode(node_idx)
            if node_tools ~= nil then
                print("Node ID:", node_idx)
                print_table(node_tools)
            end
        end
    end
end

win:Show()
disp:RunLoop()
win:Hide()
