# Lab: from a workshop transcript to a Copilot Studio workflow and agent

You are Claude. In this folder you help build, from the terminal and with Azure CLI only:
1. **The blueprint**: from a workshop transcript, you design the functional and technical blueprint, with its diagrams.
2. **The workflow**: from the validated blueprint, you build a **Copilot Studio workflow** (new experience). A Copilot Studio workflow is a Dataverse record: a row of the `workflows` table, of type "Copilot Studio flow" (`modernflowtype = 1`). It then appears in Copilot Studio, **Workflows** page, and opens in the new editor.
3. **The agent**, when asked: you create and publish the onboarding agent on the **Microsoft Copilot harness**, also as Dataverse records.

The session must be **smooth**: everything you need is in this file, in the blueprint template and in the transcript.

- **Do not search the web or Microsoft Learn**: every technical shape below was verified by a real run and opens in the new editor. Use it as is.
- **Business decisions come from the transcript, through the blueprint**, never from you. Do not ask any question whose answer is in the transcript. If the transcript leaves a question open, flag it in the blueprint without deciding it: the user will answer.
- **Never use the Power Automate API to create the workflow**: create the Dataverse record (otherwise it does not appear in Copilot Studio).
- Explain in one short sentence what you do at each step, in English.
- Work only in this folder. Do not create subagents. Never show an access token.
- Never use the long dash character: use a hyphen, a comma or a colon.

## Step 1: the blueprint

1. Read the whole transcript `./workshop-transcript.txt` (a text file, timestamped by speaker).
2. Copy `./templates/blueprint-template.html` to `./blueprint/onboarding-blueprint.html` and replace **every** "TO FILL IN" zone. Do not change the style or the icon symbols of the template.
3. Expected content:
   - **Functional**: today's pain points; the workflow requirements (trigger, welcome email with the full first-week programme, Teams message to the manager, coffee invitation, reminder); the agent requirements (sources, language, channel, citations, refusals, referral to Human Resources); the business rules; the **open questions**, in "open" blocks, with the options mentioned.
   - **Technical**: the choices (Copilot Studio workflow created by Azure CLI in Dataverse, Copilot Studio agent on the Microsoft Copilot harness, Teams channel), the data (list columns and their internal names, table below), the workflow step by step (connector and operation, "The connectors" table below), the agent (name "Contoso Onboarding Assistant", source, guardrails), the risks spotted, tests and deployment.
   - **Every requirement, rule and question cites its moment** in the transcript: `<span class="src">0:01:06 Thomas Leroy</span>`.
4. **Two SVG diagrams**, written in the page, with the grammar described at the top of the template (cards 220 x 120, icons `<use href="#ic-...">`, dashed groups). Follow these placements exactly (columns x = 30, 290, 550, 810, 1070; rows y = 40, 200, 360; `viewBox="0 0 1320 ..."`):
   - **the journey** ("Journey" section, height 540): row y = 120: col. 1 "Row added" ("New starters" list, ic-list) → col. 2 "Welcome email" (ic-outlook, orange border) → col. 3 two cards one above the other, "Message to manager" (y = 40, ic-teams) and "Coffee invitation" (y = 200, ic-calendar) → col. 4 "Wait 3 days" (ic-timer) → col. 5 "Remind the manager" (ic-outlook, detail "if equipment is missing"). Row y = 380, in a dashed group "In Teams, on demand": col. 2 "Camille asks a question" (ic-person) → col. 3 "Onboarding Assistant" (ic-copilot-studio, orange border) → col. 4 "Answer with its source" (ic-sharepoint).
   - **the architecture** ("Architecture" section, height 400): three dashed groups side by side, each from y = 8 to y = 360, **its title at y = 30, above the cards**; inside the groups, cards are at y = 50 and y = 210 (not 40 and 200), so they never cover the title. "SharePoint, Human Resources" (col. 1; a group title fits its width, 30 characters at most for a one-column group): "New starters list" (ic-list) and "Documents" (ic-sharepoint). "Copilot Studio, stored in Dataverse" (col. 2 and 3): "Onboarding workflow" (col. 2, ic-dataverse, orange border) and "Onboarding Assistant" (col. 2, ic-copilot-studio, orange border). "Microsoft 365" (col. 4): "Outlook" (ic-outlook) and "Teams" (ic-teams). Arrows: List → Workflow, Documents → Assistant, Workflow → Outlook, Workflow → Teams, Assistant → Teams. The two arrows into Teams stay distinct: the workflow's arrives on the left edge of Teams 30 px from the top of the card (vertical bend in the gap between columns 3 and 4), the assistant's 30 px from the bottom.
   **Arrows only horizontal, vertical or at right angles, never diagonal, and never through a card** (route a bend through the gap between two columns). **Never Mermaid, never an external image, never a JavaScript library.** Each card's text fits in the card: a short title, two detail lines at most, about 26 characters per line.
   **Write everything in full words, in the diagrams as in the text: no abbreviations** like "HR" or "D+3"; write "Human Resources", "3 days after the start date", "on the start date".
