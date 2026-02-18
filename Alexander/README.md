To run the password manager/changer (ADCHANGE.ps1), run the following:

PowerShell -ExecutionPolicy Bypass -File ADCHANGE.ps1
.\Bulk-Reset-ADPasswords.ps1 -PasswordCsvPath "C:\pwlist_batch1.csv" -OutputMappingPath "C:\mapping_batch1.csv" 

All other scripts should not require command-line arguments.
