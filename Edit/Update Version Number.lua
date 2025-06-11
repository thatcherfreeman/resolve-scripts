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

function get_version_from_clip(clip)
    local path = clip:GetClipProperty("File Path")
    if path then
        local matches = {}
        for v_char, version_str in string.gmatch(path, "([vV])(%d+)") do
            table.insert(matches, {
                v_char = v_char,
                version_str = version_str
            })
        end
        if #matches > 0 then
            local version_str = matches[1].version_str
            for i = 2, #matches do
                assert(matches[i].version_str == version_str, "Multiple version strings found and they differ!")
            end
            return tonumber(version_str), matches[1].v_char, #version_str, version_str
        end
    end
    return nil
end

function get_available_versions_for_clip(clip)
    local original_version, v_char, version_length, version_str = get_version_from_clip(clip)
    if not original_version then
        return {}
    end

    local versions = {}
    -- Traverse forwards from original_version
    local v = original_version
    while set_version_on_clip(clip, v, false) do
        table.insert(versions, v)
        v = v + 1
    end

    -- Traverse backwards from original_version - 1
    v = original_version - 1
    while v >= 0 and set_version_on_clip(clip, v, false) do
        table.insert(versions, v)
        v = v - 1
    end

    -- Sort versions in ascending order
    table.sort(versions)

    -- Restore original version
    set_version_on_clip(clip, original_version)
    return versions
end

function modify_path_for_replacement_clip(clip_path)
    -- Image sequences will have a "file path" attribute looks something like
    -- sequence_v00002/sample_sequence[0000-0005].jpg

    -- We need to replace this with the path for the first image in the sequence.
    -- sequence_v00002/sample_sequence0000.jpg

    -- Replace [xxxx-yyyy] with the starting frame number, keeping padding and extension
    local new_path = clip_path:gsub("(%[)(%d+)%-(%d+)%](%.[^/\\]+)$",
        function(open_bracket, start_frame, end_frame, ext)
            return start_frame .. ext
        end)
    return new_path
end

function set_version_on_clip(clip, version_num, verbose)
    local path = clip:GetClipProperty("File Path")
    local successful = false

    if verbose then
        print("Attempting to set version on clip: " .. clip:GetName() .. " to version: " .. tostring(version_num))
        print("Current path: " .. (path or "nil"))
    end

    if path then
        local curr_version_num, v_char, version_length, version_str = get_version_from_clip(clip)
        if curr_version_num then
            local new_version_str = v_char .. string.format("%0" .. tostring(version_length) .. "d", version_num)
            local new_path = modify_path_for_replacement_clip(string.gsub(path, v_char .. version_str, new_version_str))
            successful = clip:ReplaceClip(new_path)
            if verbose then
                print("New path: " .. new_path)
                if clip:GetClipProperty("File Path") == new_path then
                    print("Successfully set version on clip: " .. clip:GetName())
                else
                    print("Failed to set version on clip: " .. clip:GetName())
                end
            end
        end
    end
    return successful
end

function max_version_on_clip(clip, verbose)
    local curr_version, v_char, version_length, version_str = get_version_from_clip(clip)
    if not curr_version then
        return nil
    end
    local max_version = curr_version
    while true do
        local next_version = max_version + 1
        if set_version_on_clip(clip, next_version, verbose) then
            max_version = next_version
        else
            break
        end
    end
    set_version_on_clip(clip, max_version)
    return max_version
end

-- Get all selected media pool items
resolve = Resolve()
projectManager = resolve:GetProjectManager()
project = projectManager:GetCurrentProject()
media_pool = project:GetMediaPool()
selected_clips = media_pool:GetSelectedClips()

-- Get readout of selected clips and their current versions.
-- Start by getting mapping from selected clip to path.

function get_version_report(selected_clips)
    version_report_lines = {}
    for i, clip in ipairs(selected_clips) do
        local version_num, _, _, version_str = get_version_from_clip(clip)
        if version_num then
            table.insert(version_report_lines,
                string.format("Clip: %s\n  Current Version: %s", clip:GetName(), version_str))
            local available_versions = get_available_versions_for_clip(clip)
            if #available_versions > 0 then
                table.insert(version_report_lines, "  Available Versions: " .. table.concat(available_versions, ", "))
            end
        end
    end
    version_report = table.concat(version_report_lines, "\n")
    print("Version Report:\n" .. version_report)
    return version_report
end

-- Draw window to get user parameters.
local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)
local width, height = 500, 400 -- Increased height to ensure all elements are visible

if (selected_clips == nil or #selected_clips == 0) then
    local noClipsWin = disp:AddWindow({
        ID = "NoClipsWin",
        WindowTitle = "Error",
        Geometry = {400, 100, 400, 100},
        ui:VGroup{ui:Label{
            ID = "noClipsLabel",
            Text = "No clips selected.\nPlease select clips in the Media Pool."
        }, ui:Button{
            ID = "closeNoClipsButton",
            Text = "Close"
        }}
    })

    function noClipsWin.On.NoClipsWin.Close(ev)
        disp:ExitLoop()
    end

    function noClipsWin.On.closeNoClipsButton.Clicked(ev)
        disp:ExitLoop()
    end

    noClipsWin:Show()
    disp:RunLoop()
    noClipsWin:Hide()
    return
end

local is_windows = package.config:sub(1, 1) ~= "/"
local win = disp:AddWindow({
    ID = "MyWin",
    WindowTitle = "Update Version Numbers",
    Geometry = {100, 33, width, height},
    Spacing = 10,
    ui:HGroup{
        ID = "root",
        ui:HGroup{
            ID = "label",
            ui:Label{
                ID = "labeltext",
                Text = "Identified Clips\n" .. get_version_report(selected_clips)
            }
        },
        ui:VGroup{ui:HGroup{
            ID = "version_specify",
            ui:Label{
                ID = "Set Version",
                Text = "Set Version Number"
            },
            ui:TextEdit{
                ID = "SetVersionText",
                Text = "",
                PlaceholderText = "1"
            }
        }, ui:Button{
            ID = "setVersionButton",
            Text = "Set Specified Version"
        }, ui:Button{
            ID = "maxVersionButton",
            Text = "Maximize Version"
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

function win.On.setVersionButton.Clicked(ev)
    local target_version = tonumber(itm.SetVersionText.PlainText)

    for i, clip in ipairs(selected_clips) do
        if target_version then
            if set_version_on_clip(clip, target_version, true) then
                print("Set version on clip: " .. clip:GetName() .. " to " .. target_version)
            else
                print("Failed to set version on clip: " .. clip:GetName())
            end
        else
            print("Invalid version number specified.")
        end
    end
    itm.labeltext.Text = "Identified Clips\n" .. get_version_report(selected_clips)
    itm.labeltext:Update()
    print("Done!")
end

function win.On.maxVersionButton.Clicked(ev)
    for i, clip in ipairs(selected_clips) do
        local max_version = max_version_on_clip(clip, true)
        if max_version then
            print("Maximized version on clip: " .. clip:GetName() .. " to " .. max_version)
        else
            print("Failed to maximize version on clip: " .. clip:GetName())
        end
    end
    itm.labeltext.Text = "Identified Clips\n" .. get_version_report(selected_clips)
    itm.labeltext:Update()
    print("Done!")
end

win:Show()
disp:RunLoop()
win:Hide()