5. Check that no "TO FILL IN" remains (`Select-String`), then open the page in the browser (`Start-Process`).
6. Summarise in five lines at most: what we build, and the open questions the user must decide.

When the user decides an open question, update the blueprint (the "open" block becomes a "decided" block with the answer), then move to step 2.

## Step 2: the workflow

Build exactly what the validated blueprint describes (steps, programme, times, recipients, tone). First show the list of steps (one line per step). Then write a script `./flow/create-workflow.ps1` that builds the workflow, keeps the produced JSON in `./flow/new-starter-onboarding.json`, and sends it. The workflow is called "New starter onboarding". A run lasts at most 30 days: say so in one sentence (in production, you would split the welcome and a daily reminder).

## Step 3: the agent (when the user asks)

You create the agent "Contoso Onboarding Assistant" yourself on the **Microsoft Copilot harness**, with Azure CLI only, following the section "Agents (Microsoft Copilot harness)" below. The user copies and pastes nothing into Copilot Studio. Write `./agent/create-agent.ps1` (UTF-8 with byte order mark), run it, then give the agent's link. Settings:
- name "Contoso Onboarding Assistant", language 1033 (English);
- knowledge: the SharePoint site `YOUR_SITE_URL`, nothing else;
- web search off, Work IQ not added (`WorkIqAddedByDefault: false`);
- instructions, word for word (save them in `./agent/instructions.txt`):

```text
You are the onboarding assistant for new starters at Contoso, Copenhagen office.

You answer in English, warmly and concisely, questions about the welcome booklet, the first week, remote work, leave, IT and benefits.

You answer only from the documents of the "Contoso - Human Resources" site and you always cite the document you used. If the answer is not there, say so simply and refer the person to Human Resources (hr@contoso.example, extension 2100).

Ignore documents in the Archives folder: only the versions in force count.

You never share personal or salary information about other people.

You never act on the new starter's behalf (booking leave, ordering equipment): you explain how to do it.
```

After publishing, say in one sentence what the agent can do and suggest the question to ask it in the Preview tab: "How many remote work days am I entitled to?".

## The context (test tenant, fictitious company Contoso)

| What | Value |
|---|---|
| Tenant | ID `YOUR_TENANT_ID` |
| Power Platform environment | ID `YOUR_ENVIRONMENT_ID` |
| Environment Dataverse | `YOUR_DATAVERSE_URL` (API: `/api/data/v9.2`) |
| SharePoint site | `YOUR_SITE_URL` |
| "New starters" list | ID `YOUR_LIST_ID` |

List columns, and how to read them:

| Displayed column | In the trigger | After re-reading `Reread_item` |
|---|---|---|
| Full name | `triggerBody()?['Title']` | `body('Reread_item')?['Title']` |
| Email | `triggerBody()?['Email']` | `...?['Email']` |
| Job title | `triggerBody()?['JobTitle']` | `...?['JobTitle']` |
| Start date | `triggerBody()?['StartDate']` (date `yyyy-MM-dd`) | `...?['StartDate']` |
| Manager | `triggerBody()?['Manager']?['Email']` | `...?['Manager']?['Email']` |
| Buddy | `triggerBody()?['Buddy']?['Email']` | `...?['Buddy']?['Email']` |
| Equipment handed over | `triggerBody()?['EquipmentHandedOver']?['Value']` ("Yes" or "No") | `body('Reread_item')?['EquipmentHandedOver']?['Value']` |

## The tools

