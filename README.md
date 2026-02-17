# Blue Team README
## Max
- Disabled_LLMNR_netBIOS_mDNS.ps1 - No reboot required
```
Disables LLMNR, netBIOS, mDNS

powershell -executionpolicy bypass -file .\Disabled_LLMNR_netBIOS_mDNS.ps1
```
- Windows-Disable-UserAccess - Reboots workstation
```
Disables Local & Remote Interactive Logon
Disables Shell Access
Disables SSH Access
Disabled Port Forwarding + Tunneling

powershell -executionpolicy bypass -file .\Windows-Disable-UserAccess.ps1 'cyberrange'
```
- Linux-Disable-User.sh - Restarts ssh
```
Disables login
Disables shell access
Disables ssh access
Disables TCP Forwarding, Port forwarding + Tunnels

sudo ./Linux-Disable-User.sh cyberrange
```
