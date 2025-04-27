
#region Initialization
$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"
$backupDir = "$env:USERPROFILE\Desktop\SystemID_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$script:changesMade = $false
#endregion

#region Helper Functions
function Get-PlausibleValue {
    param (
        [string]$Type
    )
    
    switch ($Type) {
        "BIOS" {
            $vendors = @("Dell Inc.", "HP", "LENOVO", "ASUS", "American Megatrends Inc.")
            $vendor = $vendors | Get-Random
            $version = "$(Get-Random -Minimum 1 -Maximum 6).$(Get-Random -Minimum 0 -Maximum 30)"
            return "$vendor", "$version"
        }
        "MAC" {
            $prefixes = @("00155D", "005056", "000C29", "001C42", "001D0F")
            $prefix = $prefixes | Get-Random
            $suffix = -join ((1..3) | ForEach-Object { "{0:X2}" -f (Get-Random -Minimum 0 -Maximum 256) })
            return "$prefix$suffix" # Returns format like 00155D269BBE
        }
        "IP" {
            $commonSubnets = @("192.168", "10.0", "172.16")
            $subnet = $commonSubnets | Get-Random
            return "$subnet.$(Get-Random -Minimum 0 -Maximum 255).$(Get-Random -Minimum 1 -Maximum 254)"
        }
        "Hostname" {
            $prefixes = @("WS", "PC", "LAP", "SRV", "DEV")
            return "$($prefixes | Get-Random)-$(Get-Random -Minimum 1000 -Maximum 9999)"
        }
        default {
            return "UNKNOWN"
        }
    }
}

function Backup-SystemState {
    Write-Output "`n[+] Creating system backup..."
    
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir | Out-Null
    }

    # Backup critical registry keys
    $regKeys = @(
        "HKLM\HARDWARE\DESCRIPTION\System\BIOS",
        "HKLM\SYSTEM\CurrentControlSet\Control\SystemInformation",
        "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    )
    
    foreach ($key in $regKeys) {
        $fileName = ($key -replace '[\\:]', '_') + '.reg'
        reg export $key "$backupDir\$fileName" /y | Out-Null
    }

    # Backup network config
    ipconfig /all > "$backupDir\ipconfig.txt rewrited"
    Get-NetAdapter | Export-Csv "$backupDir\network_adapters.csv" -NoTypeInformation
    Get-WmiObject Win32_ComputerSystem | Export-Csv "$backupDir\system_info.csv" -NoTypeInformation

    Write-Output "[√] Backup saved to: $backupDir"
}
#endregion

#region Modification Functions
function Update-HardwareIDs {
    param (
        [bool]$automatic = $true,
        [string]$customManufacturer,
        [string]$customProductName
    )
    
    Write-Output "`n[+] Modifying hardware identifiers..."
    
    if ($automatic) {
        $biosVendor, $biosVersion = Get-PlausibleValue -Type "BIOS"
        $productName = "System-$(Get-Random -Minimum 1000 -Maximum 9999)"
    } else {
        $biosVendor = $customManufacturer
        $biosVersion = "1.$(Get-Random -Minimum 0 -Maximum 30)"
        $productName = $customProductName
    }

    $biosKeys = @{
        "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" = @{
            "SystemManufacturer" = $biosVendor
            "SystemProductName" = $productName
            "BIOSVersion" = $biosVersion
            "BaseBoardManufacturer" = $biosVendor
        }
        "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" = @{
            "SystemManufacturer" = $biosVendor
            "SystemProductName" = $productName
        }
    }

    foreach ($path in $biosKeys.Keys) {
        foreach ($value in $biosKeys[$path].Keys) {
            try {
                $current = Get-ItemPropertyValue -Path $path -Name $value -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $path -Name $value -Value $biosKeys[$path][$value] -Force
                Write-Output "  [→] Changed $value from '$current' to '$($biosKeys[$path][$value])'"
                $script:changesMade = $true
            } catch {
                Write-Output "  [!] Failed to modify $value in $path"
            }
        }
    }
}

