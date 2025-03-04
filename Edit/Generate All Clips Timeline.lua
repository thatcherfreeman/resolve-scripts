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

function sort_clip_infos(clip_infos)
    -- In place sort by startFrame
    table.sort(clip_infos, function(a, b)
        return a.startFrame < b.startFrame
    end)
end

function merge_clip_infos(clip_info_a, clip_info_b)
    -- Return new clipinfo that spans clip_info_a and clip_info_b
    assert(clip_info_a.mediaPoolItem == clip_info_b.mediaPoolItem,
        "merge_clip_infos: Cannot merge clip infos from different media pool items")
    return {
        mediaPoolItem = clip_info_a.mediaPoolItem,
        startFrame = math.min(clip_info_a.startFrame, clip_info_b.startFrame),
        endFrame = math.max(clip_info_a.endFrame, clip_info_b.endFrame)
    }
end

function check_clip_infos_overlap(clip_info_a, clip_info_b, connection_threshold)
    return not (clip_info_a.endFrame < clip_info_b.startFrame - connection_threshold or clip_info_b.endFrame <
               clip_info_a.startFrame - connection_threshold)
end

function merge_clip_infos_if_close(clip_info_a, clip_info_b, connection_threshold)
    assert(clip_info_a.mediaPoolItem == clip_info_b.mediaPoolItem,
        "merge_clip_infos_if_close: Cannot merge clip infos from different media pool items")
    if check_clip_infos_overlap(clip_info_a, clip_info_b, connection_threshold) then
        return merge_clip_infos(clip_info_a, clip_info_b)
    end
    return nil
end

function merge_clip_infos_if_close_all(clip_infos, connection_threshold)
    -- Merge clip_infos that are close together
    sort_clip_infos(clip_infos)
    local i = 1
    while i <= #clip_infos do
        local j = i + 1
        local merged = false
        while j <= #clip_infos do
            local merged_clip_info = merge_clip_infos_if_close(clip_infos[i], clip_infos[j], connection_threshold)
            if merged_clip_info ~= nil then
                print("Merging clips ", clip_infos[i].mediaPoolItem:GetName(), " and ",
                    clip_infos[j].mediaPoolItem:GetName())
                clip_infos[i] = merged_clip_info
                table.remove(clip_infos, j)
                merged = true
            else
                j = j + 1
            end
        end
        if not merged then
            i = i + 1
        end
    end
    return clip_infos
end

-- Draw window to get user parameters.
local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)
local width, height = 500, 300

local is_windows = package.config:sub(1, 1) ~= "/"

win = disp:AddWindow({
    ID = "MyWin",
    WindowTitle = "Generate All Clips Timeline",
    Geometry = {100, 100, width, height},
    Spacing = 10,
    ui:VGroup{
        ID = "root",
        ui:HGroup{
            ID = "dst",
            ui:Label{
                ID = "DstLabel",
                Text = "New Timeline Name"
            },
            ui:TextEdit{
                ID = "DstTimelineName",
                Text = "",
                PlaceholderText = "Master Timeline"
            }
        },
        ui:HGroup{ui:Label{
            ID = "selectionMethodLabel",
            Text = "Select Timelines By:"
        }, ui:ComboBox{
            ID = "selectionMethod",
            Text = "Current Selection"
        }},
        ui:HGroup{ui:Label{
            ID = "ConnectionThresholdLabel",
            Text = "Connection Threshold (Frames)"
        }, ui:TextEdit{
            ID = "ConnectionThreshold",
            Text = "24",
            PlaceholderText = "24"
        }},
        ui:CheckBox{
            ID = "includeDisabledItems",
            Text = "Include Disabled Clips"
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
itm.selectionMethod:AddItem('Current Selection')
itm.selectionMethod:AddItem('Current Bin')

win:Show()
disp:RunLoop()
win:Hide()

if run_export then
    assert(itm.DstTimelineName.PlainText ~= nil and itm.DstTimelineName.PlainText ~= "",
        "Found empty New Timeline Name! Refusing to run")
    local connection_threshold = tonumber(itm.ConnectionThreshold.PlainText)
    dst_timeline_name = itm.DstTimelineName.PlainText
    allow_disabled_clips = itm.includeDisabledItems.Checked

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

    -- Mapping of timeline name to timeline object
    project_timelines = {}
    for timeline_idx = 1, num_timelines do
        runner_timeline = project:GetTimelineByIndex(timeline_idx)
        project_timelines[runner_timeline:GetName()] = runner_timeline
    end

    -- Iterate through timelines in the current folder.

    local selected_clips
    if itm.selectionMethod.CurrentText == "Current Bin" then
        selected_clips = selected_bin:GetClipList()
    elseif itm.selectionMethod.CurrentText == "Current Selection" then
        selected_clips = media_pool:GetSelectedClips()
    else
        assert(false, "Unknown selection method.")
    end
    for _, media_pool_item in pairs(selected_clips) do
        -- Check if it's a timeline
        if type(media_pool_item) == nil or type(media_pool_item) == "number" then
            print("Skipping", media_pool_item)
        elseif media_pool_item:GetClipProperty("Type") == "Timeline" then
            desired_timeline_name = media_pool_item:GetName()
            curr_timeline = project_timelines[desired_timeline_name]

            num_tracks = curr_timeline:GetTrackCount("video")
            for track_idx = 1, num_tracks do
                track_items = curr_timeline:GetItemListInTrack("video", track_idx)
                for _, track_item in pairs(track_items) do
                    if (track_item == nil or type(track_item) == "number") then
                        print("Skipping ", track_item)
                    elseif allow_disabled_clips or track_item:GetClipEnabled() then
                        -- Add clip and clipinfo to clips.
                        if (track_item:GetMediaPoolItem() == nil) then
                            print("could not retrieve media item for clip ", track_item:GetName())
                        else
                            media_item = track_item:GetMediaPoolItem()
                            id = media_item:GetMediaId()
                            local start_frame = track_item:GetSourceStartFrame()
                            local end_frame = track_item:GetSourceEndFrame()
                            if clips[id] == nil then
                                clips[id] = {}
                            end
                            clip_info = {
                                mediaPoolItem = media_item,
                                startFrame = start_frame,
                                endFrame = end_frame
                            }
                            clips[id][#clips[id] + 1] = clip_info
                        end
                    end
                end
            end
        end
    end

    print("Unmerged clips:")
    print_table(clips)

    -- for each clips[id], merge clip_infos that are less than a certain amount of frames apart
    for id, clip_infos in pairs(clips) do
        clips[id] = merge_clip_infos_if_close_all(clip_infos, connection_threshold)
    end

    print("Merged Clips")
    print_table(clips)

    print("Adding all clips to new timeline...")
    local new_timeline = media_pool:CreateEmptyTimeline(dst_timeline_name)
    assert(project:SetCurrentTimeline(new_timeline), "couldn't set current timeline to the new timeline")

    for _, clip_infos in pairs(clips) do
        for _, clip_info in pairs(clip_infos) do
            media_pool:AppendToTimeline({clip_info})
        end
    end

    print("Done!")
end
