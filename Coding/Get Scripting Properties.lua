--[[
Looks up the file corresponding to the current DNG clip, then spits out a DCTL that will
transform it to the specified color space.
--]]

function print_table(t, indentation)
    if indentation == nil then
        indentation = 0
    end
    local outer_prefix = string.rep("    ", indentation)
    local inner_prefix = string.rep("    ", indentation + 1)
    table.sort(t)
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

local resolve = Resolve()
local projectManager = resolve:GetProjectManager()
local project = projectManager:GetCurrentProject()
print("Project Settings")
print_table(project:GetSetting())

local timeline = project:GetCurrentTimeline()
print("Timeline Settings")
print_table(timeline:GetSetting())

local clip = timeline:GetCurrentVideoItem()
print("Clip Properties")
print_table(clip:GetProperty())

local media_item = clip:GetMediaPoolItem()
print("Media Item Metadata")
print_table(media_item:GetMetadata())
print("Media Item Properties")
print_table(media_item:GetClipProperty())

local separator = package.config:sub(1,1)
