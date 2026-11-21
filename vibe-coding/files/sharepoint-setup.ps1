#requires -Version 7
<#
.SYNOPSIS
    Prepares the SharePoint ground for the onboarding lab (Power Platform Advent Calendar 2026):
    the site, the "New starters" list and the Human Resources documents of Contoso (a fictitious company).

.DESCRIPTION
    Creates or reuses, without duplicates (you can run the script as many times as needed):
      - the "Contoso - Human Resources" site (address /sites/contoso-hr), or the site you give;
      - the "New starters" list with the columns and internal names the lab and the context file use:
        Title (displayed "Full name"), Email, JobTitle, StartDate (date only), Manager and Buddy (people),
        EquipmentHandedOver (choice No or Yes);
      - two past new starters, so the list is not empty;
      - the 5 documents of the zip in the Documents library, and the 2021 policy in an "Archives" folder
        (that is the trap of the agent step: keep it).

    It goes through Microsoft Graph, with the Microsoft Graph PowerShell module and an interactive sign-in.
    When Microsoft throttles the calls, the script waits and retries on its own.

.PARAMETER SharePointHost
    The SharePoint host of your test tenant, for example contoso.sharepoint.com.

.PARAMETER SiteUrl
    Optional: the address of an existing site to use, for example https://contoso.sharepoint.com/sites/contoso-hr.
    Without it, the script creates (or finds) the /sites/contoso-hr site.

.PARAMETER Zip
    The documents zip. Default: contoso-hr-documents.zip, next to the script.

.PARAMETER TenantId
    Optional: the ID or domain of your test tenant, so you never sign in somewhere else by mistake.

.EXAMPLE
    pwsh -File .\sharepoint-setup.ps1 -SharePointHost contoso.sharepoint.com
#>
param(
    [Parameter(Mandatory)] [string] $SharePointHost,
    [string] $SiteUrl,
    [string] $Zip = (Join-Path $PSScriptRoot 'contoso-hr-documents.zip'),
    [string] $TenantId
)

$ErrorActionPreference = 'Stop'
$SharePointHost = $SharePointHost -replace '^https?://', '' -replace '/.*$', ''
$Alias = 'contoso-hr'
$SiteName = 'Contoso - Human Resources'
$ListName = 'New starters'

if (-not (Get-Module -ListAvailable Microsoft.Graph.Authentication)) {
    Write-Host "The Microsoft Graph PowerShell module is missing. Install it once with:" -ForegroundColor Yellow
    Write-Host "  Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
    exit 1
}
if (-not (Test-Path $Zip)) { throw "Zip not found: $Zip. Download contoso-hr-documents.zip from the lab, next to this script." }
Import-Module Microsoft.Graph.Authentication

# ---------- Sign-in ----------
$Scopes = @('Sites.FullControl.All', 'Sites.ReadWrite.All')
if (-not $SiteUrl) { $Scopes += 'Group.ReadWrite.All' }
try { Set-MgGraphOption -DisableLoginByWAM $true } catch { }
$signIn = @{ Scopes = $Scopes; NoWelcome = $true }
if ($TenantId) { $signIn.TenantId = $TenantId }
Connect-MgGraph @signIn
$Me = (Get-MgContext).Account
Write-Host "Signed in: $Me" -ForegroundColor Cyan

# Graph call that retries when Microsoft throttles (429) or a service is unavailable.
function Invoke-Graph {
    param([string] $Method, [string] $Uri, $Body, [string] $InputFilePath, [string] $ContentType = 'application/json')
    for ($try = 1; ; $try++) {
        try {
            $p = @{ Method = $Method; Uri = $Uri }
            if ($null -ne $Body) { $p.Body = ($Body | ConvertTo-Json -Depth 10); $p.ContentType = $ContentType }
            if ($InputFilePath) { $p.InputFilePath = $InputFilePath; $p.ContentType = $ContentType }
            return Invoke-MgGraphRequest @p
        } catch {
            $code = 0
            try { $code = [int]$_.Exception.Response.StatusCode } catch { }
            if ($code -in 429, 502, 503, 504 -and $try -lt 8) {
                $wait = [math]::Min(5 * $try, 30)
                Write-Host "  Microsoft asks to slow down ($code), retrying in $wait seconds..." -ForegroundColor DarkYellow
                Start-Sleep -Seconds $wait; continue
            }
            throw
        }
    }
}
$G = 'https://graph.microsoft.com/v1.0'

# ---------- The site ----------
if ($SiteUrl) {
    $u = [uri]$SiteUrl
    $site = Invoke-Graph GET "$G/sites/$($u.Host):$($u.AbsolutePath.TrimEnd('/'))"
    Write-Host "Using site: $($site.webUrl)"
} else {
    $site = $null
    try { $site = Invoke-Graph GET "$G/sites/${SharePointHost}:/sites/$Alias" } catch { }
    if ($site) {
        Write-Host "Site already there: $($site.webUrl)"
    } else {
        $group = @((Invoke-Graph GET "$G/groups?`$filter=mailNickname eq '$Alias'&`$select=id").value) | Select-Object -First 1
        if (-not $group) {
            Write-Host "Creating the site '$SiteName' (a Microsoft 365 group and its team site)..."
            $meId = (Invoke-Graph GET "$G/me?`$select=id").id
            $group = Invoke-Graph POST "$G/groups" @{
                displayName = $SiteName; mailNickname = $Alias; mailEnabled = $true; securityEnabled = $false
                groupTypes = @('Unified'); visibility = 'Private'
                description = "Contoso Human Resources site (fictitious lab data)"
                'owners@odata.bind' = @("$G/users/$meId"); 'members@odata.bind' = @("$G/users/$meId")
            }
        }
        Write-Host "Waiting for the SharePoint site (one to three minutes the first time)..."
        for ($i = 1; $i -le 30 -and -not $site; $i++) {
            try { $site = Invoke-Graph GET "$G/groups/$($group.id)/sites/root" } catch { Start-Sleep -Seconds 10 }
        }
        if (-not $site) { throw "The site is not ready yet. Run the script again in a few minutes: it picks up where it stopped." }
        Write-Host "Site ready: $($site.webUrl)"
    }
}
$S = "$G/sites/$($site.id)"

