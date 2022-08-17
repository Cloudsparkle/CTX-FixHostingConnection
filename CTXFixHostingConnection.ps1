<#
.SYNOPSIS

.DESCRIPTION

.INPUTS
  Hosting Connections
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  17/08/2022
  Purpose/Change: Fix Citrix CVAD Hosting connection VCA cert
 .EXAMPLE
  None
#>
# Try loading Citrix Powershell modules, exit when failed
If ((Get-PSSnapin "Citrix*" -EA silentlycontinue) -eq $null)
{
  try {Add-PSSnapin Citrix* -ErrorAction Stop }
  catch {Write-error "Error loading Citrix Powershell snapins"; Return }
}

# Get ready for GUI stuff
Add-Type -AssemblyName PresentationFramework

# Initialize variables
$NEWHC_NAME = ""
$BADHC_NAME = ""
$cred = ""

$HC = Get-ChildItem XDHyp:\Connections | Select-object HypervisorConnectionName
$NEWHC_NAME = $HC | Out-GridView -Title "Select the newly created Hosting Connection" -OutputMode Single
if ($NEWHC_NAME -eq $null)
{
  $msgBoxInput = [System.Windows.MessageBox]::Show("Newly created Hosting Connection not selected","Error","OK","Error")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 1
    }
  }
}

$BADHC_NAME = $HC | Out-GridView -Title "Select the broken Hosting Connection" -OutputMode Single
if ($BADHC_NAME -eq $null)
{
  $msgBoxInput = [System.Windows.MessageBox]::Show("Broken Hosting Connection not selected","Error","OK","Error")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 1
    }
  }
}

if ($NEWHC_NAME -eq $BADHC_NAME)
{
  $msgBoxInput = [System.Windows.MessageBox]::Show("The same Hosting Connection was selected twice","Error","OK","Error")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 1
    }
  }
}

$NEWHC_PATH = "XDHYP:\Connections\"+$NEWHC_NAME.HypervisorConnectionName
Try
{
    $NEWHC = get-item -LiteralPath $NEWHC_PATH -ErrorAction Stop
}
catch
{
  $msgBoxInput = [System.Windows.MessageBox]::Show("Error retreiving $NEWHC_NAME ","Error","OK","Error")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 1
    }
  }
}

$NEWHC_SSL = $NEWHC.SslThumbprints

$BADHC_PATH = "XDHYP:\Connections\"+$BADHC_NAME.HypervisorConnectionName
try
{
    $BADHC = get-item -LiteralPath $BADHC_PATH -ErrorAction Stop
}
catch
{
  $msgBoxInput = [System.Windows.MessageBox]::Show("Error retreiving $NEWHC_NAME ","Error","OK","Error")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 1
    }
  }
}

$cred = Get-Credential -Message "Enter credentials for the Hosting Connection Service Account"
if ($cred -eq $null)
{
  $msgBoxInput = [System.Windows.MessageBox]::Show("Service Account credentials not provided","Error","OK","Error")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 1
    }
  }
}

try
{
    Set-Item -LiteralPath $BADHC_PATH -username $cred.username -Securepassword $cred.password -SslThumbprint $NEWHC_SSL -hypervisorAddress $BADHC.HypervisorAddress
}
catch
{
  $msgBoxInput = [System.Windows.MessageBox]::Show("Error fixing Hosting Connection $BADHC_NAME","Error","OK","Error")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 1
    }
  }
}