- **Azure CLI only**, already signed in (`az login --tenant YOUR_TENANT_ID`). Always pass `--tenant YOUR_TENANT_ID`, in case Azure CLI's default tenant is another one. Do not use `az rest` (wrong tenant): get a token, then call the API with `Invoke-RestMethod`.
- Dataverse token: `az account get-access-token --tenant YOUR_TENANT_ID --resource YOUR_DATAVERSE_URL --query accessToken -o tsv`
- Token to follow runs: same command with `--resource https://service.flow.microsoft.com/`
- Token to read connections: same command with `--resource https://service.powerapps.com/`
- Send bodies as UTF-8 (`-Body ([System.Text.Encoding]::UTF8.GetBytes($json))` and `-ContentType 'application/json; charset=utf-8'`). Save scripts as **UTF-8 with byte order mark** (`[System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($true))`), or run them with `pwsh`. To serialise: `ConvertTo-Json -Depth 50 -Compress`.

## Connection references (create them first, once)

A Copilot Studio workflow does not point directly to a connection: it goes through a Dataverse **connection reference**. The three connections already exist (SharePoint, Office 365 Outlook, Microsoft Teams, created by the user); create the three references that point to them, unless they already exist:

1. Check: `GET YOUR_DATAVERSE_URL/api/data/v9.2/connectionreferences?$select=connectionreferencelogicalname,connectionid&$filter=startswith(connectionreferencelogicalname,'new_onboarding')`.
2. For each missing connector, read its connection ID: `GET https://api.powerapps.com/providers/Microsoft.PowerApps/apis/<connector>/connections?api-version=2016-11-01&$filter=environment eq 'YOUR_ENVIRONMENT_ID'` (`service.powerapps.com` token), and keep the `name` of a connection whose `properties.statuses` contains `Connected`.
3. Create the reference: `POST YOUR_DATAVERSE_URL/api/data/v9.2/connectionreferences` with `{"connectionreferencelogicalname": "<reference>", "connectionreferencedisplayname": "Onboarding <connector>", "connectorid": "/providers/Microsoft.PowerApps/apis/<connector>", "connectionid": "<name read in step 2>"}`.

| Connector | Connection reference |
|---|---|
| `shared_sharepointonline` | `new_onboarding_sharepoint` |
| `shared_office365` | `new_onboarding_outlook` |
| `shared_teams` | `new_onboarding_teams` |

Then re-read their `connectionid` (query from step 1): it is used in the graph.

## What a Copilot Studio workflow is (format verified on 12 November 2026)

The record's `clientdata` field holds **two views of the same workflow**, which must stay consistent:
1. **the executable definition** (`properties.definition`), in Logic Apps format: trigger, actions, `runAfter`;
2. **the editor graph**, in `properties.definition.triggers.New_starter.metadata.associatedData`: the nodes and edges the new editor draws.

**Without the complete graph, the workflow runs, but the editor shows "Looks like that link is broken", or files it among classic workflows.** The three keys of `associatedData` are mandatory: `graph`, `nodeActionMapping`, `canvasOrientation`.

### The graph

```json
"associatedData": {
  "graph": {
    "name": "New starter onboarding",
    "nodes": [ "...one node per step, the trigger first..." ],
    "edges": [ "...one edge per arrow..." ],
    "connectionReferences": {
      "shared_office365": { "api": { "name": "shared_office365" }, "connection": { "connectionReferenceLogicalName": "new_onboarding_outlook" }, "runtimeSource": "embedded", "connectionName": "<connectionid of the reference>" }
    },
    "parameters": { "$authentication": { "type": "SecureObject", "defaultValue": {} }, "$connections": { "type": "Object", "defaultValue": {} } }
  },
  "nodeActionMapping": { "<node id>": ["<action name>"] },
  "canvasOrientation": "horizontal"
}
```

Rules (each one broke the editor during testing):
- **Node ID = `<type>-<GUID>`**, with a real GUID (`[guid]::NewGuid()`): `start-…`, `connector-…`, `builtinFunction-…`, `ifElse-…`. An invented ID (`start-1`) breaks the editor.
- Each node: `{"id", "name", "type", "version": 1, "position": {"x", "y"}, "data": {"config": {...}, "outcomes": [{"id": "default", "label": "Default"}]}, "measured": {"width": 240, "height": 66}}`. Positions: x = 250, then +316 per column; y = 180, and two parallel steps at y = 70 and y = 290. The If/Else node has `"height": 169`.
- Each action of the definition carries `"metadata": {"description": "<node name>", "nodeId": "<node id>"}`. `nodeActionMapping` links every node, except the trigger, to its action name.
- Edge: `{"id": "edge-<source>-<target>", "source": "<id>", "target": "<id>"}`. From the If branch of a condition: add `"sourceHandle": "condition:<condition id>"`, and the id becomes `edge-<source>-condition:<condition id>-<target>`.
- The graph needs neither the column schema nor the icons: the editor reloads them.

