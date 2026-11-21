# agent-eval-gate.ps1: run a Copilot Studio test set from outside Copilot Studio and turn it into a release gate.
# Lab companion for "Your agent passed yesterday" (Elliot Margot). PowerShell 7. MIT licence, use at your own risk.
#
# What it does, with the Power Platform API (preview):
#   1. signs you in with a device code (delegated token, scopes CopilotStudio.MakerOperations.Read and ReadWrite),
#   2. finds the test set by name and starts a run on the agent's DRAFT (runOnPublishedBot = false),
#   3. polls until the run completes,
#   4. computes the pass rate of each test method and compares it with your thresholds,
#   5. exits 0 when every threshold holds (safe to publish) and 1 when one fails (do not publish).
# It never publishes and never changes the agent.
#
# Example:
#   pwsh -File .\agent-eval-gate.ps1 -TenantId <tenant id> -ClientId <app id> -EnvironmentId <environment id> -AgentId <agent id>
param(
  [Parameter(Mandatory)] [string]$TenantId,
  [Parameter(Mandatory)] [string]$ClientId,
  [Parameter(Mandatory)] [string]$EnvironmentId,
  [Parameter(Mandatory)] [string]$AgentId,
  [string]$TestSetName = 'Release gate',
  [hashtable]$Thresholds = @{ 'Policy compliance' = 100; 'Keyword match' = 80 },
  [switch]$RunOnPublished,
  [string]$AccessToken   # optional: a token you already have (for example in a CI runner); skips the device code
)
$ErrorActionPreference = 'Stop'
function Say($t, $c = 'Gray') { Write-Host $t -ForegroundColor $c }

# 1. Sign in (device code), cached for the session in an environment variable only
$scope = 'https://api.powerplatform.com/.default offline_access'
$auth = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0"
$token = $AccessToken
if (-not $token) {
$dc = Invoke-RestMethod -Method Post -Uri "$auth/devicecode" -Body @{ client_id = $ClientId; scope = $scope }
Say $dc.message Yellow
$deadline = (Get-Date).AddSeconds([int]$dc.expires_in)
while (-not $token -and (Get-Date) -lt $deadline) {
  Start-Sleep ([int]$dc.interval)
  try { $token = (Invoke-RestMethod -Method Post -Uri "$auth/token" -Body @{ client_id = $ClientId; grant_type = 'urn:ietf:params:oauth:grant-type:device_code'; device_code = $dc.device_code }).access_token }
  catch { $e = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue; if ($e.error -notin 'authorization_pending', 'slow_down') { throw $_ } }
}
if (-not $token) { throw 'The sign-in code expired.' }
}
$H = @{ Authorization = "Bearer $token" }
$api = "https://api.powerplatform.com/copilotstudio/environments/$EnvironmentId/bots/$AgentId/api/makerevaluation"
$v = 'api-version=2024-10-01'

# 2. Find the test set and start a run
$sets = (Invoke-RestMethod -Uri "$api/testsets?$v" -Headers $H).value
$set = $sets | Where-Object displayName -eq $TestSetName | Select-Object -First 1
if (-not $set) { throw "Test set '$TestSetName' not found. Test sets on this agent: $(($sets.displayName) -join ', ')" }
foreach ($i in 1..40) {   # one run at a time per agent
  $busy = @((Invoke-RestMethod -Uri "$api/testruns?$v" -Headers $H).value | Where-Object { $_.state -in 'Queued', 'InProgress' })
  if (-not $busy) { break }; if ($i -eq 1) { Say 'Another run is in progress on this agent: waiting.' Yellow }; Start-Sleep 10
}
$target = if ($RunOnPublished) { 'published agent' } else { 'draft' }
Say "`nRunning '$($set.displayName)' ($($set.totalTestCases) cases) on the $target" Cyan
$body = @{ evaluationRunName = "Gate $(Get-Date -Format 'yyyy-MM-dd HH:mm')"; runOnPublishedBot = [bool]$RunOnPublished } | ConvertTo-Json
$run = Invoke-RestMethod -Method Post -Uri "$api/testsets/$($set.id)/run?$v" -Headers $H -ContentType 'application/json' -Body $body

# 3. Poll
$t0 = Get-Date
do { Start-Sleep 10; $r = Invoke-RestMethod -Uri "$api/testruns/$($run.runId)?$v" -Headers $H; Say ("  {0,4:n0} s  {1}" -f ((Get-Date) - $t0).TotalSeconds, $r.state) }
while ($r.state -notin 'Completed', 'Failed', 'Cancelled', 'Abandoned')
if ($r.state -ne 'Completed') { Say "Run ended as $($r.state)" Red; exit 2 }

# 4. Score each test method (type names as the API returns them)
$label = @{ GeneralQuality = 'General quality'; AnyKeywordMatch = 'Keyword match'; AllKeywordsMatch = 'Keyword match'; CustomLabels = 'Policy compliance'; ExactMatch = 'Exact match'; TextSimilarity = 'Text similarity'; CompareMeaning = 'Compare meaning' }
$stats = @{}; $fails = @(); $credits = 0.0; $n = 0
foreach ($c in $r.testCasesResults) {
  $n++
  $credits += [double]$c.consumption.evaluators.totalCredits + [double]$c.consumption.conversation.totalCredits
  foreach ($m in $c.metricsResults) {
    $name = if ($label[$m.type]) { $label[$m.type] } else { $m.type }
    if (-not $stats[$name]) { $stats[$name] = @{ pass = 0; total = 0 } }
    $stats[$name].total++
    if ($m.result.status -eq 'Pass') { $stats[$name].pass++ } else { $fails += [pscustomobject]@{ Method = $name; Case = $n; Why = $m.result.aiResultReason } }
  }
}
Say "`nResults" Cyan
$red = $false
foreach ($name in ($stats.Keys | Sort-Object)) {
  $s = $stats[$name]; $pct = [math]::Round(100 * $s.pass / [math]::Max(1, $s.total)); $min = $Thresholds[$name]
  if ($null -eq $min) { Say ("  {0,-18} {1,3}%  ({2}/{3})  reported only" -f $name, $pct, $s.pass, $s.total) }
  elseif ($pct -ge $min) { Say ("  {0,-18} {1,3}%  ({2}/{3})  threshold {4}%  PASS" -f $name, $pct, $s.pass, $s.total, $min) Green }
  else { $red = $true; Say ("  {0,-18} {1,3}%  ({2}/{3})  threshold {4}%  FAIL" -f $name, $pct, $s.pass, $s.total, $min) Red }
}
foreach ($f in ($fails | Where-Object { $null -ne $Thresholds[$_.Method] })) { Say "  - [$($f.Method)] case $($f.Case): $($f.Why)" Yellow }
Say ("`nCost: {0:n1} Copilot credits, {1:n0} seconds. Details: https://copilotstudio.microsoft.com/environments/$EnvironmentId/agents/$AgentId/evaluate" -f $credits, ((Get-Date) - $t0).TotalSeconds)

# 5. The decision
if ($red) { Say "`nGATE FAILED: do not publish this draft." Red; exit 1 }
Say "`nGATE PASSED: safe to publish." Green; exit 0

