# Convenience wrapper for managing the stack from Windows PowerShell.
# Usage: .\ai.ps1 status | start | stop | restart | logs [service] | verify | update | shell
param(
  [Parameter(Position = 0)][ValidateSet('status', 'start', 'stop', 'restart', 'logs', 'verify', 'update', 'shell')]
  [string]$Command = 'status',
  [Parameter(Position = 1)][string]$Service = ''
)
$Distro = 'Ubuntu'
$Dir = '/opt/local-ai'

function Invoke-Wsl([string]$cmd) { wsl.exe -d $Distro --cd $Dir -- bash -lc $cmd }

switch ($Command) {
  'status'  { Invoke-Wsl 'docker compose ps; echo; docker exec ollama ollama ps' }
  'start'   { Invoke-Wsl 'docker compose up -d' }
  'stop'    { Invoke-Wsl 'docker compose stop' }
  'restart' { Invoke-Wsl "docker compose restart $Service" }
  'logs'    { Invoke-Wsl "docker compose logs --tail=100 -f $Service" }
  'verify'  { Invoke-Wsl './scripts/verify.sh' }
  'update'  { Invoke-Wsl 'docker compose pull && docker compose up -d && docker image prune -f' }
  'shell'   { wsl.exe -d $Distro --cd $Dir }
}
