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
            ui:Label{ID = "DstLabel", Text = "New Timeline Name"},
            ui:TextEdit{ID = "DstTimelineName", Text = "", PlaceholderText = "Master Timeline",}
        },
        ui:CheckBox{ID = "includeDisabledItems", Text = "Include Disabled Clips"},
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

win:Show()
disp:RunLoop()
win:Hide()

if run_export then
    assert(itm.DstTimelineName.PlainText ~= nil and itm.DstTimelineName.PlainText ~= "", "Found empty New Timeline Name! Refusing to run")
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
                            local end_frame = track_item:GetSourceEndFrame() - 1
                            -- print("Clip: ", id)
                            -- print("Left Offset: ", track_item:GetLeftOffset())
                            -- print("Right Offset: ", track_item:GetRightOffset())
                            -- print("Start: ", track_item:GetStart())
                            -- print("End: ", track_item:GetEnd())
                            -- print("SourceStartFrame: ", track_item:GetSourceStartFrame())
                            -- print("SourceEndFrame: ", track_item:GetSourceEndFrame())
                            -- print("SourceStartTime: ", track_item:GetSourceStartTime())
                            -- print("SourceEndTime: ", track_item:GetSourceEndTime())
                            -- print()
                            if clips[id] ~= nil then
                                start_frame = math.min(clips[id].clip_info.startFrame, start_frame)
                                end_frame = math.max(clips[id].clip_info.endFrame, end_frame)
                                clip_idx = clips[id].idx
                            else
                                idx = idx + 1
                                clip_idx = idx
                            end
                            clips[id] = {
                                idx = clip_idx,
                                clip_info = {
                                    mediaPoolItem = media_item,
                                    startFrame = start_frame,
                                    endFrame = end_frame,
                                }
                            }
                        end
                    end
                end
            end
        end
    end




    clip_items = {}
    for _, clip_item in pairs(clips) do
        clip_items[clip_item.idx] = clip_item.clip_info
    end
    print("Clip items:")
    print_table(clip_items)

    print(string.format("Adding %d items to new timeline...", #clip_items))
    media_pool:CreateTimelineFromClips(dst_timeline_name, clip_items)

    print("Done!")
end
