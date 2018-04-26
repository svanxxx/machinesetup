#turn on windows update
#\\storage2\INSTALLS\POWERSHELL\dotNetFx45_Full_setup.exe
#\\storage2\INSTALLS\POWERSHELL\Win7AndW2K8R2-KB3191566-x64.msu
#turn off windows update
#Set-ExecutionPolicy RemoteSigned -Force
#Set-ExecutionPolicy Unrestricted -Force
#Set-ExecutionPolicy bypass -Force
#Install-PackageProvider -Name NuGet -RequiredVersion 2.8.5.201 -Force
#Install-Module -Name SqlServer -Force

$sqlserver = "192.168.0.8"
$sqluser = "sa"
$sqlpass = "prosuite"
$sqlhosts = "[BST_STATISTICS].[dbo].[HOSTS]"
$sqlpcs = "[BST_STATISTICS].[dbo].[PCS]"
$sleepbeforerun = 30
$machinesfile = "C:\MACHINES.TXT"
$vboxmanage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
function GetVMs()
{
    $listofvms = New-Object System.Collections.Generic.List[System.Object]
    $runningvms = & "$vboxmanage" list runningvms
    if (!$runningvms)
    {
        return $listofvms 
    }
    if ($runningvms.GetType().FullName -eq "System.String")
    {
        return $runningvms.split('"')[1]
    }

    for ($i=0; $i -lt $runningvms.length; $i++)
    {
	    $listofvms.Add($runningvms[$i].split('"')[1])
    }
    return $listofvms
}
function PingDBWIthUpdated()
{
    echo "Ping database..."
    $str = "UPDATE $sqlhosts SET PCPING = SYSDATETIME(), LAST_UPDATED = SYSDATETIME() WHERE NAME = '$env:COMPUTERNAME'"
    Invoke-Sqlcmd -Query "$str" -ServerInstance $sqlserver -Username $sqluser -Password $sqlpass
}
function ThosterDiskInfo()
{
    $result = ""
    Get-WmiObject Win32_DiskDrive | % {
        $disk = $_
        $gbs = $disk.Size / 1024 / 1024 / 1024
        $gbstxt = [math]::Round($gbs, 1)
        $diskModel = $disk.Model
        $result += "$diskModel ($gbstxt)Gb,"

        $partitions = "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($disk.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition"
        Get-WmiObject -Query $partitions | % {
            $partition = $_
            $drives = "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} WHERE AssocClass = Win32_LogicalDiskToPartition"
            Get-WmiObject -Query $drives | % {
                $DriveLetter = $_.DeviceID
                $VolumeName  = $_.VolumeName
                $RawSize = $partition.Size
                $gbs = $RawSize / 1024 / 1024 / 1024
                $gbstxt = [math]::Round($gbs, 1)
                $result += "     $DriveLetter($VolumeName) ($gbstxt) Gb,"
            }
        }
        $result += ","
    }
    echo $result
}

PingDBWIthUpdated

if (Test-Path("$machinesfile"))
{
    $filemachines = Get-Content "$machinesfile"
    foreach ($filemachine in $filemachines)
    {
        echo "Waking up machine $filemachine..."
        & "$vboxmanage" startvm $filemachine
        PingDBWIthUpdated
        start-Sleep -s 15

        $vms = GetVMs
        $ok = $false
        foreach ($vm in $vms)
        {
            if ("$vm".ToUpper() -eq "$filemachine".ToUpper())
            {
                $ok = $true
            }
        }
        if ($ok -eq $false)
        {
            & "$vboxmanage" discardstate "$filemachine"
            PingDBWIthUpdated
		    start-Sleep -s 5
            & "$vboxmanage" startvm "$filemachine"
            PingDBWIthUpdated
		    start-Sleep -s 15
        }
    }
}
else
{
    echo "File $machinesfile was not found!"
    Read-Host 'Press Enter to continue…' | Out-Null
    Exit
}

echo "Loading machine name..."
echo $env:COMPUTERNAME

echo "Loading memory information..."
$InstalledRAM = Get-WmiObject -Class Win32_ComputerSystem
$mem = $InstalledRAM.TotalPhysicalMemory / 1024 / 1024 / 1024
$memorygb = [math]::Round($mem, 1)
$memory = "$memorygb Gb"
echo $memory

echo "Loading LAN properties..."
$colItems = get-wmiobject -class "Win32_NetworkAdapterConfiguration" -computername $env:COMPUTERNAME  | where IPEnabled -eq $true | where Description -notlike "*Box*"
$ethernet = $colItems | Select-Object -first 1
$MACAddress = $ethernet.MACAddress
$IPAddress = "" + $ethernet.IPAddress

$adapters = get-wmiobject win32_networkadapter | where netconnectionstatus -eq 2
$lanspeed = ""
for ($i=0; $i -lt $adapters.Count; $i++)
{
	$adapter = $adapters[$i]
    if (!$adapter.name.ToUpper().Contains("BOX"))
    {
        $gbspeed = $adapters[0].speed / 1000 / 1000 / 1000
        $adaptername = $adapter.name
        $lanspeed += "$gbspeed Gbps"
        if ($gbspeed -eq 1)
        {
            $lanspeed += "(OK)," + "$adaptername"
        }
        else
        {
            $lanspeed += "(FAIL)," + "$adaptername"
        }
    }
}
echo $lanspeed
$IPAddress += ",$lanspeed"
$IPAddress = $IPAddress.Substring(0,49)#db limit