# ---------- The "New starters" list ----------
$list = @((Invoke-Graph GET "$S/lists?`$select=id,displayName,webUrl").value) | Where-Object { $_.displayName -eq $ListName } | Select-Object -First 1
if (-not $list) {
    $list = Invoke-Graph POST "$S/lists" @{
        displayName = $ListName
        description = "New starters at the Copenhagen office"
        list        = @{ template = 'genericList' }
        columns     = @(
            @{ name = 'Email'; displayName = 'Email'; text = @{} }
            @{ name = 'JobTitle'; displayName = 'Job title'; text = @{} }
            @{ name = 'StartDate'; displayName = 'Start date'; dateTime = @{ format = 'dateOnly' } }
            @{ name = 'Manager'; displayName = 'Manager'; personOrGroup = @{ allowMultipleSelection = $false; chooseFromType = 'peopleOnly' } }
            @{ name = 'Buddy'; displayName = 'Buddy'; personOrGroup = @{ allowMultipleSelection = $false; chooseFromType = 'peopleOnly' } }
            @{ name = 'EquipmentHandedOver'; displayName = 'Equipment handed over'; choice = @{ allowTextEntry = $false; choices = @('No', 'Yes'); displayAs = 'dropDownMenu' }; defaultValue = @{ value = 'No' } }
        )
    }
    Write-Host "List '$ListName' created"
} else {
    Write-Host "List '$ListName' already there"
}
$titleCol = @((Invoke-Graph GET "$S/lists/$($list.id)/columns?`$select=id,name,displayName").value) | Where-Object { $_.name -eq 'Title' }
if ($titleCol -and $titleCol.displayName -ne 'Full name') {
    Invoke-Graph PATCH "$S/lists/$($list.id)/columns/$($titleCol.id)" @{ displayName = 'Full name' } | Out-Null
}

# People columns take the user's ID within the site.
$infos = @((Invoke-Graph GET "$S/lists('User Information List')/items?`$expand=fields(`$select=EMail)&`$top=500").value)
$meLookup = ($infos | Where-Object { $_.fields.EMail -eq $Me } | Select-Object -First 1).id

$samples = @(
    @{ Title = 'Hugo Bernard'; JobTitle = 'Power Platform developer'; StartDate = (Get-Date).AddDays(-14).ToString('yyyy-MM-dd'); EquipmentHandedOver = 'Yes' },
    @{ Title = 'Ines Moreau'; JobTitle = 'Recruitment officer'; StartDate = (Get-Date).AddDays(-7).ToString('yyyy-MM-dd'); EquipmentHandedOver = 'Yes' }
)
$rows = @((Invoke-Graph GET "$S/lists/$($list.id)/items?`$expand=fields(`$select=Title,ManagerLookupId)&`$top=200").value)
foreach ($e in $samples) {
    $fields = @{ Title = $e.Title; Email = $Me; JobTitle = $e.JobTitle; StartDate = $e.StartDate; EquipmentHandedOver = $e.EquipmentHandedOver }
    if ($meLookup) { $fields.ManagerLookupId = [int]$meLookup; $fields.BuddyLookupId = [int]$meLookup }
    $row = $rows | Where-Object { $_.fields.Title -eq $e.Title } | Select-Object -First 1
    if (-not $row) {
        Invoke-Graph POST "$S/lists/$($list.id)/items" @{ fields = $fields } | Out-Null
        Write-Host "New starter added: $($e.Title)"
    } elseif ($meLookup -and -not $row.fields.ManagerLookupId) {
        Invoke-Graph PATCH "$S/lists/$($list.id)/items/$($row.id)/fields" @{ ManagerLookupId = [int]$meLookup; BuddyLookupId = [int]$meLookup } | Out-Null
        Write-Host "Manager and buddy filled in: $($e.Title)"
    } else {
        Write-Host "New starter already there: $($e.Title)"
    }
}
if (-not $meLookup) {
    Write-Host "Your account is not known to the site yet: the two new starters have no manager." -ForegroundColor Yellow
    Write-Host "  Open the site once in the browser, then run the script again: it fills in the manager and the buddy."
}

# ---------- The documents ----------
$folder = Join-Path ([System.IO.Path]::GetTempPath()) ("contoso-docs-" + [guid]::NewGuid().ToString('N'))
Expand-Archive -Path $Zip -DestinationPath $folder
$files = Get-ChildItem $folder -Recurse -File -Filter *.pdf
foreach ($f in $files) {
    $relative = $f.FullName.Substring($folder.Length).TrimStart('\', '/') -replace '\\', '/'
    $path = ($relative -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    Invoke-Graph PUT "$S/drive/root:/${path}:/content" -InputFilePath $f.FullName -ContentType 'application/pdf' | Out-Null
    Write-Host "Document uploaded: $relative"
}

Write-Host ""
Write-Host "Ground ready." -ForegroundColor Green
Write-Host "  Site      : $($site.webUrl)"
Write-Host "  List      : $($list.webUrl)"
Write-Host "  Documents : $($files.Count) files, including Archives/remote-work-policy-2021.pdf"
