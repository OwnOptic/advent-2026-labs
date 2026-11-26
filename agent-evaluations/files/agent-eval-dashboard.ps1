# agent-eval-dashboard.ps1: one page with every evaluation run of a Copilot Studio agent, passed or blocked.
# Lab companion for "Your agent passed yesterday" (Elliot Margot). PowerShell 7. MIT licence, use at your own risk.
#
# What it does, with the Power Platform API (preview), read only:
#   1. signs you in with a device code (same app registration as agent-eval-gate.ps1),
#   2. reads every completed evaluation run of the agent and scores each test method,
#   3. marks each run PASSED or BLOCKED with the same thresholds as the gate,
#   4. writes dashboard.html next to this script, and uploads it to an Azure Storage static website if you give one.
# Run names tell where a run came from: "Gate ..." (the pipeline), "After publish ..." (Power Automate), anything else (manual).
#
# Example:
#   pwsh -File .\agent-eval-dashboard.ps1 -TenantId <tenant id> -ClientId <app id> -EnvironmentId <environment id> -AgentId <agent id>
#   add -StorageAccount <name> to publish it (az login first; the account needs static website hosting turned on)
param(
  [Parameter(Mandatory)] [string]$TenantId,
  [Parameter(Mandatory)] [string]$ClientId,
  [Parameter(Mandatory)] [string]$EnvironmentId,
  [Parameter(Mandatory)] [string]$AgentId,
  [string]$AgentName = 'Contoso Travel Desk',
  [int]$KeywordThreshold = 80,
  [int]$PolicyThreshold = 100,
  [string]$StorageAccount,
  [string]$AccessToken
)
$ErrorActionPreference = 'Stop'
$token = $AccessToken
if (-not $token) {
  $auth = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0"
  $dc = Invoke-RestMethod -Method Post -Uri "$auth/devicecode" -Body @{ client_id = $ClientId; scope = 'https://api.powerplatform.com/.default offline_access' }
  Write-Host $dc.message -ForegroundColor Yellow
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
$label = @{ GeneralQuality = 'quality'; AnyKeywordMatch = 'keyword'; AllKeywordsMatch = 'keyword'; CustomLabels = 'policy' }
$runs = (Invoke-RestMethod -Uri "$api/testruns?$v" -Headers $H).value | Where-Object state -eq 'Completed'
Write-Host "$(@($runs).Count) completed runs, reading the results..." -ForegroundColor Cyan
$rows = foreach ($run in $runs) {
  $r = Invoke-RestMethod -Uri "$api/testruns/$($run.id)?$v" -Headers $H
  $st = @{}; $credits = 0.0
  foreach ($c in $r.testCasesResults) {
    $credits += [double]$c.consumption.evaluators.totalCredits + [double]$c.consumption.conversation.totalCredits
    foreach ($m in $c.metricsResults) { $k = $label[$m.type]; if (-not $k) { continue }
      if (-not $st[$k]) { $st[$k] = @{ p = 0; t = 0 } }; $st[$k].t++; if ($m.result.status -eq 'Pass') { $st[$k].p++ } }
  }
  $pct = @{}; foreach ($k in 'quality', 'keyword', 'policy') { $pct[$k] = if ($st[$k]) { [math]::Round(100 * $st[$k].p / $st[$k].t) } else { $null } }
  $name = if ($r.name) { $r.name } else { "$($run.name)" }
  $kind = if ($name -like 'Gate*') { 'Release gate (pipeline)' } elseif ($name -like 'After publish*') { 'Power Automate, after publish' } else { 'Manual run' }
  [pscustomobject]@{ when = ([datetime]$run.startTime).ToLocalTime().ToString('yyyy-MM-dd HH:mm'); kind = $kind; change = $name
    quality = $pct.quality; keyword = $pct.keyword; policy = $pct.policy; credits = [math]::Round($credits, 1)
    passed = ($pct.keyword -ge $KeywordThreshold -and $pct.policy -ge $PolicyThreshold) }
}
$rows = @($rows | Sort-Object when -Descending)
if (-not $rows) { throw 'No completed evaluation run on this agent yet: run the gate or publish the agent first.' }
$TEMPLATE = @'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Agent release gate</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<style>
:root{--bg:#f4f5f8;--card:#fff;--ink:#141a26;--muted:#6b7385;--line:#e6e8ee;--green:#0f8a5f;--greenbg:#e6f5ee;--red:#d4380d;--redbg:#fff1eb;--accent:#F26F21;--navy:#2A3B4E;--grey:#d5d9e2}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 Inter,"Segoe UI",system-ui,sans-serif}
.nav{background:#16202c;color:#cfd8e3;border-bottom:1px solid #243244;font-size:14px}.navin{max-width:1180px;margin:0 auto;padding:0 32px;height:56px;display:flex;align-items:center;gap:28px}
.brand{display:flex;align-items:center;gap:10px;color:#fff;font-weight:700;font-size:15px}.logo{width:26px;height:26px;border-radius:7px;background:linear-gradient(135deg,#F26F21,#f8a35f);box-shadow:inset 0 0 0 6px rgba(255,255,255,.18)}
.links{display:flex;gap:4px}.links a{padding:8px 12px;border-radius:8px;color:#9fb0c3;cursor:pointer}.links a.on{background:#243244;color:#fff}
.right{margin-left:auto;display:flex;align-items:center;gap:12px}.env{border:1px solid #33465d;border-radius:999px;padding:4px 10px;font-size:12.5px;color:#cfd8e3}
.live{display:flex;align-items:center;gap:6px;font-size:12.5px;color:#9fb0c3}.live i{width:8px;height:8px;border-radius:50%;background:#2fd18b;box-shadow:0 0 0 3px rgba(47,209,139,.2);animation:p 2s infinite}@keyframes p{50%{box-shadow:0 0 0 6px rgba(47,209,139,0)}}
.av{width:30px;height:30px;border-radius:50%;background:#F26F21;color:#fff;display:grid;place-items:center;font-size:12px;font-weight:700}
@media(max-width:900px){.links,.env{display:none}.navin{padding:0 16px}}
.top{background:linear-gradient(135deg,#2A3B4E 0%,#1c2735 100%);color:#fff;padding:32px 0 96px}
.wrap{max-width:1180px;margin:0 auto;padding:0 32px}
.eyebrow{color:#f8b98f;font-size:12px;font-weight:700;letter-spacing:.14em;text-transform:uppercase}
h1{margin:8px 0 6px;font-size:34px;font-weight:800;letter-spacing:-.02em}.top p{margin:0;color:#b8c3d1;max-width:640px}
.hero{margin-top:-64px;display:grid;grid-template-columns:1.25fr 1fr 1fr 1fr;gap:16px}
.card{background:var(--card);border-radius:16px;box-shadow:0 1px 2px rgba(16,24,40,.06),0 8px 24px rgba(16,24,40,.06);padding:20px 22px}
.latest{display:flex;gap:16px;align-items:center}.latest .dot{width:56px;height:56px;border-radius:50%;display:grid;place-items:center;font-size:28px;color:#fff;flex:none}
.latest.ok .dot{background:var(--green)}.latest.ko .dot{background:var(--red)}
.latest h2{margin:0;font-size:22px}.latest small{color:var(--muted)}
.kpi b{display:block;font-size:40px;font-weight:800;line-height:1.05;letter-spacing:-.02em}.kpi span{color:var(--muted);font-size:13px;font-weight:500}
.kpi.g b{color:var(--green)}.kpi.r b{color:var(--red)}
.strip{margin-top:16px}.strip h3,.list h3{margin:0 0 12px;font-size:15px;font-weight:700}
.dots{display:flex;gap:6px;flex-wrap:wrap}.dots i{width:22px;height:22px;border-radius:6px;background:var(--green);cursor:default;position:relative}.dots i.ko{background:var(--red)}
.dots i:hover::after{content:attr(data-t);position:absolute;bottom:28px;left:50%;transform:translateX(-50%);background:var(--ink);color:#fff;font-size:12px;padding:4px 8px;border-radius:6px;white-space:nowrap;z-index:2}
.legend{display:flex;gap:16px;color:var(--muted);font-size:13px;margin-top:10px}.legend span::before{content:"";display:inline-block;width:10px;height:10px;border-radius:3px;margin-right:6px;background:var(--green)}.legend span.ko::before{background:var(--red)}
.rule{display:flex;gap:10px;align-items:center;margin-top:16px;padding:14px 18px;border-left:4px solid var(--accent)}
.list{margin-top:16px;padding:0;overflow:hidden}.list .head{display:flex;justify-content:space-between;align-items:center;padding:18px 22px 6px;flex-wrap:wrap;gap:10px}
.tabs{display:flex;gap:6px;background:#eef0f4;padding:4px;border-radius:10px}.tabs button{border:0;background:none;padding:7px 14px;border-radius:7px;font:600 13px Inter,sans-serif;color:var(--muted);cursor:pointer}.tabs button.on{background:#fff;color:var(--ink);box-shadow:0 1px 3px rgba(0,0,0,.1)}
.row{display:grid;grid-template-columns:150px 1.3fr 1fr 1fr 120px;gap:18px;align-items:center;padding:14px 22px;border-top:1px solid var(--line)}
.row.ko{background:var(--redbg)}.row.h{color:var(--muted);font-size:12px;font-weight:600;text-transform:uppercase;letter-spacing:.06em;border-top:0;padding-top:6px;padding-bottom:8px}
.when b{display:block;font-size:14px}.when small,.who small{color:var(--muted);font-size:12.5px}.who b{font-size:14px;font-weight:600}
.bar{position:relative;height:8px;background:#e9ecf1;border-radius:99px}.bar span{position:absolute;inset:0 auto 0 0;border-radius:99px;background:var(--green)}.bar span.ko{background:var(--red)}
.bar em{position:absolute;top:-4px;width:2px;height:16px;background:var(--ink);opacity:.55}
.val{display:flex;justify-content:space-between;font-size:13px;margin-bottom:6px}.val b.ko{color:var(--red)}.val small{color:var(--muted)}
.pill{justify-self:end;padding:6px 12px;border-radius:999px;font-weight:700;font-size:12px;letter-spacing:.04em}.pill.ok{background:var(--greenbg);color:var(--green)}.pill.ko{background:var(--red);color:#fff}
footer{color:var(--muted);font-size:12.5px;padding:18px 0 40px}
@media(max-width:900px){.wrap{padding:0 16px}.hero{grid-template-columns:1fr 1fr}.latest{grid-column:1/-1}.row{grid-template-columns:1fr 1fr;gap:10px}.row.h{display:none}.pill{justify-self:start}}
</style></head><body>
<nav class="nav"><div class="navin"><div class="brand"><span class="logo"></span>Agent Quality</div>
<div class="links"><a class="on">Release gate</a><a>Agents</a><a>Test sets</a><a>Alerts</a><a>Settings</a></div>
<div class="right"><span class="live"><i></i>Live · synced __SYNC__</span></div></div></nav>
<div class="top"><div class="wrap"><div class="eyebrow">__AGENT__ · Copilot Studio</div><h1>Agent release gate</h1>
<p>Every evaluation of the agent, from the pipeline, from Power Automate after each publish, and every morning. Green ships. Red is blocked.</p></div></div>
<div class="wrap">
<div class="hero" id="hero"></div>
<div class="card strip"><h3>Every run, oldest to newest</h3><div class="dots" id="dots"></div><div class="legend"><span>Passed</span><span class="ko">Blocked</span></div></div>
<div class="card rule"><b>The gate</b><span>Keyword match at least __KW__% and policy compliance __POL__%. Below either, nothing is published and users keep the last version that passed.</span></div>
<div class="card list"><div class="head"><h3>Runs</h3><div class="tabs" id="tabs"><button class="on" data-f="all">All</button><button data-f="ok">Passed</button><button data-f="ko">Blocked</button></div></div>
<div class="row h"><div>When</div><div>Started by</div><div>Keyword match</div><div>Policy compliance</div><div></div></div><div id="rows"></div></div>
<footer>Real runs from the Power Platform evaluation API. Updated __UPDATED__.</footer>
</div>
<script>
const D=__DATA__;const runs=(Array.isArray(D)?D:[D]);
const ok=runs.filter(r=>r.passed).length,ko=runs.length-ok,cr=runs.reduce((a,r)=>a+(r.credits||0),0);const L=runs[0];
const fmt=s=>{const d=new Date(s.replace(' ','T'));return{day:d.toLocaleDateString('en-GB',{day:'numeric',month:'short'}),time:d.toLocaleTimeString('en-GB',{hour:'2-digit',minute:'2-digit'})}};
const lf=fmt(L.when);
document.getElementById('hero').innerHTML=`<div class="card latest ${L.passed?'ok':'ko'}"><div class="dot">${L.passed?'&#10003;':'&#10005;'}</div><div><small>Latest run · ${lf.day} ${lf.time}</small><h2>${L.passed?'Passed':'Blocked'}</h2><small>${L.kind} · ${L.change}</small></div></div>`+
[[runs.length,'evaluation runs',''],[ok,'passed','g'],[ko,'blocked','r']].map(([b,s,c])=>`<div class="card kpi ${c}"><b>${b}</b><span>${s}</span></div>`).join('');
document.getElementById('dots').innerHTML=[...runs].reverse().map(r=>{const f=fmt(r.when);return`<i class="${r.passed?'':'ko'}" data-t="${f.day} ${f.time} · ${r.passed?'passed':'blocked'} · ${r.change}"></i>`}).join('');
const bar=(v,t)=>v==null?'<small>-</small>':`<div class="val"><b class="${v<t?'ko':''}">${v}%</b><small>gate ${t}%</small></div><div class="bar"><span class="${v<t?'ko':''}" style="width:${v}%"></span><em style="left:${t}%"></em></div>`;
function draw(f){document.getElementById('rows').innerHTML=runs.filter(r=>f=='all'||(f=='ok')==r.passed).map(r=>{const w=fmt(r.when);return`<div class="row ${r.passed?'':'ko'}"><div class="when"><b>${w.day}</b><small>${w.time}</small></div><div class="who"><b>${r.kind}</b><br><small>${r.change} · ${r.credits} credits</small></div><div>${bar(r.keyword,__KW__)}</div><div>${bar(r.policy,__POL__)}</div><span class="pill ${r.passed?'ok':'ko'}">${r.passed?'PASSED':'BLOCKED'}</span></div>`}).join('')}
document.getElementById('tabs').onclick=e=>{const b=e.target.closest('button');if(!b)return;document.querySelectorAll('.tabs button').forEach(x=>x.classList.toggle('on',x==b));draw(b.dataset.f)};draw('all');
</script></body></html>

'@
$html = $TEMPLATE.Replace('__DATA__', ($rows | ConvertTo-Json -Compress -Depth 4)).Replace('__AGENT__', [System.Net.WebUtility]::HtmlEncode($AgentName)).
  Replace('__KW__', "$KeywordThreshold").Replace('__POL__', "$PolicyThreshold").Replace('__SYNC__', (Get-Date).ToString('HH:mm')).Replace('__UPDATED__', (Get-Date).ToString('d MMMM yyyy, HH:mm'))
$out = Join-Path $PSScriptRoot 'dashboard.html'
Set-Content $out $html -Encoding utf8
Write-Host "$($rows.Count) runs, $(@($rows | Where-Object { -not $_.passed }).Count) blocked. Written to $out" -ForegroundColor Green
if ($StorageAccount) {
  az storage blob upload --account-name $StorageAccount -c '$web' -n index.html -f $out --content-type 'text/html; charset=utf-8' --overwrite --auth-mode key -o none
  Write-Host "Published: $(az storage account show -n $StorageAccount --query primaryEndpoints.web -o tsv)" -ForegroundColor Green
}
