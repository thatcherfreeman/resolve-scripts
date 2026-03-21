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

-- Function to recursively get all clips from media pool folders
function getAllClipsFromFolder(folder, clips_table)
    -- Get clips in current folder
    local clip_list = folder:GetClipList()
    if clip_list then
        for _, clip in pairs(clip_list) do
            if clip ~= nil and type(clip) ~= "number" then
                local clip_name = clip:GetName()
                if clip_name then
                    clips_table[clip_name] = clip
                end
            end
        end
    end

    -- Recursively process subfolders
    local subfolders = folder:GetSubFolderList()
    if subfolders then
        for _, subfolder in pairs(subfolders) do
            if subfolder ~= nil and type(subfolder) ~= "number" then
                getAllClipsFromFolder(subfolder, clips_table)
            end
        end
    end
end

-- Function to extract clip names from XML content
function extractClipNamesFromXML(xml_content)
    local clip_names = {}
    -- Pattern to match <name>filename</name>
    for clip_name in string.gmatch(xml_content, "<name>([^<]+)</name>") do
        clip_names[#clip_names + 1] = clip_name
        print("Found clip name in XML:", clip_name)
    end
    return clip_names
end

-- Function to read file content
function readFile(file_path)
    local file = io.open(file_path, "r")
    if not file then
        return nil, "Could not open file: " .. file_path
    end

    local content = file:read("*all")
    file:close()
    return content, nil
end

-- Draw window to get user parameters.
local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)
local width, height = 400, 250

win = disp:AddWindow({
    ID = "MyWin",
    WindowTitle = "Gather Clips from XML",
    Geometry = {100, 100, width, height},
    Spacing = 10,
    ui:VGroup{
        ID = "root",
        ui:HGroup{
            ID = "timelineName",
            ui:Label{
                ID = "TimelineLabel",
                Text = "Timeline Name:"
            },
            ui:TextEdit{
                ID = "TimelineName",
                Text = "",
                PlaceholderText = "New Timeline"
            }
        },
        ui:HGroup{
            ID = "xmlPath",
            ui:Label{
                ID = "XMLLabel",
                Text = "XML File Path:"
            },
            ui:TextEdit{
                ID = "XMLPath",
                Text = "",
                PlaceholderText = "/path/to/file.xml"
            }
        },
        ui:CheckBox{
            ID = "useCurrentTimeline",
            Text = "Add to current timeline (instead of creating new)",
            Checked = false
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

win:Show()
disp:RunLoop()
win:Hide()

if run_export then
    local timeline_name = itm.TimelineName.PlainText
    local xml_path = itm.XMLPath.PlainText
    local use_current_timeline = itm.useCurrentTimeline.Checked

    -- Validate inputs
    if not use_current_timeline and (timeline_name == nil or timeline_name == "") then
        print("Error: Timeline name cannot be empty when creating a new timeline!")
        return
    end

    if xml_path == nil or xml_path == "" then
        print("Error: XML file path cannot be empty!")
        return
    end

    print("XML Path:", xml_path)
    print("Use current timeline:", use_current_timeline)

    -- Get Resolve objects
    resolve = Resolve()
    projectManager = resolve:GetProjectManager()
    project = projectManager:GetCurrentProject()
    media_pool = project:GetMediaPool()

    -- Step 1: Handle timeline selection
    local target_timeline
    if use_current_timeline then
        target_timeline = project:GetCurrentTimeline()
        if not target_timeline then
            print("Error: No current timeline found!")
            return
        end
        print("Using current timeline:", target_timeline:GetName())
    else
        print("Creating new timeline:", timeline_name)
        target_timeline = media_pool:CreateEmptyTimeline(timeline_name)
        if not target_timeline then
            print("Error: Failed to create timeline!")
            return
        end

        -- Set the new timeline as current
        if not project:SetCurrentTimeline(target_timeline) then
            print("Error: Failed to set current timeline!")
            return
        end
    end

    -- Step 2: Get all clips from media pool (including subfolders)
    print("Reading all clips from media pool...")
    local media_pool_clips = {}
    local root_folder = media_pool:GetRootFolder()
    getAllClipsFromFolder(root_folder, media_pool_clips)

    print_table(media_pool_clips)
    print("Found ", #media_pool_clips, " clips in media pool")

    -- Step 3: Read XML file
    print("Reading XML file...")
    local xml_content, error_msg = readFile(xml_path)
    if not xml_content then
        print("Error reading XML file:", error_msg)
        return
    end

    -- Step 4: Extract clip names from XML
    print("Extracting clip names from XML...")
    local xml_clip_names = extractClipNamesFromXML(xml_content)
    print("Found", #xml_clip_names, "clip references in XML")

    -- Step 5: Match clips and add to timeline
    print("Matching clips and adding to timeline...")
    local matched_clips = {}
    local added_count = 0

    for _, xml_clip_name in pairs(xml_clip_names) do
        if media_pool_clips[xml_clip_name] then
            -- Only add if not already added (avoid duplicates)
            if not matched_clips[xml_clip_name] then
                matched_clips[xml_clip_name] = true
                local mediaPoolItem = media_pool_clips[xml_clip_name]
                print("Adding clip to timeline:", xml_clip_name, mediaPoolItem)
                local result = media_pool:AppendToTimeline(mediaPoolItem)
                print_table(result)
                if result then
                    added_count = added_count + 1
                    print("Added clip:", xml_clip_name)
                else
                    print("Failed to add clip:", xml_clip_name)
                end
            end
        else
            print("Clip not found in media pool:", xml_clip_name)
        end
    end

    print("Process completed!")
    if use_current_timeline then
        print("Added", added_count, "clips to current timeline:", target_timeline:GetName())
    else
        print("Added", added_count, "clips to new timeline:", timeline_name)
    end
end
