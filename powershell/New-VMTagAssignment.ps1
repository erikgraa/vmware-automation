 <#
    .DESCRIPTION
    Assigns tag(s) to new VMs.

    .PARAMETER Tag
    Specifies the tag(s).

    .PARAMETER Start
    Specifies the start time to look for new VM creation events.

    .PARAMETER Finish
    Specifies the finish time to look for new VM creation events.

    .EXAMPLE
    Get-Tag -Name 'TestTag-1','TestTag-2' | New-VMTagAssignment -Start (Get-Date).AddHours(-1) -Finish (Get-Date) -Pattern 'W11-VDI-\d+'

    .OUTPUTS
    Void.
#>


function New-VMTagAssignment {
  [OutputType([Void])]
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [VMware.VimAutomation.VICore.Types.V1.Tagging.Tag[]]$Tag,

    [Parameter(Mandatory=$false)]
    [DateTime]$Start,

    [Parameter(Mandatory=$false)]
    [DateTime]$Finish,

    [Parameter(Mandatory=$false)]
    [String]$Pattern
  )

    begin {
        $splat = @{}

        $eventPattern = 'Created virtual machine'

        if ($PSBoundParameters.ContainsKey('Start')) {
            $splat.Add('Start', $Start)
        }

        if ($PSBoundParameters.ContainsKey('Finish')) {
            $splat.Add('Finish', $Finish)
        }

        $fullEventPattern = if ($PSBoundParameters.ContainsKey('Pattern')) {
            ('{0}\s({1})\son.+' -f $eventPattern, $Pattern)
        }
        else {
            ('{0}\s(.*)\son' -f $eventPattern)
        }

        $events = Get-VIEvent @splat | Where-Object { $_.FullFormattedMessage -match $fullEventPattern }

        $vm = @()
        
        foreach ($_event in $events) {
          $name = (Select-String -InputObject $_event.FullFormattedMessage -Pattern $fullEventPattern).Matches.Groups[-1].Value
          $vm += Get-VM -Name $name
        }
    }

    process {
        foreach ($_tag in $Tag) {
            foreach ($_vm in $vm) {                      
                Write-Output ("Assigning tag '{0}' to VM '{1}'" -f $_tag.Name, $_vm.Name)
                if (-not(Get-TagAssignMent -Entity $_vm -Tag $_tag)) {
                    $null = New-TagAssignment -Entity $_vm -Tag $_tag
                }
            }
        }
    }

    end { }
}