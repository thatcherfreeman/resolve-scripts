--
-- For each project, replace all clips with a certain filename prefix to a new prefix.
-- To use this, use the following steps:
-- 1. Copy the folder with all your footage to a new location.
-- 2. In the Project manager, make sure there is a folder that contains only projects whose clips are ALL in the folder from step 1.
-- 3. Run this script. In the first box, indicate the OLD path, ending with the appropriate slash (mac) or backslash (windows)
-- 4. In the second box, indicate the NEW folder. Make sure that if what's written in the first box is substituted for what's in the second box, the clips will all still exist!
-- 5. BACK UP YOUR PROJECT DATABASE
-- 6. Run once with the "I backed up my project database" box unchecked. This will do a dry run.
-- 7. Check the console after the dry run to make sure that it got through all your projects without having difficulty finding a file.
-- 8. Run the script again with the checkbox checked.
-- 9. Cross your fingers.
--
function print_table(t)
    for k, v in pairs(t) do
        print(k, ": ", v)
    end
end

function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
 end

old_prefix = ""
new_prefix = ""

missing_files = {}

function traverse_clips(mediaPool, folder, dry_run)
    for i, clip in pairs(folder:GetClipList()) do
        if i ~= "__flags" then
            file_path = clip:GetClipProperty("File Path")
            if file_path ~= nil and file_path ~= "" then
                print("\nCurr clip: ", clip:GetName())
                print("File path: ", clip:GetClipProperty("File Path"))
                suffix = string.match(file_path, string.format("^%s(.*)", old_prefix))
                fn = clip:GetName()
                new_fn = string.format("%s%s", new_prefix, suffix)
                new_dir = string.match(new_fn, string.format("^(.+)%s$", fn))

                if suffix == nil then
                    -- Let's check if the file_path starts with the new_prefix.
                    suffix = string.match(file_path, string.format("^%s(.*)", new_prefix))
                    new_fn = string.format("%s%s", new_prefix, suffix)
                    new_dir = string.match(new_fn, string.format("^(.+)%s$", fn))

                    if suffix ~= nil then
                        print("Appears to already be linked.")
                    end
                end

                if new_dir == nil then
                    -- Probably the file didn't match the old prefix or the new prefix.
                    print("Couldn't match file path: ", file_path)
                end

                print("New File path: ", new_dir)

                if dry_run == false then
                    -- Relink the clip.
                    print("Relinking...")
                    local success = mediaPool:RelinkClips({clip}, new_dir)
                    assert(success, string.format("Could not relink clip '%s' to '%s'", file_path, new_dir))
                else
                    if not file_exists(new_fn) then
                        print("Could not find file: ", new_fn)
                        table.insert(missing_files, new_fn)
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
        print(string.format("Project '%s' had files that likely will not be relinked.", project:GetName()))
        print_table(missing_files)
        assert(false, "Missing files.")
    end
    if itm.backedup.Checked then
        -- Actually relink clips for this project.
        traverse_clips(mediaPool, folder, false)
    end
end

function traverse_projects(projectManager, projectFunc)
    print("Curr folder: ", projectManager:GetCurrentFolder())

    for i, project_name in pairs(projectManager:GetProjectListInCurrentFolder()) do
        if i ~= '__flags' then
            print("Found Project Name: ", project_name)
            project = projectManager:LoadProject(project_name)
            projectFunc(project)
        end
    end
    for i, folder_name in pairs(projectManager:GetFolderListInCurrentFolder()) do
        if i ~= '__flags' then
            if projectManager:OpenFolder(folder_name) then
                traverse_projects(projectManager, projectFunc)
                assert(projectManager:GotoParentFolder(), "Couldn't go to parent project manager folder")
            end
        end
    end
end

-- Draw window to get user parameters.
local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)
local width,height = 500,300

resolve = Resolve()
projectManager = resolve:GetProjectManager()
curr_database = projectManager:GetCurrentDatabase()['DbName']

win = disp:AddWindow({
    ID = 'MyWin',
    WindowTitle = 'Clip Relinker',
    Geometry = { 100, 100, width, height },
    Spacing = 10,
    ui:VGroup{
        ID = 'root',
        ui:Label{ID = 'database', Text = string.format('Current Database: %s', curr_database), Alignment = { AlignHCenter = true, AlignTop = true }},
        ui:HGroup{
            ID = 'src',
            ui:Label{ID = 'SrcLabel', Text = 'Select clips with this file path prefix:'},
            ui:TextEdit{ID = 'SrcPrefix', Text = '', PlaceholderText = 'C:\\Resolve Projects\\',}
        },
        ui:HGroup{
            ID = 'dst',
            ui:Label{ID = 'DstLabel', Text = 'Replace with this file path prefix:'},
            ui:TextEdit{ID = 'DstPrefix', Text = '', PlaceholderText = 'D:\\Resolve Projects\\',}
        },
        ui:CheckBox{ID = 'backedup', Text = string.format('I backed up %s', curr_database), Checked = 0},
        ui:HGroup{
            ID = 'buttons',
            ui:Button{ID = 'cancelButton', Text = 'Cancel'},
            ui:Button{ID = 'goButton', Text = 'Go'},
        },
    },
})

run_relink = false

-- The window was closed
function win.On.MyWin.Close(ev)
    disp:ExitLoop()
    run_relink = false
end

function win.On.cancelButton.Clicked(ev)
    print('Cancel Clicked')
    disp:ExitLoop()
    run_relink = false
end

function win.On.goButton.Clicked(ev)
    print('Go Clicked')
    disp:ExitLoop()
    run_relink = true
end

-- Add your GUI element based event functions here:
itm = win:GetItems()

win:Show()
disp:RunLoop()
win:Hide()

if run_relink then
    assert (itm.SrcPrefix.PlainText ~= "" and itm.DstPrefix.PlainText ~= "", "Found empty prefixes! Refusing to run.")
    assert (itm.SrcPrefix.PlainText ~= nil and itm.DstPrefix.PlainText ~= nil, "Found nil prefixes! Refusing to run.")
    old_prefix = itm.SrcPrefix.PlainText
    new_prefix = itm.DstPrefix.PlainText
    traverse_projects(projectManager, traverse_folders)
    print("Done!")
end
