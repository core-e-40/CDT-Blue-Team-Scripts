Write-Host "=== Windows Hardening Check ==="
Write-Host "Start Time:" (Get-Date)

# Local Admins
Write-Host "`n[1] Local Administrators:"
net localgroup Administrators

Write-Host "`n[2] Logged-in Users:"
query user

# Scheduled Tasks
Write-Host "`n[3] Scheduled Tasks:"
schtasks /query /fo LIST /v

# Running Processes
Write-Host "`n[4] Running Processes:"
tasklist

# Disable Remote Registry
Write-Host "`n[5] Disabling Remote Registry"
try {
    sc.exe stop RemoteRegistry
    sc.exe config RemoteRegistry start= disabled
}
catch { Write-Host "Remote Registry already disabled" }

# Enable Firewall
Write-Host "`n[6] Enabling Firewall"
netsh advfirewall set allprofiles state on

# Recent Logins
Write-Host "`n[7] Recent Logins:"
Get-EventLog Security -InstanceId 4624 -Newest 10

Write-Host "`n=== Completed ==="
