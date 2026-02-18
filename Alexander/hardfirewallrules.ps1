# Enable firewall for all profiles
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Block inbound on public profile (if exposed)
Set-NetFirewallProfile -Profile Public -DefaultInboundAction Block -DefaultOutboundAction Allow -AllowInboundRules False

# Explicitly allow core DC ports (examples; customize as needed)
New-NetFirewallRule -DisplayName "Allow LDAP" -Direction Inbound -Protocol TCP -LocalPort 389 -Action Allow
New-NetFirewallRule -DisplayName "Allow Secure LDAP" -Direction Inbound -Protocol TCP -LocalPort 636 -Action Allow
New-NetFirewallRule -DisplayName "Allow Kerberos" -Direction Inbound -Protocol TCP -LocalPort 88 -Action Allow
New-NetFirewallRule -DisplayName "Allow SMB" -Direction Inbound -Protocol TCP -LocalPort 445 -Action Allow  # Only if needed internally

# Block common risky ports (e.g., RDP if not needed)
New-NetFirewallRule -DisplayName "Block RDP Inbound" -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Block

# Apply changes
netsh advfirewall set allprofiles state on
