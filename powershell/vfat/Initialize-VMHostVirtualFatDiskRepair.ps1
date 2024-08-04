function Initialize-VMHostVirtualFatDiskRepair {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]$VMHost,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$credential
    )

    process {
        foreach ($_VMHost in $VMHost) {
            if ($PSCmdlet.ShouldProcess($_disk.Disk, ("Prepare for repair of Virtual FAT disks(s) on VMHost '{0}'" -f $_VMHost.Name))) {
                try {
                    $disks = $_VMHost | Test-VMHostVirtualFatDisk -Credential $credential

                    if ($PSCmdlet.ShouldProcess($_VMHost.Name, 'Prepare for Virtual FAT Disk Repair')) {
                        $session = New-SSHSession -ComputerName $_VMHost.Name -Credential $credential -Port 22 -AcceptKey:$true -ErrorAction Stop

                        $null = $_VMHost | Set-VMHost -State Maintenance

                        $command = Invoke-SSHCommand -Command 'kill $(cat /var/run/crond.pid)' -SSHSession $session -EnsureConnection
                        $command = Invoke-SSHCommand -Command '/usr/lib/vmware/vmsyslog/bin/shutdown.sh' -SSHSession $session -EnsureConnection
                        $command = Invoke-SSHCommand -Command '/etc/init.d/vmfstraced stop' -SSHSession $session -EnsureConnection
                        $command = Invoke-SSHCommand -Command '/etc/init.d/rhttpproxy stop' -SSHSession $session -EnsureConnection
                        $command = Invoke-SSHCommand -Command '/etc/init.d/vsandevicemonitord stop' -SSHSession $session -EnsureConnection
                    }
                }
                catch {
                    throw ("Error encountered preparing VMHost '{0}' for Virtual FAT disk(s) repair: {1}" -f $_VMHost.Name, $_)
                }
                finally {
                    $null = $_VMHost | Set-VMHost -State Connected
                }
            }
        }
    }
}