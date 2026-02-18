To run the password manager/changer (ADCHANGE.ps1), run the following:

curl -O https://raw.githubusercontent.com/core-e-40/CDT-Blue-Team-Scripts/refs/heads/main/Alexander/ADCHANGE.ps1
PowerShell -ExecutionPolicy Bypass -File ADCHANGE.ps1
.\Bulk-Reset-ADPasswords.ps1 -PasswordCsvPath "C:\pwlist_batch1.csv" -OutputMappingPath "C:\mapping_batch1.csv" 

All other scripts should not require command-line arguments.

"defender.ps1" will try and install Windows Defender and enable its protection. Can possibly be blocked if all defender functionality is removed from the box beforehand.

"disabledeprecation.ps1" will disable SMBv1, LLMNR/NetBIOS, weak Kerberos encryption (RC4/DES), and WDigest. However, if any scoring services require old Kerberos encryption, then it will break scoring.

"fulladvlogging.ps1" enables nearly all options for Advanced Logging on AD.

"restrictanonaccess.ps1" will prevent unauthorized enumeration and protects LSASS from credential dumping. However, may be a little sketchy with access control, might be chill too idk.

"hardfirewallrules.ps1" will block unnecessary inbound traffic while allowing ONLY DC essentials. VERY LOCKED DOWN RULES, I would not recommend. It's also implicit block all.
