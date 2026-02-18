# Disable SMBv1
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart

# Disable LLMNR
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0 -Type DWord

# Disable NetBIOS over TCP/IP (requires adapter index; replace 1 with your interface index from Get-NetAdapter)
Disable-NetAdapterBinding -Name "Ethernet" -ComponentID ms_netbios  # Adjust interface name

# Harden Kerberos: Disable weak encryption types (RC4, DES)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters" -Name "SupportedEncryptionTypes" -Value 2147483640 -Type DWord

# Disable WDigest to prevent cleartext credential storage
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name "UseLogonCredential" -Value 0 -Type DWord

# Enforce secure channel signing and sealing for Netlogon
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "SignSecureChannel" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "SealSecureChannel" -Value 1 -Type DWord

# Restart services to apply changes (minimal disruption on a fresh DC)
Restart-Service -Name Netlogon -Force
