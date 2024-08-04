<#
    .DESCRIPTION
       Retrieves file systems on host(s).

    .PARAMETER VMHost
        Specifies one or more host(s).

    .PARAMETER Credential
        Specifies the root SSH credential.

    .EXAMPLE
        PS> $credential = Get-Credential
        PS> Get-VMHost -Name lab-m01-esx01.graa.dev | Get-VMHostFileSystem -Credential $credential

    .LINK
        https://knowledge.broadcom.com/external/article/345227/corrupted-vfat-partitions-from-esxi-6567.html
#>

function Get-VMHostFileSystem {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]$VMHost,

        [Parameter(Mandatory=$false)]
        [ValidateSet('VFFS', 'VMFS-6', 'vfat')]
        [String]$Type
    )

    process {
        foreach ($_VMHost in $VMHost) {
            if ($PSCmdlet.ShouldProcess($_VMHost.Name, 'Retrieve File System(s)')) {
                try {
                    $esxCli = $_VMHost | Get-ESXCli -V2

                    $storage = $esxCli.storage.filesystem.list.Invoke()

                    if ($PSBoundParameters.ContainsKey('Type')) {
                        $storage = $storage | Where-Object { $_.Type -eq $Type }
                    }

                    $storage
                }
                catch {
                    throw ("Error encountered retrieving File System(s) on VMHost '{0}': {1}" -f $_VMHost.Name, $_)
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