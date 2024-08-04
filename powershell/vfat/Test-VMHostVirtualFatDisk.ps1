<#
    .DESCRIPTION
        Tests whether vFAT repair is necessary by checking for corruption on vFAT partitioned disk(s) using dosfsck..

    .PARAMETER VMHost
        Specifies one or more host(s).

    .PARAMETER Credential
        Specifies the root SSH credential.

    .EXAMPLE
        PS> $credential = Get-Credential
        PS> Get-VMHost -Name lab-m01-esx01.graa.dev | Test-VMHostVirtualFatDisk -Credential $credential

    .LINK
        https://knowledge.broadcom.com/external/article/345227/corrupted-vfat-partitions-from-esxi-6567.html
        https://linux.die.net/man/8/dosfsck
#>

#Requires -Modules 'Posh-SSH'

function Test-VMHostVirtualFatDisk {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
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
            if ($PSCmdlet.ShouldProcess($_VMHost.Name, 'Test Virtual FAT disk Consistency')) {
                try {
                    $vfat = $_VMHost | Get-VMHostVirtualFatDisk -Credential $Credential
                    $DiskIdentifier = ($vfat | Select-Object -ExpandProperty Disk)

                    $session = New-SSHSession -ComputerName $_VMHost.Name -Credential $Credential -Port 22 -AcceptKey:$true -ErrorAction Stop

                    $object = @()

                    foreach ($_diskIdentifier in $DiskIdentifier) {
                        $consistency = $false
                        $isVfat = $true

                        $check = Invoke-SSHCommand -Command ('dosfsck -Vv -n /dev/disks/{0}' -f $_diskIdentifier) -SSHSession $session -EnsureConnection

                        $hash = [Ordered]@{}

                        if ($null -ne $check.Output -and $check.Output -match 'First FAT') {
                            if ($check.ExitStatus -eq 0 -and $check.Output -notmatch 'corrupt') {
                                $consistency = $true
                            }
                        }
                        else {
                            $isVfat = $false
                        }

                        $hash.Add('VMHost', $_VMHost.Name)
                        $hash.Add('Disk', ('{0}' -f $_diskIdentifier))
                        $hash.Add('Consistent', $consistency)
                        $hash.Add('IsVirtualFatDisk', $isVfat)

                        $object += New-Object -TypeName PSCustomObject -Property $hash
                    }

                    $object
                }
                catch {
                    throw ("Error encountered testing Virtual FAT disk(s) consistency on VMHost '{0}', {1}" -f $_VMHost.Name, $_)
                }
                finally {
                    if ($null -ne $session) {
                        $null = $session | Remove-SSHSession
                    }
                }
            }
        }
    }
}