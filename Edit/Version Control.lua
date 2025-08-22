-- Version Control v2.3 - Context-Aware (Media Pool vs Timeline)
-- written by Pinionist, based on Update Version Number script by Thatcher Freeman
-- Fixed timeline detection and proper UI branching
resolve = Resolve()
projectManager = resolve:GetProjectManager()
project = projectManager:GetCurrentProject()
media_pool = project:GetMediaPool()

-- Get context information
local timeline = project:GetCurrentTimeline()
local selected_clips = media_pool:GetSelectedClips()

-- Proper timeline detection
local timeline_item_count = 0
local is_timeline_context = false

if timeline then
    local video_tracks = timeline:GetTrackCount("video")
    local audio_tracks = timeline:GetTrackCount("audio")

    for track = 1, video_tracks do
        local items = timeline:GetItemListInTrack("video", track)
        if items then
            timeline_item_count = timeline_item_count + #items
        end
    end

    -- Also check audio tracks for audio-only clips
    for track = 1, audio_tracks do
        local items = timeline:GetItemListInTrack("audio", track)
        if items then
            for _, item in ipairs(items) do
                local media_item = item:GetMediaPoolItem()
                if media_item then
                    timeline_item_count = timeline_item_count + 1
                end
            end
        end
    end

    is_timeline_context = timeline_item_count > 0
end

-- Determine working context
local working_clips = {}
local context_type = ""

if is_timeline_context then
    context_type = "timeline"
    print("Timeline context detected: " .. timeline:GetName() .. " with " .. timeline_item_count .. " items")

    -- Get timeline clips
    local video_tracks = timeline:GetTrackCount("video")
    for track = 1, video_tracks do
        local items = timeline:GetItemListInTrack("video", track)
        if items then
            for _, timeline_item in ipairs(items) do
                local media_pool_item = timeline_item:GetMediaPoolItem()
                if media_pool_item then
                    table.insert(working_clips, {
                        timeline_item = timeline_item,
                        media_pool_item = media_pool_item,
                        clip_name = timeline_item:GetName(),
                        context = "timeline"
                    })
                end
            end
        end
    end