echo $MACAddress
echo $IPAddress

echo "loading physical drives..."
$diskstxt = ThosterDiskInfo
echo $diskstxt

echo "Loading CPU Info..."
$cpu = Get-CimInstance -Class Win32_Processor
#removing names for old and new CPUs
$cpuname = $cpu.Name.Replace("Intel(R) Core(TM) ","").Replace("Intel(R) Core(TM)","").Replace("CPU ","")
echo $cpuname

echo "Loading OS Info..."
$systeminfo = systeminfo
echo $systeminfo[2]
$osname = $systeminfo[2].Split(":")[1]

$cpuname = $cpuname.Trim()
$memory = $memory.Trim()
$osname = $osname.Trim()
$diskstxt = $diskstxt.Trim()
$fullMachineInfo = "$cpuname,$memory,$osname,$diskstxt"

$db = Invoke-Sqlcmd -Query " SELECT COUNT(H.ID) C FROM $sqlhosts H WHERE UPPER(H.NAME) = UPPER('$env:COMPUTERNAME')" -ServerInstance $sqlserver -Username $sqluser -Password $sqlpass
If ($db.C -eq 0)
{
    echo "Adding record to hosts table in database..."
    $str = "INSERT INTO $sqlhosts (NAME, IP, MAC, POWEROFF, POWERON, PCPING, SYSTEMINFO, STARTED) VALUES ('$env:COMPUTERNAME', '$IPAddress', '$MACAddress', 0, 0, GETDATE(),'$fullMachineInfo', GETDATE())"
    Invoke-Sqlcmd -Query "$str" -ServerInstance "$sqlserver" -Username "$sqluser" -Password "$sqlpass"
}
Else
{
    echo "Updating info in hosts table in database..."
    $str = "UPDATE $sqlhosts SET IP = '$IPAddress', MAC = '$MACAddress', POWEROFF = 0, SYSTEMINFO = '$fullMachineInfo', STARTED = GETDATE() WHERE NAME = '$env:COMPUTERNAME'"
    Invoke-Sqlcmd -Query "$str" -ServerInstance $sqlserver -Username $sqluser -Password $sqlpass
}

PingDBWIthUpdated
echo "Sleep $sleepbeforerun seconds before thosters wake up..."
start-Sleep -s $sleepbeforerun

echo "Getting list of running machines"
$vms = GetVMs
echo $vms

echo "Updating child machines information in database..."
for ($i=0; $i -lt $vms.Count; $i++)
{
    $thoster = $vms[$i]
    echo "Updating $thoster..."
    $str = "UPDATE $sqlpcs SET HOST_ID = (SELECT H.ID FROM $sqlhosts H WHERE H.NAME = '$env:COMPUTERNAME') WHERE PCNAME = '$thoster'"
    Invoke-Sqlcmd -Query "$str" -ServerInstance $sqlserver -Username $sqluser -Password $sqlpass
}

echo "Starting process loop..."
$shell = New-Object -ComObject "Shell.Application"
$shell.minimizeall()

while($true)
{
    $date = Get-Date
    echo "Updating database: $date"
    Start-Sleep -s 10
    
    #mark machines as alive in database without last updated
    $str = "UPDATE $sqlhosts SET PCPING = SYSDATETIME() WHERE NAME = '$env:COMPUTERNAME'"
    Invoke-Sqlcmd -Query "$str" -ServerInstance $sqlserver -Username $sqluser -Password $sqlpass

    #check if power off is required
    $str = "SELECT POWEROFF P FROM $sqlhosts WHERE NAME = '$env:COMPUTERNAME'"
    $db = Invoke-Sqlcmd -Query "$str" -ServerInstance $sqlserver -Username $sqluser -Password $sqlpass
    If ($db.P -eq 1)
    {
        $str = "UPDATE $sqlhosts SET POWEROFF = 0, PCPING = dateadd(DAY, -1, getdate()) WHERE NAME = '$env:COMPUTERNAME'"
        Invoke-Sqlcmd -Query "$str" -ServerInstance $sqlserver -Username $sqluser -Password $sqlpass

        echo "Getting list of running machines"
        $vms = GetVMs
        echo $vms

        echo "Stopping Machines..."
        for ($i=0; $i -lt $vms.Count; $i++)
        {
            $thoster = $vms[$i]
            echo "Stopping $thoster..."
            & "$vboxmanage" controlvm $thoster savestate

            $str = "UPDATE $sqlpcs SET PCPING = DATEADD(DAY, -1, GETDATE()), LAST_UPDATED = SYSDATETIME() WHERE PCNAME = '$thoster'"
            Invoke-Sqlcmd -Query "$str" -ServerInstance $sqlserver -Username $sqluser -Password $sqlpass

        }
        echo "sleep 10 sec before shut down..."
        Start-Sleep -s 10
        Stop-Computer -Force
    }
}