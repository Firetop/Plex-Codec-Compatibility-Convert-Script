##Script Locations##
$CustomScripts = "C:\Program Files\MKVToolNix\Custom Scripts"
##Root of Movies Directory##
$MoviesD = "M:\Movies\"
##Same as above, but add secondary backslashes to the path##
$MoviesDC = "M:\\Movies\\"


##MKV Audio Track Values to Search in Files##
$Track2A= "Track ID 2: audio"
###DTS Values###
$Track1DTS = "Track ID 1: audio (DTS)"
$Track1DTSHD = "Track ID 1: audio (DTS-HD Master Audio)"
$Track2DTS = "Track ID 2: audio (DTS)"
$Track2DTSHD = "Track ID 2: audio (DTS-HD Master Audio)"
###TrueHD Values###
$Track1True = "Track ID 1: audio (TrueHD)"
$Track1TrueA = "Track ID 1: audio (TrueHD Atmos)"
$Track2True = "Track ID 2: audio (TrueHD)"
$Track2TrueA = "Track ID 2: audio (TrueHD Atmos)"

function Show-Notification {
    [cmdletbinding()]
    Param (
        [string]
        $ToastTitle,
        [string]
        [parameter(ValueFromPipeline)]
        $ToastText
    )

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    $Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)

    $RawXml = [xml] $Template.GetXml()
    ($RawXml.toast.visual.binding.text|where {$_.id -eq "1"}).AppendChild($RawXml.CreateTextNode($ToastTitle)) > $null
    ($RawXml.toast.visual.binding.text|where {$_.id -eq "2"}).AppendChild($RawXml.CreateTextNode($ToastText)) > $null

    $SerializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $SerializedXml.LoadXml($RawXml.OuterXml)

    $Toast = [Windows.UI.Notifications.ToastNotification]::new($SerializedXml)
    $Toast.Tag = "MKV Cleanup"
    $Toast.Group = "MKV Cleanup"
    $Toast.ExpirationTime = [DateTimeOffset]::Now.AddHours(8)

    $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("MKV Cleanup")
    $Notifier.Show($Toast);
}

## Commentary Track Search & Remove Code ##
Set-Location -Path $MoviesD
$oldvids = Get-ChildItem *.mkv -Recurse | Sort-Object CreationTime | Select-Object -Last 1

foreach ($oldvid in $oldvids) {
    $newVariable = $oldvid.DirectoryName
    Set-Location -Path "$newVariable"
    
    # Capture the JSON output from mkvmerge.exe
    $jsonOutput = & mkvmerge.exe -J $oldvid | Out-String
    # Parse the JSON output
    $obj = $jsonOutput | ConvertFrom-Json
    
    # Initialize flag
    $hasCommentary = $false

    # Check each track for 'commentary' in any property
    foreach ($track in $obj.tracks) {
        foreach ($prop in $track.properties.PSObject.Properties) {
            # Ensure the property value is a string before matching
            if ($prop.Value -is [string] -and $prop.Value -match '(?i)\bcommentary\b') {
                $hasCommentary = $true
                break
            }
        }
        if ($hasCommentary) { break }
    }
    
    if ($hasCommentary) {
        & "$CustomScripts\DelMKVComment.bat"
        Start-Sleep -Milliseconds 500
        Get-ChildItem -Path "$newVariable\*.NoComments.mkv" | ForEach-Object {
            Rename-Item -Path $_.FullName -NewName $_.FullName.Replace(".NoComments", "")
        }
        Show-Notification "Removed Commentary Tracks!" "Removed Commentary Tracks Detected from $newVariable"
    }
}