elseif selected_clips and #selected_clips > 0 then
    context_type = "media_pool"
    print("Media Pool context detected with " .. #selected_clips .. " selected clips")

    -- Get media pool clips
    for _, clip in ipairs(selected_clips) do
        table.insert(working_clips, {
            timeline_item = nil,
            media_pool_item = clip,
            clip_name = clip:GetName(),
            context = "media_pool"
        })
    end
else
    print("No timeline is open and no clips are selected in Media Pool")
    return
end

print("Working with " .. #working_clips .. " clips in " .. context_type .. " context")

-- Extract functions (unchanged)
function extract_shot_name_from_path(file_path)
    local file_name = file_path:match("([^\\/]+)%.[^\\/]+$") or file_path
    local shot_name = file_name:match("([Ss][Hh][Oo][Tt]_?%d+)")
    if shot_name then
        return shot_name:upper()
    end
    shot_name = file_name:match("SEQ%d+_([Ss][Hh]%d+)")
    if shot_name then
        return shot_name:upper()
    end
    shot_name = file_name:match("([Ss][Hh]_?%d+)")
    if shot_name then
        return shot_name:upper()
    end
    shot_name = file_name:match("^(%d+)_")
    if shot_name then
        return "SH" .. shot_name
    end
    return nil
end

function extract_scene_name_from_path(file_path)
    local file_name = file_path:match("([^\\/]+)%.[^\\/]+$") or file_path
    local scene_name = file_name:match("^(.-)_[Ss][Hh]_?%d+")
    if scene_name and scene_name ~= "" then
        return scene_name
    end
    scene_name = file_name:match("^(.-)_[Ss][Hh][Oo][Tt]_?%d+")
    if scene_name and scene_name ~= "" then
        return scene_name
    end
    scene_name = file_name:match("^(.-)_[Ss][Hh]%d+")
    if scene_name and scene_name ~= "" then
        return scene_name
    end
    return nil
end

function extract_version_for_take(clip)
    local version_num, v_char, _, version_str = get_version_from_clip(clip)
    if version_num then
        return version_str
    end
    return nil
end

function find_plate_sequence_path(comp_path)
    local plate_path = comp_path:gsub("/comp/", "/plate/")
    plate_path = plate_path:gsub("_comp_", "_plate_")
    plate_path = plate_path:gsub("_v%d+", "_v000")
    return plate_path
end

function find_plate_clip_in_media_pool(comp_clip)
    local comp_path = comp_clip:GetClipProperty("File Path")
    if not comp_path then
        return nil
    end

    local plate_path = find_plate_sequence_path(comp_path)

    local function search_clips_recursive(folder)
        local clips = {}
        local folder_clips = folder:GetClipList()
        if folder_clips then
            for _, clip in ipairs(folder_clips) do
                table.insert(clips, clip)
            end
        end
        local subfolders = folder:GetSubFolderList()
        if subfolders then
            for _, subfolder in ipairs(subfolders) do
                local subfolder_clips = search_clips_recursive(subfolder)
                for _, clip in ipairs(subfolder_clips) do
                    table.insert(clips, clip)
                end
            end
        end
        return clips
    end

    local all_clips = search_clips_recursive(media_pool:GetRootFolder())

    for _, clip in ipairs(all_clips) do
        local clip_path = clip:GetClipProperty("File Path")
        if clip_path then
            if clip_path:find("plate") and clip_path:find("_v000") then
                local comp_scene = extract_scene_name_from_path(comp_path)
                local comp_shot = extract_shot_name_from_path(comp_path)
                local plate_scene = extract_scene_name_from_path(clip_path)
                local plate_shot = extract_shot_name_from_path(clip_path)

                if comp_scene == plate_scene and comp_shot == plate_shot then
                    return clip
                end
            end
        end
    end
    return nil
end

function validate_plate_duration(comp_clip, plate_clip, verbose)
    local comp_duration = comp_clip:GetClipProperty("Duration")
    local plate_duration = plate_clip:GetClipProperty("Duration")

    if verbose then
        print("Duration check:")
        print("  Comp duration: " .. tostring(comp_duration))
        print("  Plate duration: " .. tostring(plate_duration))
    end

    if comp_duration == plate_duration then
        if verbose then
            print("Duration match - safe to transfer timecode")
        end
        return true
    else
        if verbose then
            print("WARNING: Duration mismatch! Plate (" .. tostring(plate_duration) .. ") and comp (" ..
                      tostring(comp_duration) .. ") have different durations.")
            print("Skipping timecode transfer to prevent incorrect timecode.")
        end
        return false
    end
end

function get_plate_metadata(comp_clip, verbose)
    local plate_clip = find_plate_clip_in_media_pool(comp_clip)

    if plate_clip then
        if verbose then
            print("Found plate sequence: " .. plate_clip:GetName() .. " for comp: " .. comp_clip:GetName())
        end

        if not validate_plate_duration(comp_clip, plate_clip, verbose) then
            if verbose then
                print("Duration mismatch - using plate metadata but skipping")
            end
            return {}, nil
        end

        return plate_clip:GetMetadata() or {}, plate_clip
    else
        if verbose then
            print("No matching plate sequence found for: " .. comp_clip:GetName())
        end
        return {}, nil
    end
end

function compare_timecode_plate_vs_comp(comp_clip, verbose)
    if verbose then
        print("Starting timecode comparison for: " .. comp_clip:GetName())
    end

    local plate_clip = find_plate_clip_in_media_pool(comp_clip)

    if not plate_clip then
        if verbose then
            print("No plate sequence found for timecode comparison: " .. comp_clip:GetName())
        end
        return false
    end

    if verbose then
        print("Found plate clip: " .. plate_clip:GetName())
    end

    if not validate_plate_duration(comp_clip, plate_clip, false) then
        if verbose then
            print("Duration mismatch - skipping timecode comparison for: " .. comp_clip:GetName())
        end
        return false
    end

    if verbose then
        print("Durations match, comparing timecode...")
    end

    local tc_properties = {"Start TC", "End TC", "Start Timecode", "End Timecode"}
    local timecode_differs = false

    for _, prop in ipairs(tc_properties) do
        local success_comp, comp_value = pcall(function()
            return comp_clip:GetClipProperty(prop)
        end)
        local success_plate, plate_value = pcall(function()
            return plate_clip:GetClipProperty(prop)
        end)

        if verbose then
            print("Checking property: " .. prop)
            print("  Comp success: " .. tostring(success_comp) .. ", value: " .. tostring(comp_value))
            print("  Plate success: " .. tostring(success_plate) .. ", value: " .. tostring(plate_value))
        end

        if success_comp and success_plate and comp_value and plate_value and comp_value ~= "" and plate_value ~= "" then
            if comp_value ~= plate_value then
                timecode_differs = true
                if verbose then
                    print("TIMECODE DIFFERENCE FOUND!")
                    print("  " .. prop .. " - Comp: " .. comp_value .. " | Plate: " .. plate_value)
                end
                break
            else
                if verbose then
                    print("  " .. prop .. " matches: " .. comp_value)
                end
            end
        else
            if verbose then
                print("  Skipping " .. prop .. " - missing or empty values")
            end
        end
    end

    if verbose then
        print("Final result for " .. comp_clip:GetName() .. ": timecode_differs = " .. tostring(timecode_differs))
    end

    return timecode_differs
end

function update_clip_metadata(media_pool_item, verbose, use_plate_metadata, check_timecode_differences)
    local file_path = media_pool_item:GetClipProperty("File Path")
    if not file_path then
        if verbose then
            print("No file path found for clip: " .. media_pool_item:GetName())
        end
        return false
    end

    local shot_name = extract_shot_name_from_path(file_path)
    local scene_name = extract_scene_name_from_path(file_path)
    local take_version = extract_version_for_take(media_pool_item)

    local current_metadata

    if use_plate_metadata then
        local plate_metadata, plate_clip = get_plate_metadata(media_pool_item, verbose)
        if next(plate_metadata) then
            current_metadata = plate_metadata
            if verbose then
                print("Using plate metadata for: " .. media_pool_item:GetName())
            end
        else
            current_metadata = media_pool_item:GetMetadata() or {}
            if verbose then
                print("No plate found or duration mismatch, using current metadata for: " .. media_pool_item:GetName())
            end
        end
    else
        current_metadata = media_pool_item:GetMetadata() or {}
    end

    if check_timecode_differences then
        local success, has_timecode_differences = pcall(function()
            return compare_timecode_plate_vs_comp(media_pool_item, verbose)
        end)

        if success and has_timecode_differences then
            media_pool_item:SetClipColor("Brown")
            if verbose then
                print("Set clip color to BROWN due to timecode differences between plate and comp: " ..
                          media_pool_item:GetName())
            end
        elseif not success and verbose then
            print("Error checking timecode differences for: " .. media_pool_item:GetName())
        end
    end

    local metadata_to_set = {}
    for key, value in pairs(current_metadata) do
        metadata_to_set[key] = value
    end

    local updated = false

    if scene_name then
        metadata_to_set["Scene"] = scene_name
        updated = true
        if verbose then
            print("Set Scene metadata: " .. scene_name .. " for " .. media_pool_item:GetName())
        end
    end

    if shot_name then
        metadata_to_set["Shot"] = shot_name
        updated = true
        if verbose then
            print("Set Shot metadata: " .. shot_name .. " for " .. media_pool_item:GetName())
        end
    end

    if take_version then
        metadata_to_set["Take"] = take_version
        updated = true
        if verbose then
            print("Set Take metadata: " .. take_version .. " for " .. media_pool_item:GetName())
        end
    end

    if updated then
        local success = pcall(function()
            media_pool_item:SetMetadata(metadata_to_set)
        end)

        if not success and verbose then
            print("Failed to set metadata for: " .. media_pool_item:GetName())
            return false
        end
    end

    return updated
end

function get_version_from_clip(clip)
    local path = clip:GetClipProperty("File Path")
    if path then
        for v_char, version_str in string.gmatch(path, "([vV])(%d+)") do
            return tonumber(version_str), v_char, #version_str, version_str
        end
    end
    return nil
end

function modify_path_for_replacement_clip(path)
    return path:gsub("(%[)(%d+)%-(%d+)%](%.[^/\\]+)$", function(_, start_frame, _, ext)
        return start_frame .. ext
    end)
end

function assign_clip_color(clip, check_timecode_differences)
    local version_num = get_version_from_clip(clip)
    if version_num then
        if check_timecode_differences then
            local success, has_timecode_differences = pcall(function()
                return compare_timecode_plate_vs_comp(clip, false)
            end)

            if success and has_timecode_differences then
                clip:SetClipColor("Brown")
                return
            end
        end

        if version_num == 0 then
            clip:SetClipColor("Apricot")
        else
            clip:SetClipColor("Violet")
        end
    end
end

function set_version_on_clip(clip_data, version_num, verbose, use_plate_metadata, check_timecode_differences)
    local media_pool_item = clip_data.media_pool_item

    if verbose then
        print("Processing " .. clip_data.context .. " clip: " .. clip_data.clip_name)
    end

    local path = media_pool_item:GetClipProperty("File Path")
    if not path then
        if verbose then
            print("No file path found for clip")
        end
        return false
    end

    local curr_version, v_char, version_length, version_str = get_version_from_clip(media_pool_item)
    if not curr_version then
        if verbose then
            print("No version found in file path")
        end
        return false
    end

    local new_version_str = v_char .. string.format("%0" .. tostring(version_length) .. "d", version_num)
    local new_path = modify_path_for_replacement_clip(string.gsub(path, v_char .. version_str, new_version_str))

    if verbose then
        print(clip_data.context:upper() .. " Context Replacement:")
        print("  Current path: " .. path)
        print("  New path: " .. new_path)
        print("  Version: " .. curr_version .. " -> " .. version_num)
    end

    local success = media_pool_item:ReplaceClip(new_path)

    if success then
        local new_name = new_path:match("([^\\/]+)%.[^\\/]+$"):gsub("%[.*%]", "")
        media_pool_item:SetClipProperty("Clip Name", new_name:gsub("[_%.]%d+$", ""))
        assign_clip_color(media_pool_item, check_timecode_differences)
        update_clip_metadata(media_pool_item, verbose, use_plate_metadata, check_timecode_differences)

        if verbose then
            print("SUCCESS: Clip updated to version: " .. version_num .. " -> " .. new_name)
        end
    elseif verbose then
        print("FAILED: Could not switch clip to: " .. new_path)
    end

    return success
end

function get_available_versions_for_clip(clip_data)
    local media_pool_item = clip_data.media_pool_item
    local original_version, v_char, version_length, version_str = get_version_from_clip(media_pool_item)
    if not original_version then
        return {}
    end

    local versions, checked = {}, {}
    local path = media_pool_item:GetClipProperty("File Path")

    for offset = 0, 50 do
        for _, dir in ipairs({1, -1}) do
            local v = original_version + offset * dir
            if v >= 0 and not checked[v] then
                checked[v] = true
                local new_version_str = v_char .. string.format("%0" .. version_length .. "d", v)
                local test_path = modify_path_for_replacement_clip(
                    string.gsub(path, v_char .. version_str, new_version_str))
                local file = io.open(test_path, "r")
                if file then
                    file:close()
                    table.insert(versions, v)
                end
            end
        end
    end
    table.sort(versions)
    return versions
end

-- Initialize clip version cache and index
local clip_version_cache = {}
local clip_version_index = {}
local NUM_NONCONSECUTIVE_FALLBACK = 10

for _, clip_data in ipairs(working_clips) do
    local versions = get_available_versions_for_clip(clip_data)
    clip_version_cache[clip_data] = versions
    local current_version = get_version_from_clip(clip_data.media_pool_item)
    local index = 1
    for i, v in ipairs(versions) do
        if v == current_version then
            index = i;
            break
        end
    end
    clip_version_index[clip_data] = index
    assign_clip_color(clip_data.media_pool_item, false)
end

function max_version_on_clip(clip_data, verbose, use_plate_metadata, check_timecode_differences)
    local versions = clip_version_cache[clip_data]
    if not versions or #versions == 0 then
        return nil
    end

    local max_cached = versions[#versions]
    if set_version_on_clip(clip_data, max_cached, verbose, use_plate_metadata, check_timecode_differences) then
        clip_version_index[clip_data] = #versions
        return max_cached
    end

    local _, v_char, version_length, version_str = get_version_from_clip(clip_data.media_pool_item)
    local path = clip_data.media_pool_item:GetClipProperty("File Path")
    local fallback = max_cached + 1
    local failures = 0
    while failures < NUM_NONCONSECUTIVE_FALLBACK do
        local candidate_str = v_char .. string.format("%0" .. version_length .. "d", fallback)
        local test_path = modify_path_for_replacement_clip(string.gsub(path, v_char .. version_str, candidate_str))
        local file = io.open(test_path, "r")
        if file then
            file:close()
            if set_version_on_clip(clip_data, fallback, verbose, use_plate_metadata, check_timecode_differences) then
                table.insert(clip_version_cache[clip_data], fallback)
                clip_version_index[clip_data] = #clip_version_cache[clip_data]
                return fallback
            end
            failures = 0
        else
            failures = failures + 1
        end
        fallback = fallback + 1
    end
    return nil
end

function min_version_on_clip(clip_data, verbose, use_plate_metadata, check_timecode_differences)
    local versions = clip_version_cache[clip_data]
    if not versions or #versions == 0 then
        return nil
    end

    local min_version = versions[1]
    if set_version_on_clip(clip_data, min_version, verbose, use_plate_metadata, check_timecode_differences) then
        clip_version_index[clip_data] = 1
        return min_version
    end
    return nil
end

function get_version_report(clips)
    local report_lines = {}
    for _, clip_data in ipairs(clips) do
        local media_pool_item = clip_data.media_pool_item

        local version_num, _, _, version_str = get_version_from_clip(media_pool_item)
        if version_num then
            local color_indicator = version_num == 0 and " (Apricot)" or " (Violet)"

            local success, has_tc_diff = pcall(function()
                return compare_timecode_plate_vs_comp(media_pool_item, false)
            end)

            if success and has_tc_diff then
                color_indicator = " (Brown - TC Diff)"
            end

            local metadata = media_pool_item:GetMetadata() or {}
            local shot_meta = metadata["Shot"] or "No Shot"
            local scene_meta = metadata["Scene"] or "No Scene"
            local take_meta = metadata["Take"] or "No Take"

            local clip_display = clip_data.context == "timeline" and
                                     string.format("Timeline: %s | MediaPool: %s", clip_data.timeline_item:GetName(),
                    media_pool_item:GetName()) or string.format("MediaPool: %s", media_pool_item:GetName())

            table.insert(report_lines,
                string.format("%s\n  Current Version: %s%s\n  Scene: %s | Shot: %s | Take: %s", clip_display,
                    version_str, color_indicator, scene_meta, shot_meta, take_meta))

            local versions = clip_version_cache[clip_data]
            if #versions > 0 then
                table.insert(report_lines, "  Available Versions: " .. table.concat(versions, ", "))
            end
        end
    end
    return table.concat(report_lines, "\n")
end

function get_simplified_report(clips)
    local clip_count = #clips
    local versioned_clips = 0
    local apricot_clips = 0
    local violet_clips = 0
    local brown_clips = 0
    local clips_with_shot = 0
    local clips_with_scene = 0
    local clips_with_take = 0

    for _, clip_data in ipairs(clips) do
        local media_pool_item = clip_data.media_pool_item
        local version_num = get_version_from_clip(media_pool_item)
        if version_num then
            versioned_clips = versioned_clips + 1

            local success, has_tc_diff = pcall(function()
                return compare_timecode_plate_vs_comp(media_pool_item, false)
            end)

            if success and has_tc_diff then
                brown_clips = brown_clips + 1
            elseif version_num == 0 then
                apricot_clips = apricot_clips + 1
            else
                violet_clips = violet_clips + 1
            end
        end

        local metadata = media_pool_item:GetMetadata() or {}
        local shot_meta = metadata["Shot"]
        local scene_meta = metadata["Scene"]
        local take_meta = metadata["Take"]
        if shot_meta and shot_meta ~= "" then
            clips_with_shot = clips_with_shot + 1
        end
        if scene_meta and scene_meta ~= "" then
            clips_with_scene = clips_with_scene + 1
        end
        if take_meta and take_meta ~= "" then
            clips_with_take = clips_with_take + 1
        end
    end

    return string.format(
        "%s Clips: %d\nVersioned Clips: %d\nApricot (v000): %d | Violet (v001+): %d | Brown (TC Diff): %d\nWith Scene: %d | Shot: %d | Take: %d",
        context_type:upper(), clip_count, versioned_clips, apricot_clips, violet_clips, brown_clips, clips_with_scene,
        clips_with_shot, clips_with_take)
end

-- Create UI based on context and clip count
local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)

local use_simplified_gui = #working_clips > 10
local width, height = 450, 485

local window_title
if context_type == "timeline" then
    window_title = "Version Control v2.3 - Timeline Mode" .. (use_simplified_gui and " (Simplified)" or " (Detailed)")
else
    window_title = "Version Control v2.3 - Media Pool Mode" .. (use_simplified_gui and " (Simplified)" or " (Detailed)")
end

local window_content
if use_simplified_gui then
    window_content = ui:VGroup{ui:Label{
        ID = "labeltext",
        Text = get_simplified_report(working_clips)
    }, ui:CheckBox{
        ID = "usePlateMetadata",
        Text = "Use plate metadata (duration match required)",
        Checked = true
    }, ui:CheckBox{
        ID = "checkTimecodeChanges",
        Text = "Check plate vs comp timecode (brown if different)",
        Checked = true
    }, ui:HGroup{ui:Button{
        ID = "versionDownButton",
        Text = "Version Down"
    }, ui:Button{
        ID = "versionUpButton",
        Text = "Version Up"
    }}, ui:Button{
        ID = "maxVersionButton",
        Text = "Maximize Version"
    }, ui:Button{
        ID = "minVersionButton",
        Text = "Minimize Version"
    }, ui:Button{
        ID = "refreshColorsButton",
        Text = "Refresh Colors"
    }, ui:Button{
        ID = "closeButton",
        Text = "Close"
    }}
else
    window_content = ui:VGroup{ui:Label{
        ID = "labeltext",
        Text = context_type:upper() .. " Clips\n" .. get_version_report(working_clips)
    }, ui:CheckBox{
        ID = "usePlateMetadata",
        Text = "Use plate metadata (duration match required)",
        Checked = true
    }, ui:CheckBox{
        ID = "checkTimecodeChanges",
        Text = "Check plate vs comp timecode (brown if different)",
        Checked = true
    }, ui:HGroup{ui:Button{
        ID = "versionDownButton",
        Text = "Version Down"
    }, ui:Button{
        ID = "versionUpButton",
        Text = "Version Up"
    }}, ui:Button{
        ID = "maxVersionButton",
        Text = "Maximize Version"
    }, ui:Button{
        ID = "minVersionButton",
        Text = "Minimize Version"
    }, ui:Button{
        ID = "refreshColorsButton",
        Text = "Refresh Colors"
    }, ui:Button{
        ID = "closeButton",
        Text = "Close"
    }}
end

local win = disp:AddWindow({
    ID = "MyWin",
    WindowTitle = window_title,
    Geometry = {100, 100, width, height},
    window_content
})

local itm = win:GetItems()

function win.On.MyWin.Close()
    disp:ExitLoop()
end
function win.On.closeButton.Clicked()
    disp:ExitLoop()
end

function win.On.refreshColorsButton.Clicked()
    local check_timecode = itm.checkTimecodeChanges.Checked

    for _, clip_data in ipairs(working_clips) do
        assign_clip_color(clip_data.media_pool_item, check_timecode)
    end

    if use_simplified_gui then
        itm.labeltext.Text = get_simplified_report(working_clips)
    else
        itm.labeltext.Text = context_type:upper() .. " Clips\n" .. get_version_report(working_clips)
    end
    itm.labeltext:Update()
    print("Colors refreshed for all " .. context_type .. " clips")
end

function win.On.maxVersionButton.Clicked()
    local use_plate = itm.usePlateMetadata.Checked
    local check_timecode = itm.checkTimecodeChanges.Checked

    for _, clip_data in ipairs(working_clips) do
        max_version_on_clip(clip_data, true, use_plate, check_timecode)
    end

    if use_simplified_gui then
        itm.labeltext.Text = get_simplified_report(working_clips)
    else
        itm.labeltext.Text = context_type:upper() .. " Clips\n" .. get_version_report(working_clips)
    end
    itm.labeltext:Update()
end

function win.On.minVersionButton.Clicked()
    local use_plate = itm.usePlateMetadata.Checked
    local check_timecode = itm.checkTimecodeChanges.Checked

    for _, clip_data in ipairs(working_clips) do
        min_version_on_clip(clip_data, true, use_plate, check_timecode)
    end

    if use_simplified_gui then
        itm.labeltext.Text = get_simplified_report(working_clips)
    else
        itm.labeltext.Text = context_type:upper() .. " Clips\n" .. get_version_report(working_clips)
    end
    itm.labeltext:Update()
end

function win.On.versionUpButton.Clicked()
    local use_plate = itm.usePlateMetadata.Checked
    local check_timecode = itm.checkTimecodeChanges.Checked

    for _, clip_data in ipairs(working_clips) do
        local versions = clip_version_cache[clip_data]
        local index = clip_version_index[clip_data]
        if versions and index < #versions then
            index = index + 1
            local new_version = versions[index]
            if set_version_on_clip(clip_data, new_version, true, use_plate, check_timecode) then
                clip_version_index[clip_data] = index
            end
        end
    end

    if use_simplified_gui then
        itm.labeltext.Text = get_simplified_report(working_clips)
    else
        itm.labeltext.Text = context_type:upper() .. " Clips\n" .. get_version_report(working_clips)
    end
    itm.labeltext:Update()
end

function win.On.versionDownButton.Clicked()
    local use_plate = itm.usePlateMetadata.Checked
    local check_timecode = itm.checkTimecodeChanges.Checked

    for _, clip_data in ipairs(working_clips) do
        local versions = clip_version_cache[clip_data]
        local index = clip_version_index[clip_data]
        if versions and index > 1 then
            index = index - 1
            local new_version = versions[index]
            if set_version_on_clip(clip_data, new_version, true, use_plate, check_timecode) then
                clip_version_index[clip_data] = index
            end
        end
    end

    if use_simplified_gui then
        itm.labeltext.Text = get_simplified_report(working_clips)
    else
        itm.labeltext.Text = context_type:upper() .. " Clips\n" .. get_version_report(working_clips)
    end
    itm.labeltext:Update()
end

win:Show()
disp:RunLoop()
win:Hide()

print(context_type:upper() .. "-based version control completed")