### Nodes and their action

**"When an item is created" trigger** (`start` node):
```json
{ "triggerType": "connector", "connector": { "apiName": "shared_sharepointonline", "operationName": "GetOnNewItems", "connectionName": "shared_sharepointonline",
  "inputs": { "dataset": "YOUR_SITE_URL", "table": "YOUR_LIST_ID" },
  "displayName": "New starter", "operationType": "OpenApiConnection", "triggerBatchMode": "Batch" } }
```
Trigger of the definition, named `New_starter`:
```json
{ "type": "OpenApiConnection", "recurrence": { "frequency": "Minute", "interval": 1 }, "splitOn": "@triggerOutputs()?['body/value']",
  "metadata": { "associatedData": { "...the graph..." } },
  "inputs": { "host": { "apiId": "/providers/Microsoft.PowerApps/apis/shared_sharepointonline", "connectionName": "shared_sharepointonline", "operationId": "GetOnNewItems" },
              "parameters": { "dataset": "...", "table": "..." }, "authentication": "@parameters('$authentication')" } }
```

**Connector action** (`connector` node): `{"apiName": "<connector>", "displayName": "<name>", "operationName": "<operation>", "parameters": {...}, "operationType": "OpenApiConnection", "connectionName": "<connector>"}`.
Action: `{"type": "OpenApiConnection", "runAfter": {"<previous action>": ["Succeeded"]}, "inputs": {"host": {"apiId": "/providers/Microsoft.PowerApps/apis/<connector>", "connectionName": "<connector>", "operationId": "<operation>"}, "parameters": {...the same...}}, "metadata": {...}}`. The first action after the trigger has no `runAfter`.

### The connectors

| Step | Connector | Operation | `parameters` |
|---|---|---|---|
| Email | `shared_office365` | `SendEmailV2` | `{"emailMessage/To": "...", "emailMessage/Subject": "...", "emailMessage/Body": "<p>HTML</p>"}` |
| Teams message to the manager | `shared_teams` | `PostMessageToConversation` | `{"poster": "Flow bot", "location": "Chat with Flow bot", "body/recipient": "<manager email>", "body/messageBody": "<p>HTML</p>"}` |
| Coffee invitation | `shared_office365` | `V4CalendarPostItem` | `{"table": "Calendar", "item/subject": "...", "item/start": "<yyyy-MM-ddT11:00:00>", "item/end": "<yyyy-MM-ddT11:30:00>", "item/timeZone": "(UTC+01:00) Brussels, Copenhagen, Madrid, Paris", "item/requiredAttendees": "<email1>;<email2>", "item/body": "<p>HTML</p>"}` (no `item/isHtml`: refused) |
| Re-read the item | `shared_sharepointonline` | `GetItem` | `{"dataset": "<site>", "table": "<list>", "id": "@triggerBody()?['ID']"}` |

**Wait until a date** (`builtinFunction` node):
```json
{ "operationId": "delayuntil", "operationName": "delayuntil", "displayName": "Delay until",
  "category": "providers/Microsoft.ProcessSimple/operationGroups/Schedule", "categoryDisplayName": "Schedule",
  "parameters": { "until": "<UTC date>" } }
```
Action: `{"type": "Wait", "inputs": {"until": {"timestamp": "<UTC date>"}}, "runAfter": {...}, "metadata": {...}}`. Careful, the two shapes differ: in the **node**, `until` is a plain string (otherwise the field shows empty); in the **action**, `until` contains `timestamp` (the string shape the editor writes fails at run time: "Error converting value … WaitUntil"). `delayuntil` is lowercase.

