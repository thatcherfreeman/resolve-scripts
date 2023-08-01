--[[
Deletes empty bins from the Media Pool
--]]

resolve = Resolve()
projectManager = resolve:GetProjectManager()
project = projectManager:GetCurrentProject()
mediaPool = project:GetMediaPool()
rootFolder = mediaPool:GetRootFolder()

function delete_subfolders(folder)
    print(string.format("Curr Folder: %s", folder:GetName()))
    subfolders = folder:GetSubFolderList()

    for _, subfolder in ipairs(subfolders) do
        delete_subfolders(subfolder)
    end

    if #folder:GetSubFolderList() == 0 and #folder:GetClipList() == 0 then
        print(string.format("Deleting folder %s", folder:GetName()))
        mediaPool:DeleteFolders({folder})
    end
end

delete_subfolders(rootFolder)