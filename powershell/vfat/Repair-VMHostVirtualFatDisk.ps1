function Repair-VMHostVirtualFatDisk {
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
            try {
                $disks = $_VMHost | Test-VMHostVirtualFatDisk -Credential $credential -Verbose:$false

                $session = New-SSHSession -ComputerName $_VMHost.Name -Credential $credential -Port 22 -AcceptKey:$true -Verbose:$false -ErrorAction Stop

                $object = @()

                foreach ($_disk in $disks) {
                    if ($PSCmdlet.ShouldProcess($_disk.Disk, ("Repair Virtual FAT disk on VMHost '{0}'" -f $_VMHost.Name))) {
                        if ($_disk.IsVirtualFatDisk -eq $true) {
                            if ($_disk.Consistent -ne $true) {
                                $repair = Invoke-SSHCommand -Command ('dosfsck -a -w /dev/disks/{0}' -f $_disk.Disk) -SSHSession $session -EnsureConnection -Verbose:$false

                                if ($repair.ExitStatus -eq 0) {
                                    Write-Verbose ("Repaired disk '{0}' on VMHost '{1}'", $_disk.Disk, $_VMHost.Name)
                                }
                                else {
                                    Write-Warning ("Error occurred while repairing disk '{0}' on VMHost '{1}'", $_disk.Disk, $_VMHost.Name)
                                }
                            }
                            else {
                                Write-Verbose ("Disk '{0}' on VMHost '{1}' is consistent and healthy" -f $_disk.Disk, $_VMHost.Name)
                            }
                        }
                        else {
                            Write-Verbose ("Disk '{0}' on VMHost '{1}' is not partitioned as Virtual Fat (VFAT)" -f $_disk.Disk, $_VMHost.Name)
                        }
                    }
                }  

                $object
            }
            catch {
                throw ("Error encountered repairing Virtual FAT disk(s) on VMHost '{0}': {1}" -f $_VMHost.Name, $_)
            }
            finally {
                if ($null -ne $session) {
                    $null = $session | Remove-SSHSession
                }
            }
        }
    }
}