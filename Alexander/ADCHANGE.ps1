<#
.SYNOPSIS
    Combined AD/Local Management script for changing passwords and managing AD users.
    
.DESCRIPTION
    1. Resets AD passwords for whitelisted users.
    2. Disables any AD account NOT in the whitelist.
    3. Prompts to delete/cleanup Local accounts NOT in the whitelist.
    4. Logs everything to a central CSV mapping.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$PasswordCsvPath,

    [Parameter(Mandatory=$true)]
    [string]$OutputMappingPath,

    [string]$SearchBase = "", 
    [switch]$HasHeader = $false,
    [switch]$RecyclePasswords = $true,
    [switch]$DryRun = $false
)

# --- CONFIGURATION: Whitelists and Exclusions ---

# 1. Accounts that should STAY ENABLED (The Whitelist)
$keepEnabledList = @(
    ""
)

# 2. Accounts that should NEVER have their password changed
$pwResetExclusionList = @(
    ""
)

# 3. Built-in locals to ignore during cleanup
$builtInLocalAccounts = @("administrator", "guest", "defaultaccount", "wdagutilityaccount", "krbtgt")

# --- Initialization ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not [System.IO.Path]::IsPathRooted($PasswordCsvPath)) { $PasswordCsvPath = Join-Path $ScriptDir $PasswordCsvPath }

try { Import-Module ActiveDirectory -ErrorAction Stop } catch { Write-Error "AD Module Missing."; return }

if (-not (Test-Path $PasswordCsvPath)) { Write-Error "CSV not found: $PasswordCsvPath"; return }
$passwordLines = Get-Content $PasswordCsvPath | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
if ($HasHeader) { $passwordLines = $passwordLines[1..($passwordLines.Count - 1)] }

$results = @()
$pwIndex = 0

# --- PART 1: ACTIVE DIRECTORY PROCESSING ---
Write-Host "--- Starting AD Account Processing ---" -ForegroundColor Yellow
$adUsers = if ([string]::IsNullOrWhiteSpace($SearchBase)) { Get-ADUser -Filter * -Properties Enabled } else { Get-ADUser -Filter * -SearchBase $SearchBase -Properties Enabled }

foreach ($u in $adUsers) {
    $sam = $u.SamAccountName.ToLower()
    $isWhitelisted = $keepEnabledList -contains $sam
    $isPwExcluded = $pwResetExclusionList -contains $sam
    $action = ""
    $pwUsed = "N/A"

    # Disable Logic
    if (-not $isWhitelisted) {
        if ($u.Enabled -and -not $DryRun) { Set-ADUser -Identity $u.SamAccountName -Enabled $false }
        $action += "[Disabled AD Account] "
    } else {
        $action += "[Kept Enabled] "
        
        # Password Reset Logic (Only for active whitelisted users)
        if (-not $isPwExcluded) {
            $pw = $passwordLines[$pwIndex % $passwordLines.Count]
            $pwUsed = $pw
            if (-not $DryRun) {
                $securePw = ConvertTo-SecureString $pw -AsPlainText -Force
                Set-ADAccountPassword -Identity $u.SamAccountName -Reset -NewPassword $securePw -ErrorAction SilentlyContinue
                Set-ADUser -Identity $u.SamAccountName -ChangePasswordAtLogon $true -PasswordNeverExpires $false
            }
            $action += "[PW Reset] "
            $pwIndex++
        } else {
            $action += "[PW Excluded] "
        }
    }

    Write-Host "AD User: $sam -> $action" -ForegroundColor Cyan
    $results += [PSCustomObject]@{ Account=$sam; Type="AD"; Action=$action; Password=$pwUsed; Timestamp=(Get-Date).ToString() }
}

# --- PART 2: LOCAL ACCOUNT PROCESSING ---
Write-Host "`n--- Starting Local Account Audit ---" -ForegroundColor Yellow
$localUsers = try { Get-LocalUser } catch { Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount = TRUE" }

foreach ($l in $localUsers) {
    $name = $l.Name.ToLower()
    if ($keepEnabledList -contains $name -or $builtInLocalAccounts -contains $name) {
        Write-Host "Local User: $name -> [Whitelisted/Built-in]" -ForegroundColor Green
        continue
    }

    # If not whitelisted, prompt for deletion (as per your second script's logic)
    $resp = Read-Host "Extra local account '$name' found. Delete? (y/N)"
    if ($resp -eq 'y') {
        if (-not $DryRun) {
            try { Remove-LocalUser -Name $l.Name -ErrorAction Stop } catch { & net user $l.Name /delete }
            Write-Host "Deleted $name" -ForegroundColor Red
            $results += [PSCustomObject]@{ Account=$name; Type="Local"; Action="Deleted"; Password="N/A"; Timestamp=(Get-Date).ToString() }
        } else {
            Write-Host "DryRun: Would delete $name"
        }
    }
}

# --- Export ---
$results | Export-Csv -Path $OutputMappingPath -NoTypeInformation -Force
Write-Host "`nMaster Report saved to: $OutputMappingPath" -ForegroundColor Green
