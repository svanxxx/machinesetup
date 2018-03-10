function shut-service{
Param ($Name)
"Updating service {0}..." -f $name
Stop-Service $Name
Set-Service $Name -StartupType Disabled
}

shut-service("wscsvc")
shut-service("windefend")
shut-service("wuauserv")

echo "turning off hibernate ..."
& "powercfg.exe" /hibernate off

echo "turning off system restore for disk c..."
Disable-ComputerRestore -Drive "C:\"

echo "turning off sounds..."
Set-ItemProperty "HKCU:\AppEvents\Schemes" -Name "(default)" -Value ".None"

echo "turning off screen saver..."
Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "ScreenSaveActive" -value 0
if (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name "SCRNSAVE.EXE" -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "SCRNSAVE.EXE"
}

echo "updating desktop..."
Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "Wallpaper" -value ""
Set-ItemProperty 'HKCU:\Control Panel\Colors' -Name "Background" -Value "0 0 0"
Set-ItemProperty "HKCU:\Software\Microsoft\Internet Explorer\Desktop\General" -Name "WallpaperSource" -value ""
RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters ,1 ,True

echo "Done."