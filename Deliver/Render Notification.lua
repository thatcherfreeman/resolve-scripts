function os.is_windows()
    return package.config:sub(1, 1) ~= "/"
end

local time = os.date("%I:%M %p")

if os.is_windows() then
    local ps = string.format(
        'powershell -WindowStyle Hidden -command "Add-Type -AssemblyName System.Windows.Forms;' ..
        '$n = New-Object System.Windows.Forms.NotifyIcon;' ..
        '$n.Icon = [System.Drawing.SystemIcons]::Information;' ..
        '$n.Visible = $true;' ..
        '$n.ShowBalloonTip(5000, \'Resolve\', \'Render Finished! Completed at %s\', [System.Windows.Forms.ToolTipIcon]::Info);' ..
        'Start-Sleep -s 6;' ..
        '$n.Dispose()"',
        time
    )
    io.popen(ps)
else
    io.popen("osascript -e 'display notification \"Render Finished!\" with title \"Resolve\" subtitle \"Completed at " .. time .. "\" sound name \"Glass\"'")
end
