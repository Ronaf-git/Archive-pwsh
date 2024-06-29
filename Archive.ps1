<# 
----------------------------------------------------
Description : Archive multiples folders when changes are found 
Usage : fill the config file (psd1) present with this script 
Author : Ronaf
Version : 0.3
Revision : 
	0.3 27/06/2024 : Abandon the hash comparaison (Zip files done with Compress-Archive are not determinist, which means that two zip files with same files, done at different times/localisation will be differents). 
		Use of a Timestamp of last Updated file to identifie new files
	0.2 20/06/2024 : Try to compare Hash from previous archive and newest archive
	0.1 11/06/2024 : First version
----------------------------------------------------
#>

#=====================================================================================================
#==========================================  Fonctions ===============================================
#=====================================================================================================
function Display-Notification($Txt,$Title,$Duration) {
  <#
    .DESCRIPTION
    Create a notification for the notification center of Windows
    .INPUTS
    Text, Title and duration (Millisec) 
    .OUTPUTS
    Notification in the notification center
  #>
    Add-Type -AssemblyName System.Windows.Forms
    $global:balmsg = New-Object System.Windows.Forms.NotifyIcon
    $path = (Get-Process -id $pid).Path
    $balmsg.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
    $balmsg.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
    $balmsg.BalloonTipText = "$Txt"
    $balmsg.BalloonTipTitle = "$Title"
    $balmsg.Visible = $true
    $balmsg.ShowBalloonTip($Duration)
}
function Increment-FolderName ($PathWhereCreateFolder) {
    $i=0
    #get the name to increment it
    $TestedPathName,$null=$PathWhereCreateFolder.split("_")
    #variable to output
    $Output = $TestedPathName
	while (Test-Path -Path "$Output"){
		$i ++
        $Output = "${TestedPathName}_${i}"
        }
		return "$Output"	  
}

function LastUpdateFolder ($FolderPath) {
  <#
    .DESCRIPTION
    Get the timestamp of the last updated files in all folders/subfolders
    We cannot simply get the Timestamp of the alst update of the folder, because it updates only if this folder or the folder L-1 is modified. Below levels are not taken into account. 
    .INPUTS
    Path to a folder 
    .OUTPUTS
    Number of seconds elapsed since January 1, 1970 00:00:00 (UTC) of the last updated file in the folder/subfolders
  #>
    $a = Get-ChildItem "$FolderPath" -Recurse -file
    $b = ($a.LastWriteTime | measure -Maximum).Maximum
    $c = [System.Math]::Truncate((Get-Date -Date $b  -UFormat %s)) 
    return $c
}

#=====================================================================================================
#================================================  Script ============================================
#=====================================================================================================
# ----------------- Init variables -------------------------
#From the script
$strInputPathNotSaved = @()
$Today = Get-Date -Format "ddMMyyyy"
$PSD1Path = "$PSScriptRoot\Settings.psd1"
#From the config file
$ConfigFile = Import-PowerShellDataFile -Path "$PSD1Path" -ErrorAction Stop
$OutputGenericNameTmp =$ConfigFile.OutputGenericName
$OutputGenericName ="$($ConfigFile.OutputGenericName)_${Today}"
$OutputFormat = $ConfigFile.OutputFormat
$OutputPath = $ConfigFile.OutputPath
$InputPaths = $ConfigFile.InputPaths
$InputPathsTS = $ConfigFile.InputPathsTS

