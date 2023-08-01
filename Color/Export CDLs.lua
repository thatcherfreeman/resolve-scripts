
function print_table(t)
    for k, v in pairs(t) do
        print(k, ": ", v)
    end
end

function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
 end

-- Draw window to get user parameters.
local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)
local width,height = 500,200

win = disp:AddWindow({
    ID = 'MyWin',
    WindowTitle = 'Export CDLs',
    Geometry = { 100, 100, width, height },
    Spacing = 10,
    ui:VGroup{
        ID = 'root',
        ui:HGroup{
            ID = 'dst',
            ui:Label{ID = 'DstLabel', Text = 'Location to write EDL and CDLs to:'},
            ui:TextEdit{ID = 'DstPath', Text = '', PlaceholderText = '~/Desktop/',}
        },
        ui:CheckBox{ID = 'overwriteFiles', Text = 'Overwrite Files'},
        ui:HGroup{
            ID = 'buttons',
            ui:Button{ID = 'cancelButton', Text = 'Cancel'},
            ui:Button{ID = 'goButton', Text = 'Go'},
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
    print('Cancel Clicked')
    disp:ExitLoop()
    run_export = false
end

function win.On.goButton.Clicked(ev)
    print('Go Clicked')
    disp:ExitLoop()
    run_export = true
end

-- Add your GUI element based event functions here:
itm = win:GetItems()

win:Show()
disp:RunLoop()
win:Hide()

if run_export then
    assert (itm.DstPath.PlainText ~= nil and itm.DstPath.PlainText ~= "", "Found empty destination path! Refusing to run")
    dstPath = itm.DstPath.PlainText
    overwrite = itm.overwriteFiles.Checked

    M.path_separator = "/"
    M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win32unix") == 1
    if M.is_windows == true then
        M.path_separator = "\\"
    end

    -- Make EDL via Export CDL button
    resolve = Resolve()
    projectManager = resolve:GetProjectManager()
    project = projectManager:GetCurrentProject()
    timeline = project:GetCurrentTimeline()
    output_fn = string.format("%s%s%s", dstPath)
    print(output_fn)
end
