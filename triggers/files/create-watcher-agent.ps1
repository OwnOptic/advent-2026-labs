#requires -Version 7
<#
.SYNOPSIS
    Creates (or updates) the agent "Contoso Procurement Watcher" on the Microsoft Copilot harness, then publishes it.

.DESCRIPTION
    Lab "Copilot Studio triggers" (Power Platform Advent Calendar 2026), by Elliot Margot.
    The agent is a Dataverse "bots" row with the template cliagent-1.0.0 (the Microsoft Copilot harness).
    The script only talks to the Dataverse Web API with an Azure CLI token: nothing to install but Azure CLI.

    - If an agent with this name already exists on the Microsoft Copilot harness, its instructions are replaced.
    - Otherwise the agent is created and provisioned.
    - In both cases it is published, and the script waits until the publish has finished (about 15 seconds).

    The instructions are read from watcher-instructions.txt, next to this script.
    No tools, no knowledge, no web search: the workflow hands the agent everything it needs.

.PARAMETER EnvironmentUrl
    The URL of your Power Platform environment, for example https://yourorg.crm.dynamics.com
    (Power Platform admin center, your environment, Environment URL). No trailing slash.

.PARAMETER TenantId
    Your test tenant ID (36 characters).

.EXAMPLE
    az login --tenant YOUR_TENANT_ID
    ./create-watcher-agent.ps1 -EnvironmentUrl https://yourorg.crm.dynamics.com -TenantId YOUR_TENANT_ID
#>
param(
  [Parameter(Mandatory)][string]$EnvironmentUrl,
  [Parameter(Mandatory)][string]$TenantId,
  [string]$Name = 'Contoso Procurement Watcher'
)
$ErrorActionPreference = 'Stop'
$ORG = $EnvironmentUrl.TrimEnd('/'); $api = "$ORG/api/data/v9.2"
$tok = az account get-access-token --tenant $TenantId --resource $ORG --query accessToken -o tsv
if (-not $tok) { throw "No token. Run: az login --tenant $TenantId" }
$H = @{ Authorization = "Bearer $tok"; Accept = 'application/json'; 'OData-MaxVersion' = '4.0'; 'OData-Version' = '4.0' }
$utf8 = [System.Text.Encoding]::UTF8
$instructions = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'watcher-instructions.txt')

# Look for an existing agent with this name on the Microsoft Copilot harness
$existing = (Invoke-RestMethod -Uri "$api/bots?`$select=botid,name,template,configuration&`$filter=template eq 'cliagent-1.0.0'" -Headers $H).value | Where-Object { $_.name -eq $Name }
if ($existing) {
  # Update: replace the instructions in the configuration, keep everything else
  $botid = $existing.botid
  $cfg = $existing.configuration | ConvertFrom-Json
  $cfg.agentSettings.instructions.segments[0].value = $instructions
  $json = @{ configuration = ($cfg | ConvertTo-Json -Depth 20 -Compress) } | ConvertTo-Json
  Invoke-RestMethod -Method Patch -Uri "$api/bots($botid)" -Headers ($H + @{ 'If-Match' = '*' }) -ContentType 'application/json; charset=utf-8' -Body $utf8.GetBytes($json)
  "UPDATED $botid"
} else {
  # Create: the schema name needs a unique suffix
  $suffix = -join ((65..90) + (97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
  $config = [ordered]@{
    '$kind' = 'BotConfiguration'
    settings = @{ WorkIqAddedByDefault = $false }
    recognizer = @{ '$kind' = 'CLICopilotRecognizer' }
    agentSettings = [ordered]@{
      '$kind' = 'AgentSettings'
      model = @{ '$kind' = 'ModelConfig'; series = 'Auto' }
      instructions = @{ '$kind' = 'Instructions'; segments = @(@{ '$kind' = 'StaticSegment'; value = $instructions }) }
      web = @{ '$kind' = 'WebSettings'; enableWebSearch = $false }
    }
  } | ConvertTo-Json -Depth 10 -Compress
  # Template cliagent-1.0.0 = Microsoft Copilot harness. Language 1033 = English.
  $body = @{ name = $Name; schemaname = "new_contosoProcurementWatcher_$suffix"; template = 'cliagent-1.0.0'; language = 1033
    authenticationmode = 2; authenticationtrigger = 1; accesscontrolpolicy = 2; runtimeprovider = 0; configuration = $config } | ConvertTo-Json -Depth 5
  $r = Invoke-WebRequest -Method Post -Uri "$api/bots" -Headers $H -ContentType 'application/json; charset=utf-8' -Body $utf8.GetBytes($body)
  $botid = $r.Headers['OData-EntityId'] -replace '.*\(([0-9a-f-]+)\).*', '$1'
  Invoke-RestMethod -Method Post -Uri "$api/bots($botid)/Microsoft.Dynamics.CRM.PvaProvision" -Headers $H -ContentType 'application/json' -Body '{}' | Out-Null
  "CREATED $botid"
}

# Publish, then wait until the publish date changes
$before = (Invoke-RestMethod -Uri "$api/bots($botid)?`$select=publishedon" -Headers $H).publishedon
Invoke-RestMethod -Method Post -Uri "$api/bots($botid)/Microsoft.Dynamics.CRM.PvaPublish" -Headers $H -ContentType 'application/json' -Body '{}' | Out-Null
foreach ($i in 1..24) {
  Start-Sleep 5
  $b = Invoke-RestMethod -Uri "$api/bots($botid)?`$select=publishedon,synchronizationstatus" -Headers $H
  if ($b.publishedon -and $b.publishedon -ne $before) { break }
}
"PUBLISHED $($b.publishedon) status=$((($b.synchronizationstatus | ConvertFrom-Json).lastFinishedPublishOperation.status))"
"Open it in Copilot Studio: Agents, then Contoso Procurement Watcher (bot ID $botid)."