##DTS Search and Reorder & Replace Code##
Set-Location -Path $MoviesD
$oldvids = Get-ChildItem *.mkv -Recurse | sort Creationtime | select -last 8
foreach ($oldvid in $oldvids) {
$newVariable = $oldvid.DirectoryName
Set-Location -Path "$newVariable"
$newvids = mkvmerge.exe -i $oldvid.FullName

#Reorder if DTS is first Audio track, and anything but DTS or TrueHD is the second audio track#
#    if (($newvids.Contains($Track1DTS) -or $newvids.Contains($Track1DTSHD)) -and
#    (-not $newvids.Contains($Track2DTS) -and -not $newvids.Contains($Track2DTSHD) -and
#     -not $newvids.Contains($Track2True) -and -not $newvids.Contains($Track2TrueA)) -and
#    ($newvids -match $Track2A))
#    {& $CustomScripts\DTSReorder.bat
#    Start-Sleep -Milliseconds 500
#    get-childitem -Path *.AudioTrackReordered.mkv -Recurse | foreach { rename-item $_ $_.Name.Replace(".AudioTrackReordered", "") }
#    Show-Notification "DTS Tracks Detected!" "Reordered DTS Tracks Detected from $newVariable" 
#    continue
#    }

#Convert if DTS is first Audio track, and DTS or TrueHD is the second audio track#
    if(($newvids.Contains($Track1DTS) -or $newvids.Contains($Track1DTSHD)) -and 
    ($newvids.Contains($Track2DTSHD) -and $newvids.Contains($Track2DTS) -and $newvids.Contains($Track2TrueA) -and $newvids.Contains($Track2True)))
    {& $CustomScripts\DTSConvert.bat
    Start-Sleep -Milliseconds 500
    Get-ChildItem -Path "$newVariable\*.ACConverted.mkv" | ForEach-Object {
    Rename-Item -Path $_.FullName -NewName $_.FullName.Replace(".ACConverted", "")
}
    Show-Notification "DTS Tracks Detected!" "Converted DTS Tracks Detected from $newVariable" 
    continue
    }

#Convert if DTS is the only Audio track#
    if(($newvids.Contains($Track1DTSHD) -or $newvids.Contains($Track1DTS)) -and (-not $newvids.Contains($Track2A)))
    {& $CustomScripts\DTSConvert.bat
    Start-Sleep -Milliseconds 500
    Get-ChildItem -Path "$newVariable\*.ACConverted.mkv" | ForEach-Object {
    Rename-Item -Path $_.FullName -NewName $_.FullName.Replace(".ACConverted", "")
}
    Show-Notification "DTS Tracks Detected!" "Converted DTS Tracks Detected from $newVariable" 
    }
}


##TrueHD Search and Reorder & Replace Code##
Set-Location -Path $MoviesD
$oldvids = Get-ChildItem *.mkv -Recurse | sort Creationtime | select -last 8
foreach ($oldvid in $oldvids) {
$newVariable = $oldvid.DirectoryName
Set-Location -Path "$newVariable"
$newvids = mkvmerge.exe -i $oldvid.FullName

#Reorder if TrueHD is first Audio track, and anything but DTS or TrueHD is the second audio track#
#    if (($newvids.Contains($Track1True) -or $newvids.Contains($Track1TrueA)) -and
#    (-not $newvids.Contains($Track2True) -and -not $newvids.Contains($Track2TrueA) -and
#     -not $newvids.Contains($Track2DTS) -and -not $newvids.Contains($Track2DTSHD)) -and
#    ($newvids -match $Track2A))
#    {& $CustomScripts\TrueHDTReorder.bat
#    Start-Sleep -Milliseconds 500
#    get-childitem -Path *.AudioTrackReordered.mkv -Recurse | foreach { rename-item $_ $_.Name.Replace(".AudioTrackReordered", "") }
#    Show-Notification "TrueHD Tracks Detected!" "Reordered TrueHD Tracks Detected from $newVariable" 
#    continue
#}

#Convert if TrueHD is first Audio track, and TrueHD or DTS is the second audio track#
    if(($newvids.Contains($Track1True) -or $newvids.Contains($Track1TrueA)) -and 
    ($newvids.Contains($Track2TrueA) -and $newvids.Contains($Track2True) -and $newvids.Contains($Track2DTS) -and $newvids.Contains($Track2DTSHD)))
    {& $CustomScripts\TrueHDConvert.bat
    Start-Sleep -Milliseconds 500
    Get-ChildItem -Path "$newVariable\*.ACConverted.mkv" | ForEach-Object {
    Rename-Item -Path $_.FullName -NewName $_.FullName.Replace(".ACConverted", "")
}
    Show-Notification "TrueHD Tracks Detected!" "Converted TrueHD Tracks Detected from $newVariable" 
    continue
}

#Convert if TrueHD is the only Audio track#
    if(($newvids.Contains($Track1True) -or $newvids.Contains($Track1TrueA)) -and (-not $newvids.Contains($Track2A)))
    {& $CustomScripts\TrueHDConvert.bat
    Start-Sleep -Milliseconds 500
    Get-ChildItem -Path "$newVariable\*.ACConverted.mkv" | ForEach-Object {
    Rename-Item -Path $_.FullName -NewName $_.FullName.Replace(".ACConverted", "")
}
    Show-Notification "TrueHD Tracks Detected!" "Converted TrueHD Tracks Detected from $newVariable" 
    }
}


##Subtitle and Search & Remove Code##
#Set-Location -Path $MoviesD
#$oldvids = Get-ChildItem *.mkv -Recurse | sort Creationtime | select -last 8
#foreach ($oldvid in $oldvids) {
#$newVariable = $oldvid.DirectoryName
#Set-Location -Path "$newVariable"
#$newvids = mkvmerge.exe -i $oldvid.FullName
#    if($newvids -match "subtitles")
#    {& $CustomScripts\DelMKVSubs.bat
#    Start-Sleep -Milliseconds 500
#    get-childitem -Path *.NoSubs.mkv -Recurse | foreach { rename-item $_ $_.Name.Replace(".NoSubs", "") }
#    Show-Notification "Subtitle Tracks Detected!" "Removed Subtitle Tracks Detected from $newVariable" 
#    }
#}

exit
