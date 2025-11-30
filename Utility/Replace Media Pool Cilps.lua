--
-- For each clip within the current project's media pool, replaces the clip with the same clip's file path.
-- This has the effect of getting resolve to refresh some properties it isn't correctly reading.
--
function print_table(t)
    for k, v in pairs(t) do
        print(k, ": ", v)
    end
end

function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

missing_files = {}
replace_audio_clips = false
replace_video_clips = false

metadata_to_save = {"Clip Color", "PAR"}

function traverse_clips(mediaPool, folder, dry_run)
    for i, clip in pairs(folder:GetClipList()) do
        if i ~= "__flags" then
            file_path = clip:GetClipProperty("File Path")
            clip_name = clip:GetName()
            local clip_type = clip:GetClipProperty("Type")

            local filter = (replace_audio_clips and clip_type:find("Audio")) or
                               (replace_video_clips and clip_type:find("Video"))

            if file_path ~= nil and file_path ~= "" and filter then
                print("\nCurr clip: ", clip_name)
                print("File path: ", file_path)
                print("Type: ", clip:GetClipProperty("Type"))
                print_table(clip:GetClipProperty())

                if dry_run == false then
                    -- replace the clip.
                    print("Replacing clip with same file path...")
                    local success = clip:ReplaceClip(file_path)
                    assert(success, string.format("Could not replace clip %s at %s", clip_name, file_path))
                else
                    if file_path == nil or not file_exists(file_path) then
                        print("Could not find file: ", file_path)
                        table.insert(missing_files, file_path)
                    else
                        print("File OK")
                    end
                end
            end
        end
    end
    for i, subfolder in pairs(folder:GetSubFolderList()) do
        if i ~= "__flags" then
            traverse_clips(mediaPool, subfolder, dry_run)
        end
    end
end

function traverse_folders(project)
    print("Now in project: ", project:GetName())
    mediaPool = project:GetMediaPool()
    folder = mediaPool:GetRootFolder()

    -- If there are any missing files, we better not actually run this for this project.
    traverse_clips(mediaPool, folder, true)
    if #missing_files > 0 then
        print(string.format("Project '%s' had files that likely will not be replaced.", project:GetName()))
        print_table(missing_files)
        assert(false, "Missing files.")
    end
    if itm.backedup.Checked then
        -- Actually replace clips for this project.
        traverse_clips(mediaPool, folder, false)
    end
end

-- Draw window to get user parameters.
local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)
local width, height = 500, 300

resolve = Resolve()
projectManager = resolve:GetProjectManager()
curr_database = projectManager:GetCurrentDatabase()['DbName']

win = disp:AddWindow({
    ID = 'MyWin',
    WindowTitle = 'Clip Replacer',
    Geometry = {100, 100, width, height},
    Spacing = 10,
    ui:VGroup{
        ID = 'root',
        ui:HGroup{
            ID = 'audio',
            ui:Label{
                ID = 'AudioLabel',
                Text = 'Replace audio-only clips'
            },
            ui:CheckBox{
                ID = 'ReplaceAudio',
                Text = '',
                Checked = 0
            }
        },
        ui:HGroup{
            ID = 'video',
            ui:Label{
                ID = 'VideoLabel',
                Text = 'Replace Video clips'
            },
            ui:CheckBox{
                ID = 'ReplaceVideo',
                Text = '',
                Checked = 0
            }
        },
        ui:CheckBox{
            ID = 'backedup',
            Text = string.format('I backed up this project.'),
            Checked = 0
        },
        ui:HGroup{
            ID = 'buttons',
            ui:Button{
                ID = 'cancelButton',
                Text = 'Cancel'
            },
            ui:Button{
                ID = 'goButton',
                Text = 'Go'
            }
        }
    }
})

run_replace_clip = false

-- The window was closed
function win.On.MyWin.Close(ev)
    disp:ExitLoop()
    run_replace_clip = false
end

function win.On.cancelButton.Clicked(ev)
    print('Cancel Clicked')
    disp:ExitLoop()
    run_replace_clip = false
end

function win.On.goButton.Clicked(ev)
    print('Go Clicked')
    disp:ExitLoop()
    run_replace_clip = true
end

-- Add your GUI element based event functions here:
itm = win:GetItems()

win:Show()
disp:RunLoop()
win:Hide()

if run_replace_clip then
    replace_audio_clips = itm.ReplaceAudio.Checked
    replace_video_clips = itm.ReplaceVideo.Checked
    curr_project = projectManager:GetCurrentProject()
    traverse_folders(curr_project)
    print("Done!")
end
