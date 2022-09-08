<#
	.DESCRIPTION
		This script sets UEM settings with PowerShell.
		When executed under SYSTEM authority a scheduled task is created to ensure recurring or once script execution on each user logon.
	.NOTES
        BASE Author: Nicola Suter, nicolonsky tech: https://tech.nicolonsky.ch
        Modified to UEM by: Naures Shakarchi Nimmit.nl
#>

[CmdletBinding()]
Param()

###########################################################################################
# Start transcript for logging															  #
###########################################################################################

Start-Transcript -Path $(Join-Path $env:temp "UEM.log")

###########################################################################################
# Helper function to determine a users group membership									  #
###########################################################################################

function Get-ADGroupMembership {
	param(
		[parameter(Mandatory=$true)]
		[string]$UserPrincipalName
	)
	process{

		try{

			$Searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
			$Searcher.Filter = "(&(userprincipalname=$UserPrincipalName))"
			$Searcher.SearchRoot = "LDAP://$env:USERDNSDOMAIN"
			$DistinguishedName = $Searcher.FindOne().Properties.distinguishedname
			$Searcher.Filter = "(member:1.2.840.113556.1.4.1941:=$DistinguishedName)"
			
			[void]$Searcher.PropertiesToLoad.Add("name")
			
			$List = [System.Collections.Generic.List[String]]@()

			$Results = $Searcher.FindAll()
			
			foreach ($Result in $Results) {
				$ResultItem = $Result.Properties
				[void]$List.add($ResultItem.name)
			}
		
			$List

		}catch{
			#Nothing we can do
			Write-Warning $_.Exception.Message
		}
	}
}

###########################################################################################
# Get current group membership for the group filter capabilities						  #
###########################################################################################

if ($driveMappingConfig.GroupFilter){
	try{
		#check if running as user and not system
		if (-not ($(whoami -user) -match "S-1-5-18")){

			$groupMemberships = Get-ADGroupMembership -UserPrincipalName $(whoami -upn)
		}
	}catch{
		#nothing we can do
	}	 
}
###########################################################################################
# UEM CODE														                          #
###########################################################################################



###########################################################################################
# End & finish transcript																  #
###########################################################################################

Stop-transcript

###########################################################################################
# Done																					  #
###########################################################################################

#!SCHTASKCOMESHERE!#

###########################################################################################
# If this script is running under system (IME) scheduled task is created  (recurring)	  #
###########################################################################################

Start-Transcript -Path $(Join-Path -Path $env:temp -ChildPath "UEM.log")

if ($(whoami -user) -match "S-1-5-18"){

	Write-Output "Running as System --> creating scheduled task which will run on user logon"

	###########################################################################################
	# Get the current script path and content and save it to the client						  #
	###########################################################################################

	$currentScript= Get-Content -Path $($PSCommandPath)
	
	$schtaskScript=$currentScript[(0) .. ($currentScript.IndexOf("#!SCHTASKCOMESHERE!#") -1)]

	$scriptSavePath=$(Join-Path -Path $env:ProgramData -ChildPath "UEM")

	if (-not (Test-Path $scriptSavePath)){

		New-Item -ItemType Directory -Path $scriptSavePath -Force
	}

	$scriptSavePathName="UEMReg.ps1"

	$scriptPath= $(Join-Path -Path $scriptSavePath -ChildPath $scriptSavePathName)

	$schtaskScript | Out-File -FilePath $scriptPath -Force

	###########################################################################################
	# Create dummy vbscript to hide PowerShell Window popping up at logon					  #
	###########################################################################################

	$vbsDummyScript = "
	Dim shell,fso,file
	Set shell=CreateObject(`"WScript.Shell`")
	Set fso=CreateObject(`"Scripting.FileSystemObject`")
	strPath=WScript.Arguments.Item(0)
	If fso.FileExists(strPath) Then
		set file=fso.GetFile(strPath)
		strCMD=`"powershell -nologo -executionpolicy ByPass -command `" & Chr(34) & `"&{`" &_ 
		file.ShortPath & `"}`" & Chr(34) 
		shell.Run strCMD,0
	End If
	"

	$scriptSavePathName="UEM-VBSHelper.vbs"

	$dummyScriptPath= $(Join-Path -Path $scriptSavePath -ChildPath $scriptSavePathName)
	
	$vbsDummyScript | Out-File -FilePath $dummyScriptPath -Force

	$wscriptPath = Join-Path $env:SystemRoot -ChildPath "System32\wscript.exe"

	###########################################################################################
	# Register a scheduled task to run for all users and execute the script on logon		  #
	###########################################################################################

	$schtaskName= "UEMTasks"
	$schtaskDescription="UEM task envoker"

	$trigger = New-ScheduledTaskTrigger -AtLogOn
	#Execute task in users context
	$principal= New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -Id "Author"
	#call the vbscript helper and pass the PosH script as argument
	$action = New-ScheduledTaskAction -Execute $wscriptPath -Argument "`"$dummyScriptPath`" `"$scriptPath`""
	$settings= New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
	
	$null=Register-ScheduledTask -TaskName $schtaskName -Trigger $trigger -Action $action  -Principal $principal -Settings $settings -Description $schtaskDescription -Force

	Start-ScheduledTask -TaskName $schtaskName
}

Stop-Transcript

###########################################################################################
# Done																					  #
###########################################################################################