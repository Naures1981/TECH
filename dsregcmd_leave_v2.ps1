###################################################################################################################
# Created by: Naures Shakarchi                                                                                    #
# Synopsis: Issues regarding Hybrid Domain Join pending state AAD object and re-creation of the AAD Device object #
###################################################################################################################

$Dsregcmd = New-Object PSObject ; Dsregcmd /status | Where {$_ -match ' : '}|ForEach {$Item = $_.Trim() -split '\s:\s'; $Dsregcmd|Add-Member -MemberType NoteProperty -Name $($Item[0] -replace '[:\s]','') -Value $Item[1] -EA SilentlyContinue}

###########################################
# Get status of Primary Refresh Token AAD #
###########################################

if ($dsregcmd.AzureAdJoined -eq "NO")
{
 dsregcmd /leave
 schtasks /Run /TN “Microsoft\Windows\Workplace Join\Automatic-Device-Join”
}