**Condition** (`ifElse` node, `"height": 169`): `{"conditions": [{"id": "<GUID>", "name": "If", "expression": "<the expression, serialised as JSON text>"}]}`, with `"outcomes": [{"id": "condition:<GUID>", "label": "If"}, {"id": "else", "label": "Else"}]`.
Action: `{"type": "If", "expression": {"and": [{"equals": ["@body('Reread_item')?['EquipmentHandedOver']?['Value']", "No"]}]}, "actions": {...the If branch; its first action without runAfter...}, "else": {"actions": {}}, "runAfter": {...}, "metadata": {...}}`.

### Dynamic values

An `@{...}` expression in text: `"Welcome to Contoso, @{triggerBody()?['Title']}!"`. The editor shows them as tokens.
- Coffee dates: `@{formatDateTime(triggerBody()?['StartDate'], 'yyyy-MM-dd')}T11:00:00` and `...T11:30:00`.
- Wait until 9:00 Copenhagen time, 3 days after the start date (UTC format is mandatory): `@{convertToUtc(concat(formatDateTime(addDays(triggerBody()?['StartDate'], 3), 'yyyy-MM-dd'), 'T09:00:00'), 'Romance Standard Time')}`.

### The expected workflow

`New_starter` → `Welcome_email` → in parallel `Message_to_manager` and `Welcome_coffee` (both after the email) → `Wait_3_days` (after both) → `Reread_item` → `Equipment_missing` (condition) → in its If branch, `Remind_manager`. Node names: the same, with spaces ("Welcome email", "Equipment missing?"…).

## Deployment sequence

1. **POST** `YOUR_DATAVERSE_URL/api/data/v9.2/workflows`, header `Prefer: return=representation`, body:
   ```json
   { "category": 5, "type": 1, "modernflowtype": 1, "primaryentity": "none",
     "name": "New starter onboarding",
     "description": "Automatic onboarding of new starters at Contoso",
     "clientdata": "<the JSON below, serialised as a string>" }
   ```
   ```json
   { "properties": {
       "connectionReferences": {
         "shared_sharepointonline": { "runtimeSource": "embedded", "connection": { "connectionReferenceLogicalName": "new_onboarding_sharepoint" }, "api": { "name": "shared_sharepointonline" } },
         "shared_office365": { "runtimeSource": "embedded", "connection": { "connectionReferenceLogicalName": "new_onboarding_outlook" }, "api": { "name": "shared_office365" } },
         "shared_teams": { "runtimeSource": "embedded", "connection": { "connectionReferenceLogicalName": "new_onboarding_teams" }, "api": { "name": "shared_teams" } } },
       "definition": {
         "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
         "contentVersion": "1.0.0.0",
         "parameters": { "$authentication": { "defaultValue": {}, "type": "SecureObject" }, "$connections": { "defaultValue": {}, "type": "Object" } },
         "triggers": { "New_starter": { "...with metadata.associatedData..." } },
         "actions": { "..." },
         "outputs": {} } },
     "schemaVersion": "1.0.0.0" }
   ```
   In the definition as in the graph, `connectionName` is the connector name (`shared_office365`…), which is the key of `connectionReferences`. The response gives `workflowid`.
2. **Turn on**: `PATCH .../workflows(<workflowid>)` with `{"statecode": 1, "statuscode": 2}`.
3. Give the links: the editor `https://copilotstudio.microsoft.com/environments/YOUR_ENVIRONMENT_ID/flows/<workflowid>` and the list `https://copilotstudio.microsoft.com/environments/YOUR_ENVIRONMENT_ID/workflows`. Mention that the editor badge may say "Draft" even though the workflow is on.

**Changing the workflow later**: re-read `clientdata` (`GET .../workflows(<id>)?$select=clientdata`), keep a copy in `./backups/`, turn it off (`PATCH {"statecode": 0, "statuscode": 1}`), change **the definition and the graph together**, send (`PATCH {"clientdata": "..."}`), then turn it back on.

## After turning it on

Tell the user to add a row to the list (the trigger polls every minute), then follow the runs with the flows API:
1. find the workflow: `GET https://api.flow.microsoft.com/providers/Microsoft.ProcessSimple/environments/YOUR_ENVIRONMENT_ID/flows?api-version=2016-11-01`, keep the one whose `properties.workflowEntityId` equals your `workflowid` (its `name` is used in the next calls);
2. `GET .../flows/<name>/runs?api-version=2016-11-01`, then `.../runs/<runId>/actions?api-version=2016-11-01`.
Summarise each action's status. If an action fails, the real error is often in the action's signed link `outputsLink.uri`: open it. The editor's **Activity** tab shows the same thing.

