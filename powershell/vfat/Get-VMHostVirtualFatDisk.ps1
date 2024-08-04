function Get-VMHostVirtualFatDisk {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
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
            if ($PSCmdlet.ShouldProcess($_VMHost.Name, 'Retrieve Virtual FAT disk(s)')) {
                try {
                    $vfat = $_VMHost | Get-VMHostFileSystem -Type vfat
                    $PartitionIdentifier = ($vfat | Select-Object -ExpandProperty UUID)

                    $session = New-SSHSession -ComputerName $_VMHost.Name -Credential $credential -Port 22 -AcceptKey:$true -ErrorAction Stop 

                    $object = @()

                    foreach ($_partitionIdentifier in $PartitionIdentifier) {
                        $consistency = 'Unhealthy'

                        $output = Invoke-SSHCommand -Command ('vmkfstools -P /vmfs/volumes/{0}' -f $_partitionIdentifier) -SSHSession $session -EnsureConnection
                        $_diskIdentifier = (Select-String -InputObject $output.output -Pattern 'on "disks"\):(.*)Is Native').Matches.Groups[-1].Value.Trim()

                        if ($null -ne $_diskIdentifier) {
                            $hash = @{}
 
                           $hash.Add('VMHost', $_VMHost.Name)
                            $hash.Add('Disk', ('{0}' -f $_diskIdentifier))
                            $hash.Add('MountPoint', ('/vmfs/volumes/{0}' -f $_partitionIdentifier))

                            $object += New-Object -TypeName PSCustomObject -Property $hash
                        }
                    }

                    $object
                }
                catch {
                    throw ("Error encountered retrieving Virtual FAT disk(s) on VMHost '{0}': {1}" -f $_VMHost.Name, $_)
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