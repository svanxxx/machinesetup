#Set-ExecutionPolicy RemoteSigned -Force
#Set-ExecutionPolicy Unrestricted -Force
#Set-ExecutionPolicy bypass -Force

function disable-service([string]$name)
{
	"Updating service...$($name)"
	Stop-Service $name
	Set-Service $name -StartMode Disabled
}

#Telemetry Disable
function Telemetry-Disable()
{
	New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -PropertyType DWord -Value 0 -Force
	disable-service "DiagTrack"
	disable-service "dmwappushservice"

    ($TaskScheduler = New-Object -ComObject Schedule.Service).Connect("localhost")
    $MyTask = $TaskScheduler.GetFolder("Microsoft\Windows\Application Experience").GetTask("Microsoft Compatibility Appraiser")
    $MyTask.Enabled = $false
}
#Disable Action Center
function ActionCenter-Disable()
{
    New-Item HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer -Force | New-ItemProperty -Name DisableNotificationCenter -Value 1 -Force
}

Telemetry-Disable
ActionCenter-Disable