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
local width, height = 500, 200

local is_windows = package.config:sub(1, 1) ~= "/"

win = disp:AddWindow({
    ID = "MyWin",
    WindowTitle = "Rename Clips",
    Geometry = {100, 100, width, height},
    Spacing = 10,
    ui:VGroup{
        ID = "root",
        ui:HGroup{
            ID = "dst",
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
            ID = "dst",
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
    -- disp:ExitLoop()
    assert(itm.FindText.PlainText ~= nil and itm.FindText.PlainText ~= "",
        "Found empty New Timeline Name! Refusing to run")
    find_text = itm.FindText.PlainText
    replace_text = itm.ReplaceText.PlainText

    -- Get clips in current bin
    resolve = Resolve()
    projectManager = resolve:GetProjectManager()
    project = projectManager:GetCurrentProject()
    media_pool = project:GetMediaPool()
    num_timelines = project:GetTimelineCount()
    selected_bin = media_pool:GetCurrentFolder()

    -- Iterate through timelines in the current folder.
    for _, media_pool_item in pairs(selected_bin:GetClipList()) do
        -- Check if it's a timeline
        if type(media_pool_item) == nil or type(media_pool_item) == "number" then
            print("Skipping", media_pool_item)
        elseif media_pool_item:GetClipProperty("Type") ~= "Timeline" then
            curr_item_name = media_pool_item:GetClipProperty("Clip Name")
            new_name = string.gsub(curr_item_name, find_text, replace_text)
            if curr_item_name ~= new_name then
                media_pool_item:SetClipProperty("Clip Name", new_name)
                print("Renaming Clip: ", curr_item_name, " --> ", new_name)
            end
        end
    end

    print("Done!")
end

win:Show()
disp:RunLoop()
win:Hide()
