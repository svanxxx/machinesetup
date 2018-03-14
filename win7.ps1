Set-ExecutionPolicy RemoteSigned -Force
Set-ExecutionPolicy Unrestricted -Force
Set-ExecutionPolicy bypass -Force

function shut-service{
Param ($Name)
"Updating service {0}..." -f $name
Stop-Service $Name
Set-Service $Name -StartupType Disabled
}

echo "installing win7 time zone update ..."
wusa "\\192.168.0.1\Installs\OS Installs\Windows 7\Windows6.1-KB3162835-x64 (time zone).msu" /quiet /norestart | Out-Null

echo "installing framework 4.7 ..."
& "\\sirius\Installs\System\DotNetFramework\NDP471-KB4033342-x86-x64-AllOS-ENU.exe" /passive | Out-Null

echo "installing power shell update..."
wusa "\\192.168.0.1\Installs\OS Installs\Windows 7\Win7AndW2K8R2-KB3191566-x64.msu" /quiet /norestart | Out-Null

echo "disabling UAC ..."
New-ItemProperty -Path HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system -Name EnableLUA -PropertyType DWord -Value 0 -Force

echo "hiding action center ..."
New-ItemProperty -Path HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name HideSCAHealth -PropertyType String -Value 1 -Force

echo "setting up autologon ..."
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultDomainName -PropertyType String -Value "MPS" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultUserName -PropertyType String -Value "sqlserver" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon -PropertyType String -Value "1" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultPassword -PropertyType String -Value "sql911" -Force

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