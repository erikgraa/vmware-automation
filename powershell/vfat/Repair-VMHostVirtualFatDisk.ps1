<#
    .DESCRIPTION
        Repairs vFAT partitioned disk(s) using dosfsck. A reboot is necessary post-repair.

    .PARAMETER VMHost
        Specifies one or more host(s).

    .PARAMETER Credential
        Specifies the root SSH credential.

    .EXAMPLE
        PS> $credential = Get-Credential
        PS> Get-VMHost -Name lab-m01-esx01.graa.dev | Repair-VMHostVirtualFatDisk -Credential $credential

    .LINK
        https://knowledge.broadcom.com/external/article/345227/corrupted-vfat-partitions-from-esxi-6567.html
        https://linux.die.net/man/8/dosfsck
#>

#Requires -Modules 'Posh-SSH'

function Repair-VMHostVirtualFatDisk {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]$VMHost,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential
    )

    process {
        foreach ($_VMHost in $VMHost) {
            try {
                $disks = $_VMHost | Test-VMHostVirtualFatDisk -Credential $Credential -Verbose:$false

                $session = New-SSHSession -ComputerName $_VMHost.Name -Credential $credential -Port 22 -AcceptKey:$true -Verbose:$false -ErrorAction Stop

                foreach ($_disk in $disks) {
                    if ($PSCmdlet.ShouldProcess($_disk.Disk, ("Repair Virtual FAT disk on VMHost '{0}'" -f $_VMHost.Name))) {

                        if ($_disk.IsVirtualFatDisk -ne $true) {
                            Write-Output ("Disk '{0}' on VMHost '{1}' is not partitioned as Virtual Fat (VFAT)" -f $_disk.Disk, $_VMHost.Name)
                            return
                        }
                        
                        if ($_disk.Consistent -eq $true) {
                            Write-Output ("Disk '{0}' on VMHost '{1}' is consistent and healthy" -f $_disk.Disk, $_VMHost.Name)
                            return
                        }

                        $command = Invoke-SSHCommand -Command ('dosfsck -a -w /dev/disks/{0}' -f $_disk.Disk) -SSHSession $session -EnsureConnection -Verbose:$false

                        if ($command.ExitStatus -ne 1) {
                            Write-Warning ("Error may have occurred while repairing disk '{0}' on VMHost '{1}', review the output: {2}" -f $_disk.Disk, $_VMHost.Name, $_)
                        }

                        Write-Output ("Repaired disk '{0}' on VMHost '{1}'" -f $_disk.Disk, $_VMHost.Name)
                    }
                }
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
