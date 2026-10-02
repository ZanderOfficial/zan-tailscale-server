# Registers a Windows scheduled task that starts WSL (and therefore Docker + the stack) at boot,
# before anyone signs in. Run in an ELEVATED PowerShell:  .\register-boot-task.ps1
#
# Uses S4U logon ("run whether user is logged on or not", no stored password).
# If WSL refuses to start under S4U on your build, re-run with -UsePassword and type your
# Windows password into the prompt yourself (it's stored by Task Scheduler, not in any file).
param([switch]$UsePassword, [string]$Distro = 'Ubuntu')

$ErrorActionPreference = 'Stop'
$TaskName = 'local-ai WSL keepalive'
$User = "$env:USERDOMAIN\$env:USERNAME"

$action   = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\wsl.exe" `
              -Argument "-d $Distro -u root -- /opt/local-ai/scripts/wsl-boot.sh"
$trigger  = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = 'PT30S'
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
              -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
              -StartWhenAvailable -MultipleInstances IgnoreNew

if ($UsePassword) {
  $cred = Get-Credential -UserName $User -Message 'Windows password for the boot task (stored by Task Scheduler)'
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
    -User $User -Password $cred.GetNetworkCredential().Password -RunLevel Limited -Force | Out-Null
} else {
  $principal = New-ScheduledTaskPrincipal -UserId $User -LogonType S4U -RunLevel Limited
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
    -Principal $principal -Force | Out-Null
}
Write-Host "Registered '$TaskName' for $User. Test now with: Start-ScheduledTask -TaskName '$TaskName'"