#start try
$ErrorActionPreference = 'Stop'
try {
# ----------------- Check if the output path exist -------------------------
if (-not (Test-Path -Path "$OutputPath")) { 
	#If not exist : stop script
    Display-Notification -Txt "The folder ${OutputPath} does not exist. No archive done. Please fix the variable 'OutputPath" -Title "Erreur" -Duration "30000"
	exit
	} 	
# ------------ Create the folder that will get the archives and start logs ------------
Start-transcript -Path "${OutputPath}\Log.txt" -Append 	 
$OutputFolder =Increment-FolderName -PathWhereCreateFolder "${OutputPath}${Today}"
[void](New-Item -ItemType Directory -Path $OutputFolder)

# ------------ Create one archive per SavedFolder. Usefull if some do not change often ------------
$IndexInput = 0
ForEach ($InputPath in $InputPaths) {
#note : InputPathsTS save the lastest TS present in the last save, for each InputPaths. Their indexes MUST be linked. that's why IndexInput is used here : to know in which Index we are in the for each boucle
    #Check if the folder exist. if not, continue to the next InputPath and report it
    if (!(Test-Path -Path "$($InputPath)\*")) {
        $strInputPathNotSaved += $InputPath
        $IndexInput ++
        continue
        }
    #get the timestamp of the last updated file in the folder/subfolders. If it's greater than the one of last time we archived this folder, archive it
    $LstUpdt = LastUpdateFolder -FolderPath $InputPath
     if($LstUpdt -le $InputPathsTS[$IndexInput]) {
        $IndexInput ++
        continue
        } else {$InputPathsTS[$IndexInput] = $LstUpdt}
    #Check if the archive alerady exist. if so, create a new one with an incremented name
    $i=0
	$TmpName = [regex]::Replace($InputPath, "[^a-zA-Z0-9\s]", "")
	$OutputName = "${OutputGenericName}_${TmpName}"
	$OutputFullPath = "${OutputFolder}\${OutputName}${OutputFormat}"
	while (Test-Path -Path "${OutputFullPath}"){
		$i ++
		$OutputFullPath = "${OutputFolder}\${OutputName}_${i}${OutputFormat}"	
	}                               
	#Parameters for archiving
	$compress = @{
		Path= $InputPath
		CompressionLevel = "Optimal"
		DestinationPath = "${OutputFullPath}"
	}
	#Create Archive
	Compress-Archive @compress

    #Increment the variable that store my index
    $IndexInput ++
        }

# ----------------- Update the PSD1 file (config) with new values -------------------------
$NewInputPaths = $InputPaths -join "','"
$NewInputPathsTS = $InputPathsTS -join ","
$strMyModule= "
#This module is used to store variables between runs of the script
@{
# -------- Variables that you can change -------- 
    OutputGenericName = ""$OutputGenericNameTmp""  #Ex: MyArchive
    OutputFormat = ""$OutputFormat""    #Ex: .zip
    OutputPath = '$OutputPath'  #Ex: C:\Users\<MyUser>\Downloads\'
#/!\ The indexes of InputPaths and InputPathsTS must match /!\
#That means : if you add a InputPaths : You must add a value (0) in InputPathsTS, at the same index. If you delete a InputPaths : You must delete the value in InputPathsTS, at the same index
    InputPaths =  @('$NewInputPaths') #Ex : C:\Users\<MyUser>\Videos
    InputPathsTS = @($NewInputPathsTS) #Ex : 0. It'll be changed after first run

# -------- Please don't touch theses -------- 
    LastRun = $Today                    
}"	

[void] (New-Item -Path $PSD1Path -Value $strMyModule -ItemType File -Force)

#Check if at least an archive is stored in the folder. if Not delete it
if (!(Test-Path -Path "${OutputFolder}\*")) {
	#None exist. Delete folder and report it
	Remove-Item "${OutputFolder}"
    Display-Notification -Txt "No modification. No new archive." -Title "Archive-pwsh result" -Duration "30000"
    break
    }	                               
#catch
} catch { 
    Display-Notification -Txt "Errors. Please check logs" -Title "Archive-pwsh result" -Duration "30000"
    break}

# ----------------- End -------------------------
#String displayed
if ($strInputPathNotSaved.count -gt 0) {
      $strNotification = "Folders ${strInputPathNotSaved} do not exist/are empty. No archive done for them. Other folders were successfuly saved."
    }	else {
	    $strNotification = "Success !"
    }
#Notification
Display-Notification -Txt "$strNotification" -Title "Archive-pwsh result" -Duration "30000"

Stop-Transcript


# ----------------- ZZZ_OLD -------------------------
#Store hashed value of all current saved archives. Will be usefull to compare the fresh archive with all the previous already saved
#$files = Get-ChildItem -path "$OutputPath\*" -Recurse -Force -Exclude *.txt
#$ArchivesHashs = $(foreach ($File in $files){(Get-FileHash $File).Hash } ) | Sort-Object | Get-Unique
#Verifie si une archive au contenu identique existe deja . Si oui, supprime celle nouvellement creee.
#if ($ArchivesHashs -contains (Get-FileHash $OutputFullPath).Hash )  {Remove-Item ${OutputFullPath} ; break }
