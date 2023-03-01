<#
.SYNOPSIS
  Replace bad VMware cert on hosting connection
.DESCRIPTION
  Fix a broken Hosting Connection due to bad/expired/changed VMware VCA cert
.INPUTS
  Hosting Connections
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  17/08/2022
  Purpose/Change: Fixes Citrix CVAD Hosting connection VCA cert
 .EXAMPLE
  None
#>
# Try loading Citrix Powershell modules, exit when failed
If ((Get-PSSnapin "Citrix*" -EA silentlycontinue) -eq $null)
{
  try {Add-PSSnapin Citrix* -ErrorAction Stop }
  catch {Write-error "Error loading Citrix Powershell snapins"; Return }
}

# Initialize variables
$NEWHC_NAME = ""
$BADHC_NAME = ""
$cred = ""

Write-Host "Selecting newly created Hosting Connection..." -ForegroundColor Yellow
$HC = Get-ChildItem XDHyp:\Connections | Select-object HypervisorConnectionName
$NEWHC_NAME = $HC | Out-GridView -Title "Select the newly created Hosting Connection" -OutputMode Single
if ($NEWHC_NAME -eq $null)
{
  write-host "Newly created Hosting Connection not selected, exiting" -ForegroundColor Red
  Exit 1
}
Else
{
  Write-Host "New Hosting Connection selected" -ForegroundColor Green
}

Write-Host "Selecting Broken Hosting Connection..." -ForegroundColor Yellow
$BADHC_NAME = $HC | Out-GridView -Title "Select the broken Hosting Connection" -OutputMode Single
if ($BADHC_NAME -eq $null)
{
  write-host "Broken Hosting Connection not selected, exiting" -ForegroundColor Red
  Exit 1
}
Else
{
  Write-Host "Broken Hosting Connection selected" -ForegroundColor Green
}

if ($NEWHC_NAME -eq $BADHC_NAME)
{
  write-host "The same Hosting Connection was selected twice, exiting" -ForegroundColor Red
  Exit 1
}

Write-Host "Retrieving $NEWHC_NAME..." -ForegroundColor Yellow
$NEWHC_PATH = "XDHYP:\Connections\"+$NEWHC_NAME.HypervisorConnectionName
Try
{
  $NEWHC = get-item -LiteralPath $NEWHC_PATH -ErrorAction Stop
}
catch
{
  write-host "Error retrieving $NEWHC_NAME, exiting" -ForegroundColor Red
  Exit 1
}
Write-Host "Gathering SSL Thumbprints..." -ForegroundColor Yellow
$NEWHC_SSL = $NEWHC.SslThumbprints
Write-Host "SSL Thumbprints succesfully gathered" -ForegroundColor Green

$BADHC_PATH = "XDHYP:\Connections\"+$BADHC_NAME.HypervisorConnectionName
try
{
  $BADHC = get-item -LiteralPath $BADHC_PATH -ErrorAction Stop
}
catch
{
  write-host "Error retreiving $BADHC_NAME, exiting" -ForegroundColor Red
  Exit 1
}

$ADCredTest = $false
do
{
  Write-host "Getting credentials for Hosting Connection Service Account..." -ForegroundColor Yellow
  $cred = Get-Credential -Message "Enter credentials for the Hosting Connection Service Account"
  if ($cred -eq $null)
  {
    break
  }

  Write-Host "Checking authentication..." -ForegroundColor Yellow
  $username = $Cred.username
  $password = $Cred.GetNetworkCredential().password
  $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
  $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$Password)
  if ($domain.name -eq $null)
  {
    write-host "Authentication failed - please verify your username and password." -ForegroundColor Red
    $ADCredTest = $false
  }
  else
  {
    write-host "Successfully authenticated" -ForegroundColor Green
    $ADCredTest = $true
  }
} until ($ADCredTest)

if ($cred -eq $null)
{
  write-host "Service Account credentials not provided, exiting" -ForegroundColor Red
  Exit 1
}
else
{
  write-host "Credentials for Hosting Connection Service Account are OK" -ForegroundColor Green
}

Write-host "Trying to fix the Hosting Connection..." -ForegroundColor Yellow
$BADHC_Displayname = $BADHC_NAME.HypervisorConnectionName
try
{
  Set-Item -LiteralPath $BADHC_PATH -username $cred.username -Securepassword $cred.password -SslThumbprint $NEWHC_SSL -hypervisorAddress $BADHC.HypervisorAddress -ErrorAction Stop
  $HostingConnectionFixed = $true
}
catch
{

  write-host "Error fixing Hosting Connection $BADHC_Displayname, exiting" -ForegroundColor Red
  Exit 1
}

if ($HostingConnectionFixed)
{
  Write-Host "Hosting Connection $BADHC_Displayname was fixed succesfully" -ForegroundColor Green
}


$HostingConName = $NEWHC_NAME.HypervisorConnectionName
$title    = ''
$question = "Do you want to delete the new Hosting Connection "+$HostingConName+"?"
$choices  = '&Yes', '&No'
write-host " "
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)

if ($decision -eq 0)
{
  $title    = ''
  $question = "Are you sure to delete the new Hosting Connection "+$HostingConName+"?"
  $choices  = '&Yes', '&No'
  write-host " "
  $decision2 = $Host.UI.PromptForChoice($title, $question, $choices, 1)

  if ($decision2 -eq 0)
  {
    # Removing all resources under the connection first
    $HypResources = get-childitem xdhyp:\HostingUnits | Where-Object {$_.HypervisorConnection -like $NEWHC_NAME.HypervisorConnectionName}
    if ($HypResources -ne $null)
    {
      $RemovalError1 = $false
      $RemovalError2 = $false
      Try
      {
        Write-host "Removing Hosting Connection Resources..." -ForegroundColor Yellow
        remove-item $HypResources.PSPath -ErrorAction Stop
      }
      Catch
      {
        Write-host "Error removing Hosting Connection Resources" -ForegroundColor Red
        $RemovalError = $true
      }
      if ($RemovalError1 -eq $false)
      {
        Write-Host "Hosting Connection Resources removed" -ForegroundColor Green
        Try
        {
          Write-host "Removing Hosting Connection..." -ForegroundColor Yellow
          Remove-Item -Path $NEWHC_PATH -Force
        }
        catch
        {
          Write-host "Error removing Hosting Connection" -ForegroundColor Red
        }
        if ($RemovalError2 -eq $false)
        {
          Write-Host "Hosting Connection removed" -ForegroundColor Green
        }
      }
    }
  }
}

Read-Host "`nPress Enter to continue"
