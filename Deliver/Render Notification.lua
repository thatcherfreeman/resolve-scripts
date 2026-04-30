function os.is_windows()
    return package.config:sub(1, 1) ~= "/"
end

local time = os.date("%I:%M %p")

if not os.is_windows() then
    io.popen("osascript -e 'display notification \"Render Finished!\" with title \"Resolve\" subtitle \"Completed at " .. time .. "\" sound name \"Glass\"'")
end
