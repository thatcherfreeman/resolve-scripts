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
local width, height = 500, 400 -- Increased height to ensure all elements are visible

local is_windows = package.config:sub(1, 1) ~= "/"

win = disp:AddWindow({
    ID = "MyWin",
    WindowTitle = "Rename Timelines",
    Geometry = {100, 100, width, height},
    Spacing = 10,
    ui:VGroup{
        ID = "root",
        ui:HGroup{
            ID = "prefix",
            ui:Label{
                ID = "PrefixLabel",
                Text = "Add Prefix"
            },
            ui:TextEdit{
                ID = "PrefixText",
                Text = "",
                PlaceholderText = "prefix"
            }
        },
        ui:HGroup{
            ID = "find",
            ui:Label{
                ID = "FindLabel",
                Text = "Find String"
            },
            ui:TextEdit{
                ID = "FindText",
                Text = "",
                PlaceholderText = "find"
            }
        },
        ui:HGroup{
            ID = "replace",
            ui:Label{
                ID = "ReplaceLabel",
                Text = "Replace String"
            },
            ui:TextEdit{
                ID = "ReplaceText",
                Text = "",
                PlaceholderText = "replace"
            }
        },
        ui:HGroup{
            ID = "suffix",
            ui:Label{
                ID = "SuffixLabel",
                Text = "Add Suffix"
            },
            ui:TextEdit{
                ID = "SuffixText",
                Text = "",
                PlaceholderText = "suffix"
            }
        },
        ui:HGroup{
            ID = "buttons",
            ui:Button{
                ID = "cancelButton",
                Text = "Cancel"
            },
            ui:Button{
                ID = "goButton",
                Text = "Replace"
            }
        }
    }
})

-- Add your GUI element based event functions here:
itm = win:GetItems()

-- The window was closed
function win.On.MyWin.Close(ev)
    disp:ExitLoop()
end

function win.On.cancelButton.Clicked(ev)
    print("Cancel Clicked")
    disp:ExitLoop()
end

function win.On.goButton.Clicked(ev)
    print("Go Clicked")
    -- Get text from all fields
    find_text = itm.FindText.PlainText
    replace_text = itm.ReplaceText.PlainText
    prefix_text = itm.PrefixText.PlainText
    suffix_text = itm.SuffixText.PlainText

    -- Get timelines
    resolve = Resolve()
    projectManager = resolve:GetProjectManager()
    project = projectManager:GetCurrentProject()
    media_pool = project:GetMediaPool()
    num_timelines = project:GetTimelineCount()
    selected_bin = media_pool:GetCurrentFolder()

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

            -- Apply find and replace if find_text is not empty
            new_name = curr_name
            if find_text ~= "" then
                new_name = string.gsub(new_name, find_text, replace_text)
            end

            -- Apply prefix if specified
            if prefix_text ~= "" then
                new_name = prefix_text .. new_name
            end

            -- Apply suffix if specified
            if suffix_text ~= "" then
                new_name = new_name .. suffix_text
            end

            -- Only rename if the name has changed
            if curr_name ~= new_name then
                curr_timeline:SetName(new_name)
                print("Renaming Timeline: ", curr_name, " --> ", new_name)
            end
        end
    end

    print("Done!")
end

win:Show()
disp:RunLoop()
win:Hide()
