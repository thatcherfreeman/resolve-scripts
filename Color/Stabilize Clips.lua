resolve = Resolve()
projectManager = resolve:GetProjectManager()
project = projectManager:GetCurrentProject()
curr_timeline = project:GetCurrentTimeline()

-- Collect all clips from all video tracks up front
local all_clips = {}
local clip_colors = {}
local flag_colors = {}
local track_names = {}  -- "All" plus each track index

local num_tracks = curr_timeline:GetTrackCount("video")
for track_idx = 1, num_tracks do
    local track_items = curr_timeline:GetItemListInTrack("video", track_idx)
    for _, item in pairs(track_items) do
        if item ~= nil and type(item) ~= "number" then
            table.insert(all_clips, {item = item, track = track_idx})

            local color = item:GetClipColor()
            if color and color ~= "" and not clip_colors[color] then
                clip_colors[color] = true
            end

            local flags = item:GetFlagList()
            if flags then
                for _, flag in ipairs(flags) do
                    if flag and flag ~= "" and not flag_colors[flag] then
                        flag_colors[flag] = true
                    end
                end
            end
        end
    end
    table.insert(track_names, tostring(track_idx))
end

-- Build UI
local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)
local width, height = 400, 220

local win = disp:AddWindow({
    ID = "BulkStabilizeWin",
    WindowTitle = "Bulk Stabilize",
    Geometry = {100, 100, width, height},
    Spacing = 10,
    ui:VGroup{
        ID = "root",
        ui:HGroup{
            ui:Label{ Text = "Clip Color", MinimumSize = {100, 20} },
            ui:ComboBox{ ID = "ClipColorCombo" }
        },
        ui:HGroup{
            ui:Label{ Text = "Flag Color", MinimumSize = {100, 20} },
            ui:ComboBox{ ID = "FlagColorCombo" }
        },
        ui:HGroup{
            ui:Label{ Text = "Video Track", MinimumSize = {100, 20} },
            ui:ComboBox{ ID = "TrackCombo" }
        },
        ui:HGroup{
            ui:Label{
                ID = "StatusLabel",
                Text = "",
                Alignment = { AlignHCenter = true, AlignVCenter = true }
            }
        },
        ui:HGroup{
            ui:Button{ ID = "CancelButton", Text = "Cancel" },
            ui:Button{ ID = "StabilizeButton", Text = "Stabilize" }
        }
    }
})

local itm = win:GetItems()

-- Populate clip color combo
itm.ClipColorCombo:AddItem("Any")
for color, _ in pairs(clip_colors) do
    itm.ClipColorCombo:AddItem(color)
end

-- Populate flag color combo
itm.FlagColorCombo:AddItem("Any")
itm.FlagColorCombo:AddItem("None")  -- clips with no flags at all
for color, _ in pairs(flag_colors) do
    itm.FlagColorCombo:AddItem(color)
end

-- Populate track combo
itm.TrackCombo:AddItem("All")
for _, name in ipairs(track_names) do
    itm.TrackCombo:AddItem(name)
end

function win.On.BulkStabilizeWin.Close(ev)
    disp:ExitLoop()
end

function win.On.CancelButton.Clicked(ev)
    disp:ExitLoop()
end

function win.On.StabilizeButton.Clicked(ev)
    local clip_color_filter = itm.ClipColorCombo.CurrentText
    local flag_filter = itm.FlagColorCombo.CurrentText
    local track_filter = itm.TrackCombo.CurrentText

    local success_count = 0
    local fail_count = 0
    local skip_count = 0

    for _, entry in ipairs(all_clips) do
        local item = entry.item
        local track = entry.track

        -- Track filter
        if track_filter ~= "All" and tostring(track) ~= track_filter then
            skip_count = skip_count + 1
            goto continue
        end

        -- Clip color filter
        if clip_color_filter ~= "Any" then
            local color = item:GetClipColor()
            if color ~= clip_color_filter then
                skip_count = skip_count + 1
                goto continue
            end
        end

        -- Flag filter
        if flag_filter ~= "Any" then
            local flags = item:GetFlagList()
            if flag_filter == "None" then
                if flags and #flags > 0 then
                    skip_count = skip_count + 1
                    goto continue
                end
            else
                local has_flag = false
                if flags then
                    for _, f in ipairs(flags) do
                        if f == flag_filter then
                            has_flag = true
                            break
                        end
                    end
                end
                if not has_flag then
                    skip_count = skip_count + 1
                    goto continue
                end
            end
        end

        -- Stabilize
        local name = item:GetName()
        print("Stabilizing: " .. name .. " (track " .. track .. ")")
        if item:Stabilize() then
            print("  OK")
            success_count = success_count + 1
        else
            print("  FAILED")
            fail_count = fail_count + 1
        end

        ::continue::
    end

    local status = string.format("%d succeeded, %d failed, %d skipped.", success_count, fail_count, skip_count)
    print("Done. " .. status)
    itm.StatusLabel.Text = status
end

win:Show()
disp:RunLoop()
win:Hide()
