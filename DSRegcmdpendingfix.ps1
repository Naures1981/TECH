###################################################################################################################
# Created by: Naures Shakarchi                                                                                    #
# Synopsis: Issues regarding Hybrid Domain Join pending state AAD object and re-creation of the AAD Device object #
###################################################################################################################
$Logfile = $MyInvocation.MyCommand.Path -replace '\.ps1$', '.log'

Start-Transcript -OutputDirectory c:\temp

$Dsregcmd = New-Object PSObject ; Dsregcmd /status | Where {$_ -match ' : '}|ForEach {$Item = $_.Trim() -split '\s:\s'; $Dsregcmd|Add-Member -MemberType NoteProperty -Name $($Item[0] -replace '[:\s]','') -Value $Item[1] -EA SilentlyContinue}

##############################
# Get the device AUTH status #
##############################

if ($dsregcmd.DeviceAuthStatus -eq "FAILED. Device is either disabled or deleted" -or $dsregcmd.DeviceAuthStatus -eq "FAILED") 
{
 dsregcmd /leave
 schtasks /Run /TN "Microsoft\Windows\Workplace Join\Automatic-Device-Join"
}

Stop-Transcript