function Update-NetworkConfiguration {
    param (
        [bool]$changeMAC = $true,
        [bool]$changeIP = $false
    )
    
    Write-Output "`n[+] Updating network configuration..."
    
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.MacAddress -ne $null }
    foreach ($adapter in $adapters) {
        # MAC Address modification
        if ($changeMAC) {
            try {
                $newMAC = Get-PlausibleValue -Type "MAC"
                # Check if NetworkAddress property is supported
                $propertyCheck = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | Where-Object { $_.RegistryKeyword -eq 'NetworkAddress' }
                
                if ($propertyCheck) {
                    $adapter | Set-NetAdapterAdvancedProperty -RegistryKeyword 'NetworkAddress' -RegistryValue $newMAC -ErrorAction Stop
                    # Restart adapter to apply changes
                    Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
                    Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
                    Write-Output "  [→] Changed MAC for $($adapter.Name) to $newMAC"
                    $script:changesMade = $true
                } else {
                    Write-Output "  [!] NetworkAddress property not supported for $($adapter.Name)"
                }
            } catch {
                Write-Output "  [!] Failed to change MAC for $($adapter.Name): $($_.Exception.Message)"
            }
        }

        # IP Address modification
        if ($changeIP) {
            $newIP = Get-PlausibleValue -Type "IP"
            $newGateway = $newIP -replace '\.\d+$','.1'
            
            $adapter | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
            $adapter | New-NetIPAddress -IPAddress $newIP -PrefixLength 24 -DefaultGateway $newGateway -ErrorAction SilentlyContinue
            Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses ("8.8.8.8","1.1.1.1") -ErrorAction SilentlyContinue
            
            Write-Output "  [→] Changed IP for $($adapter.Name) to $newIP"
            $script:changesMade = $true
        }
    }
}

function Update-SystemInformation {
    param (
        [bool]$changeHostname = $true,
        [bool]$changeRegistration = $true
    )
    
    Write-Output "`n[+] Updating system information..."
    
    # Computer name change
    if ($changeHostname) {
        $newName = Get-PlausibleValue -Type "Hostname"
        try {
            Rename-Computer -NewName $newName -Force -ErrorAction Stop
            Write-Output "  [→] Computer name will change to $newName after reboot"
            $script:changesMade = $true
        } catch {
            Write-Output "  [!] Failed to change computer name: $_"
        }
    }

    # Windows registration info
    if ($changeRegistration) {
        $users = @("Admin", "User", "Owner", "Administrator")
        $orgs = @("Home", "Private", "Personal", "Business")
        
        try {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "RegisteredOwner" -Value ($users | Get-Random) -Force
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "RegisteredOrganization" -Value ($orgs | Get-Random) -Force
            Write-Output "  [→] Modified Windows registration information"
            $script:changesMade = $true
        } catch {
            Write-Output "  [!] Failed to modify registration info: $_"
        }
    }
}

function Clear-SystemArtifacts {
    Write-Output "`n[+] Cleaning system artifacts..."
    
    # Event logs
    Get-EventLog -List | ForEach-Object { Clear-EventLog -LogName $_.Log }
    Write-Output "  [→] Cleared all event logs"

    # Temporary files
    $tempPaths = @(
        "$env:TEMP\*",
        "$env:WINDIR\Temp\*",
        "$env:USERPROFILE\AppData\Local\Temp\*",
        "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache\*"
    )
    
    $tempPaths | ForEach-Object { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Output "  [→] Removed temporary files"

    # PowerShell history
    Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue
    Write-Output "  [→] Cleared PowerShell history"
}
#endregion

#region Anti-Detection
function Add-DecoyInformation {
    Write-Output "`n[+] Adding decoy information..."
    
    $fakeKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\FakeApp",
        "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\FAKE_DEVICE"
    )

    foreach ($key in $fakeKeys) {
        try {
            if (-not (Test-Path $key)) {
                New-Item -Path $key -Force | Out-Null
                New-ItemProperty -Path $key -Name "DisplayName" -Value "Fake Component" -PropertyType String -Force | Out-Null
                New-ItemProperty -Path $key -Name "Version" -Value "1.0.$(Get-Random -Minimum 0 -Maximum 100)" -PropertyType String -Force | Out-Null
                Write-Output "  [→] Created decoy registry key: $key"
            }
        } catch {
            Write-Output "  [!] Failed to create decoy key $key"
        }
    }
}

function Protect-Modifications {
    Write-Output "`n[+] Protecting modifications..."
    
    $protectedKeys = @(
        "HKLM:\HARDWARE\DESCRIPTION\System\BIOS",
        "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation"
    )

    foreach ($key in $protectedKeys) {
        try {
            $acl = Get-Acl $key
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule("Users","ReadKey","Deny")
            $acl.AddAccessRule($rule)
            Set-Acl -Path $key -AclObject $acl
            Write-Output "  [→] Restricted permissions for: $key"
        } catch {
            Write-Output "  [!] Failed to protect $key"
        }
    }
}
#endregion

