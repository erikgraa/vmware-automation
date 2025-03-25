  <#
    .DESCRIPTION
    Retrieves VMware port list.

    .EXAMPLE
    Get-VMwarePortList

    .OUTPUTS
    PSCustomObject.

    .LINK
    https://ports.broadcom.com/
#>

function Get-VMwarePortList {
  [CmdletBinding()]
  [OutputType([HashTable])]
  param ()

  begin {
    $baseUri = 'https://ports.esp.spespg1.vmw.saas.broadcom.com/manage/view/v1/vmwareproducts'

    $products = Invoke-RestMethod -Uri $baseUri -Method Get

    $hash = [Ordered]@{}    
  }

  process {
    foreach ($_product in ($products | Sort-Object -Property productName)) {
      $ports = Invoke-RestMethod -Uri ('{0}/{1}/listings1' -f $baseUri, $_product.id) -Method Get

      if (($ports | Measure-Object).Count -ne 0) {
        $hash.Add($_product.productName, $ports)
      }
    }
  }

  end {
    $hash
  }
}