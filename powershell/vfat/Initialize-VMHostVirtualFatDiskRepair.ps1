<#
    .DESCRIPTION
        Initializes vFAT repair by placing host in maintenance mode and turning off daemons that might have open file descriptors.

    .PARAMETER VMHost
        Specifies one or more host(s).

    .PARAMETER Credential
        Specifies the root SSH credential.

    .EXAMPLE
        PS> $credential = Get-Credential
        PS> Get-VMHost -Name lab-m01-esx01.graa.dev | Initialize-VMHostVirtualFatDiskRepair -Credential $credential

    .LINK
        https://knowledge.broadcom.com/external/article/345227/corrupted-vfat-partitions-from-esxi-6567.html
#>

#Requires -Modules 'Posh-SSH'

function Initialize-VMHostVirtualFatDiskRepair {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]$VMHost,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential
    )

    process {
        foreach ($_VMHost in $VMHost) {
            if ($_VMHost.Version -ge 8) {
                try {
                    if ($PSCmdlet.ShouldProcess($_VMHost.Name, 'Prepare for Virtual FAT Disk Repair')) {
                        $disks = $_VMHost | Test-VMHostVirtualFatDisk -Credential $Credential

                        $session = New-SSHSession -ComputerName $_VMHost.Name -Credential $Credential -Port 22 -AcceptKey:$true -ErrorAction Stop

                        $null = $_VMHost | Set-VMHost -State Maintenance

                        $command = Invoke-SSHCommand -Command 'kill $(cat /var/run/crond.pid)' -SSHSession $session -EnsureConnection
                        $command = Invoke-SSHCommand -Command '/usr/lib/vmware/vmsyslog/bin/shutdown.sh' -SSHSession $session -EnsureConnection
                        $command = Invoke-SSHCommand -Command '/etc/init.d/vmfstraced stop' -SSHSession $session -EnsureConnection
                        $command = Invoke-SSHCommand -Command '/etc/init.d/rhttpproxy stop' -SSHSession $session -EnsureConnection
                        $command = Invoke-SSHCommand -Command '/etc/init.d/vsandevicemonitord stop' -SSHSession $session -EnsureConnection
                    }

                    Write-Output ("You can now run the cmdlet 'Repair-VMHostVirtualFatDisk' on VMHost '{0}', then reboot the host" -f $_VMHost.Name)
                }
                catch {
                    throw ("Error encountered preparing VMHost '{0}' for Virtual FAT disk(s) repair: {1}. Reboot the host" -f $_VMHost.Name, $_)
                }
            }
            else {
                Write-Warning ("This cmdlet is only supported for vSphere version >= 8, and VMHost '{0}' is '{1}'" -f $_VMHost.Name, $_VMHost.Version)
            }
        }
    }
}