🛠️ Advanced System Identity Modifier

📝 Synopsis
A powerful tool designed to modify system identities, providing advanced features for hardware ID spoofing, anti-detection, and digital footprint management.

📋 Description
This comprehensive system identity modification tool offers:
- 🔧 Realistic Hardware ID Spoofing: Simulate or modify system identifiers like manufacturer and product name.
- 🕵️ Anti-Detection Measures: Add decoy information to obscure system tracking.
- 🧹 Digital Footprint Cleaning: Remove temporary files, logs, and command histories.
- 💾 Backup and Restore Functionality: Safeguard original settings for easy recovery.

⚠️ Notes
- Legal Warning: Modifying system identities may violate software End-User License Agreements (EULAs). Use only in controlled test environments or with explicit legal permission.
- Environment: Optimized for VMware virtual machines (e.g., VMware Workstation, ESXi) but adaptable to physical hardware with additional tools.

🖥️ For Windows (PowerShell Script)

📌 Requirements
- Operating System: Windows 10 or later (with PowerShell 5.1+).
- Permissions: Must be run as Administrator.
- Environment: Designed for VMware virtual machines.

🚀 Important Commands
1. Allow Script Execution:
   - Open Windows PowerShell as Administrator:
     - Press Win + X and select "Windows PowerShell (Admin)".
   - Run the following command to enable running custom scripts:
     ```
     Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
     ```
     - Confirm by typing Y if prompted.

2. Create the Script File:
   - Copy the PowerShell script to a file named system_identity_modifier.ps1.
   - Save it to an accessible location, e.g., Desktop:
     ```
     C:\Users\<YourUsername>\Desktop\Modify-windows-system-id.ps1
     ```

3. Run the Script:
   - In PowerShell (Admin), navigate to the script’s directory:
     ```
     cd $env:USERPROFILE\Desktop
     ```
   - Execute the script:
     ```
     .\Modify-windows-system-id.ps1
     ```

4. Interact with the Menu:
   - A menu will appear with options:
     ```
     === Advanced System Identity Modifier ===
     1. Automatic Full Modification (Recommended)
     2. Custom Modification
     3. Restore Original Settings
     4. Exit
     ```
   - Enter a number (1-4) to select an option.
   - After modifications, you may be prompted to reboot:
     ```
     Reboot now? (Y/N)
     ```
     - Type Y to apply changes like hostname updates.

5. Verify Changes (Optional):
   - Check system name:
     ```
     Get-ComputerInfo | Select-Object WindowsProductName, CsName
     ```
   - Check MAC address:
     ```
     Get-NetAdapter | Select-Object Name, MacAddress
     ```
   - Check backup:
     ```
     dir $env:USERPROFILE\Desktop\SystemID_Backup_*
     ```

✅ Done!
Your Windows system identity is now modified, with backups stored in C:\Users\<YourUsername>\Desktop\SystemID_Backup_*.

🐧 For Linux (Bash Script)

📌 Requirements
- Operating System: Debian-based (e.g., Ubuntu) or Red Hat-based (e.g., CentOS) Linux distribution.
- Permissions: Must be run with root privileges (sudo).
- Environment: Designed for VMware virtual machines.
- Dependencies: Requires dmidecode, virt-what, ip, and hostnamectl.

🚀 Important Commands
1. Install Required Tools:
   - Open a terminal (Ctrl+Alt+T on Ubuntu).
   - Update package lists and install tools:
     - For Ubuntu/Debian:
       ```
       sudo apt update
       sudo apt install dmidecode virt-what
       ```
     - For CentOS/RHEL:
       ```
       sudo yum install dmidecode virt-what
       ```

2. Verify Tool Installation:
   - Check if the required tools are installed:
     ```
     dmidecode --version
     virt-what --version
     ip --version
     hostnamectl --version
     ```

3. Make File Executable:
   - Grant execution permissions to the script:
     ```
     cd (folder path)
     chmod +x Modify-Linux-system-id.sh
     ```

4. Run the Script:
   - Execute script with root privileges:
     ```
     sudo bash Modify-Linux-system-id.sh
     ```

5. Interact with the Menu:
   - A menu will appear with options:
     ```
     === Advanced System Identity Modifier ===
     1. Automatic Full Modification (Recommended)
     2. Custom Modification
     3. Restore Original Settings
     4. Exit
     ```
   - Enter a number (1-4) to select an option.
   - After modifications, you may be prompted to reboot:
     ```
     Reboot now? (Y/N)
     ```
     - Type Y to apply changes like hostname updates:
       ```
       reboot
       ```

6. Verify Changes (Optional):
   - Check hostname:
     ```
     hostnamectl
     ```
   - Check MAC address:
     ```
     ip link
     ```
   - Check mocked hardware IDs:
     ```
     cat /tmp/mock_dmi/system_info
     ```


✅ Done!
Your Linux system identity is now modified, with backups stored in ~/system_backup_*.

📢 Additional Notes
- If MAC address changes fail in VMware, modify them manually in VMware settings:
  - Open VM settings > Network Adapter > Advanced > Set MAC address.
- Ensure backups are retained for restoration.
- Test scripts in a safe environment to avoid unintended system changes.
