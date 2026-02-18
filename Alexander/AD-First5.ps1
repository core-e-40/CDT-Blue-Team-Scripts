Write-Host "=== AD First 5 Check ==="
Write-Host "Start Time:" (Get-Date)

# Check Domain Admins
Write-Host "`n[1] Domain Admins:"
try {
    Get-ADGroupMember "Domain Admins" | Select Name
}
catch { Write-Host "Error checking Domain Admins" }

# Check Enterprise Admins
Write-Host "`n[2] Enterprise Admins:"
try {
    Get-ADGroupMember "Enterprise Admins" | Select Name
}
catch { Write-Host "Error checking Enterprise Admins" }

# Recent Users
Write-Host "`n[3] Recently Created Users:"
try {
    Get-ADUser -Filter * -Properties whenCreated |
    Sort whenCreated -Descending |
    Select -First 5 Name, whenCreated
}
catch { Write-Host "Error retrieving users" }

# Scheduled Tasks
Write-Host "`n[4] Scheduled Tasks:"
Get-ScheduledTask | Where {$_.State -eq "Ready"} |
Select TaskName, TaskPath

# Automatic Services
Write-Host "`n[5] Auto Services:"
Get-Service | Where {$_.StartType -eq "Automatic"} |
Select Name, Status

# Enable Logon Auditing
Write-Host "`n[6] Enabling Audit Logging"
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
auditpol /set /subcategory:"Account Logon" /success:enable /failure:enable

# Recent Logins
Write-Host "`n[7] Recent Logins:"
Get-EventLog Security -InstanceId 4624 -Newest 10

Write-Host "`n[8] Recent TGT Requests:"
Get-EventLog Security -InstanceId 4768 -Newest 10

Write-Host "`n[9] Purging Kerberos Tickets:"
klist purge
klist -li 0x3e7 purge

Write-Host "`n=== Completed ==="