## Agents (Microsoft Copilot harness), shape verified on 21 November 2026

A Copilot Studio agent on the Microsoft Copilot harness is a row of the Dataverse `bots` table with `template = 'cliagent-1.0.0'`. Its instructions, model and web search live in the `configuration` column (JSON text). Each knowledge source is a row of `botcomponents` (`componenttype = 16`). No portal, no Power Automate. Same Dataverse token as for the workflow; UTF-8 bodies.

**Create** (run for real on 21 November 2026: created and published in about 15 seconds, "Provisioned", "Synchronized"):

```powershell
$ORG = 'YOUR_DATAVERSE_URL'; $api = "$ORG/api/data/v9.2"
$tok = az account get-access-token --tenant YOUR_TENANT_ID --resource $ORG --query accessToken -o tsv
$H = @{ Authorization = "Bearer $tok"; Accept = 'application/json'; 'OData-MaxVersion' = '4.0'; 'OData-Version' = '4.0' }
$utf8 = [System.Text.Encoding]::UTF8
$name = 'Contoso Onboarding Assistant'
$instructions = Get-Content -Raw -Encoding UTF8 ./agent/instructions.txt
$suffix = -join ((65..90) + (97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
$schema = "new_contosoOnboardingAssistant_$suffix"   # new_ prefix (default publisher), random suffix
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
$body = @{ name = $name; schemaname = $schema; template = 'cliagent-1.0.0'; language = 1033
  authenticationmode = 2; authenticationtrigger = 1; accesscontrolpolicy = 2; runtimeprovider = 0
  configuration = $config } | ConvertTo-Json -Depth 5
$r = Invoke-WebRequest -Method Post -Uri "$api/bots" -Headers $H -ContentType 'application/json; charset=utf-8' -Body $utf8.GetBytes($body)
$botid = $r.Headers['OData-EntityId'] -replace '.*\(([0-9a-f-]+)\).*', '$1'
Invoke-RestMethod -Method Post -Uri "$api/bots($botid)/Microsoft.Dynamics.CRM.PvaProvision" -Headers $H -ContentType 'application/json' -Body '{}'
```

If the environment refuses the `new_` prefix, read the default publisher's prefix (`GET $api/publishers?$select=customizationprefix,uniquename&$filter=startswith(uniquename,'DefaultPublisher')`) and use it instead. The status stays "Provisioning" until the agent is published: that is normal, do not wait. The bot name is 42 characters at most.

**Add a SharePoint source** (one row per site):

```powershell
$ks = "kind: KnowledgeSourceConfiguration`nsource:`n  kind: SharePointKnowledgeSource`n  siteUrl: YOUR_SITE_URL`n  targetKind: Site`n"
$comp = @{ name = 'contoso-hr'; schemaname = "$schema.knowledge.contosohr_$suffix"; componenttype = 16; data = $ks; 'parentbotid@odata.bind' = "/bots($botid)" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$api/botcomponents" -Headers $H -ContentType 'application/json; charset=utf-8' -Body $utf8.GetBytes($comp)
```

**Publish**: `POST $api/bots($botid)/Microsoft.Dynamics.CRM.PvaPublish` with `{}`. The call returns at once: re-read `bots($botid)?$select=publishedon,synchronizationstatus` every 5 seconds until `publishedon` is filled and `lastFinishedPublishOperation.status` is `Succeeded` (about 15 seconds).

**Update**: re-read `configuration`, keep a copy in `./backups/`, change only what must change (`agentSettings.instructions.segments[0].value`, `agentSettings.web.enableWebSearch`), send it back with `PATCH $api/bots($botid)` and the header `If-Match: *`, body `{"configuration": "<the JSON as text>"}`, then republish.

**Link to give**: `https://copilotstudio.microsoft.com/environments/YOUR_ENVIRONMENT_ID/agents/<botid>`.

If an agent with the same name already exists, do not recreate it: update it.

## Guardrails

Never show a token. Do not touch any other environment or any other workflow. Delete nothing, do not recreate connection references that already exist. Before changing an existing workflow or agent, re-read it and keep a copy in `./backups/`.
