try {
  Write-Host "Installing defender components..."
  Install-WindowsFeature -Name Windows-Defender-Features
  Install-WindowsFeature -Name Windows-Defender-GUI
  Write-Host "Done!"
} catch {
  Write-Host "Error encountered, exiting..."
}


Write-Host "Starting defender..."
Start-Service WinDefend

Write-Host "Setting options..."
Set-MpPreference -DisableRealtimeMonitoring $false
Set-MpPreference -DisableIOAVProtection $false
Set-MpPreference -DisableBehaviorMonitoring $false
Set-MpPreference -DisableOnAccessProtection $false

Write-Host "Defender status:"
Get-MpComputerStatus
