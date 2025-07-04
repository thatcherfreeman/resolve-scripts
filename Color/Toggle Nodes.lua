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
        ui:VGroup{ui:HGroup{
            ID = "id_specify",
            ui:Label{
                ID = "IdSpecifyLabel",
                Text = "Indicate Node ID"
            },
            ui:TextEdit{
                ID = "SetId",
                Text = "",
                PlaceholderText = "1"
            }
        }, ui:HGroup{
            ID = "layer_idx",
            ui:Label{
                ID = "LayerIdxLabel",
                Text = "Indicate Layer ID"
            },
            ui:TextEdit{
                ID = "SetLayerIdx",
                Text = "1",
                PlaceholderText = "1"
            }
        }, ui:Button{
            ID = "setEnable",
            Text = "Enable"
        }, ui:Button{
            ID = "setDisable",
            Text = "Disable"
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

function win.On.setEnable.Clicked(ev)
    local layer_idx = tonumber(itm.SetLayerIdx.PlainText)
    local node_id = tonumber(itm.SetId.PlainText)

    if layer_idx == nil or node_id == nil then
        print("Invalid layer index or node ID")
        return
    end

    num_tracks = curr_timeline:GetTrackCount("video")
    for track_idx = 1, num_tracks do
        local track_items = curr_timeline:GetItemListInTrack("video", track_idx)
        for _, track_item in pairs(track_items) do
            if track_item ~= nil and type(track_item) ~= "number" and track_item:GetClipEnabled() then
                local graph = track_item:GetNodeGraph(layer_idx)
                if graph ~= nil then
                    if not graph:SetNodeEnabled(node_id, true) then
                        print("Failed to enable node:", node_id)
                    end
                end
            end
        end
    end
end

function win.On.setDisable.Clicked(ev)
    local layer_idx = tonumber(itm.SetLayerIdx.PlainText)
    local node_id = tonumber(itm.SetId.PlainText)

    if layer_idx == nil or node_id == nil then
        print("Invalid layer index or node ID")
        return
    end

    num_tracks = curr_timeline:GetTrackCount("video")
    for track_idx = 1, num_tracks do
        local track_items = curr_timeline:GetItemListInTrack("video", track_idx)
        for _, track_item in pairs(track_items) do
            if track_item ~= nil and type(track_item) ~= "number" and track_item:GetClipEnabled() then
                local graph = track_item:GetNodeGraph(layer_idx)
                if graph ~= nil then
                    if not graph:SetNodeEnabled(node_id, false) then
                        print("Failed to disable node:", node_id)
                    end
                end
            end
        end
    end
end

win:Show()
disp:RunLoop()
win:Hide()