#region User Interface
function Show-MainMenu {
    Clear-Host
    Write-Output @"

=== Advanced System Identity Modifier ===
1. Automatic Full Modification (Recommended)
2. Custom Modification
3. Restore Original Settings
4. Exit
"@
}

function Show-CustomMenu {
    Clear-Host
    Write-Output @"

=== Custom Modification Options ===
1. Modify Hardware IDs
2. Change Network Configuration
3. Update System Information
4. Clean System Artifacts
5. Add Anti-Detection Measures
6. Return to Main Menu
"@
}

function Invoke-AutomaticMode {
    Write-Output "`n[!] Starting automatic modification..."
    Backup-SystemState
    Update-HardwareIDs -automatic $true
    Update-NetworkConfiguration -changeMAC $true -changeIP $false
    Update-SystemInformation -changeHostname $true -changeRegistration $true
    Clear-SystemArtifacts
    Add-DecoyInformation
    Protect-Modifications
    
    if ($script:changesMade) {
        Write-Output "`n[√] Automatic modifications completed successfully!"
        Write-Output "    Some changes require reboot to take effect."
    } else {
        Write-Output "`n[!] No changes were made during automatic mode"
    }
}

function Invoke-CustomMode {
    do {
        Show-CustomMenu
        $choice = Read-Host "`nSelect an option (1-6)"
        
        switch ($choice) {
            "1" { 
                Backup-SystemState
                $man = Read-Host "Enter custom manufacturer (or leave blank for random)"
                $prod = Read-Host "Enter custom product name (or leave blank for random)"
                
                if ([string]::IsNullOrEmpty($man) -or [string]::IsNullOrEmpty($prod)) {
                    Update-HardwareIDs -automatic $true
                } else {
                    Update-HardwareIDs -automatic $false -customManufacturer $man -customProductName $prod
                }
            }
            "2" { 
                $mac = Read-Host "Change MAC addresses? (Y/N)"
                $ip = Read-Host "Change IP configuration? (Y/N)"
                Update-NetworkConfiguration -changeMAC ($mac -eq 'Y') -changeIP ($ip -eq 'Y')
            }
            "3" { 
                $hostname = Read-Host "Change computer name? (Y/N)"
                $reg = Read-Host "Modify registration info? (Y/N)"
                Update-SystemInformation -changeHostname ($hostname -eq 'Y') -changeRegistration ($reg -eq 'Y')
            }
            "4" { Clear-SystemArtifacts }
            "5" { 
                Add-DecoyInformation
                Protect-Modifications
            }
            "6" { return }
            default { Write-Output "Invalid selection" }
        }
        
        if ($choice -ne "6") {
            Pause
        }
    } while ($choice -ne "6")
}

function Restore-OriginalSettings {
    Write-Output "`n[!] Restoring original settings..."
    
    if (Test-Path $backupDir) {
        # Restore registry keys
        Get-ChildItem "$backupDir\*.reg" | ForEach-Object {
            try {
                reg import $_.FullName
                Write-Output "  [→] Restored registry key from $($_.Name)"
            } catch {
                Write-Output "  [!] Failed to restore $($_.Name)"
            }
        }
        
        # Note: MAC/IP restoration would require additional implementation
        Write

-Output "`n[√] Original settings restored from backup"
        Write-Output "    Some restorations may require reboot to take effect"
    } else {
        Write-Output "[!] No backup found to restore from"
    }
}
#endregion

#region Main Execution
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "`n[!] ERROR: This script must be run as Administrator!"
    exit
}

do {
    Show-MainMenu
    $mainChoice = Read-Host "`nSelect an option (1-4)"
    
    switch ($mainChoice) {
        "1" { Invoke-AutomaticMode }
        "2" { Invoke-CustomMode }
        "3" { Restore-OriginalSettings }
        "4" { exit }
        default { Write-Output "Invalid selection" }
    }
    
    if ($mainChoice -ne "4") {
        $reboot = Read-Host "`nReboot now? (Y/N)"
        if ($reboot -eq 'Y' -or $reboot -eq 'y') {
            Restart-Computer -Force
        }
    }
} while ($mainChoice -ne "4")
#endregion
