param(
  [Parameter(Mandatory = $true)]
  [string]$RunDir,

  [Parameter(Mandatory = $true)]
  [string]$RepoRoot
)

$ErrorActionPreference = "Stop"

$rawDir = Join-Path $RunDir "raw"
$telemetryDir = Join-Path $RunDir "telemetry"
New-Item -ItemType Directory -Force $rawDir | Out-Null
New-Item -ItemType Directory -Force $telemetryDir | Out-Null

function Get-GitInfo {
  param([string]$Path)

  if (-not (Test-Path (Join-Path $Path ".git"))) {
    return $null
  }

  $commit = git -C $Path rev-parse HEAD 2>$null
  $branch = git -C $Path branch --show-current 2>$null
  $status = git -C $Path status --short 2>$null

  return [ordered]@{
    path = $Path
    branch = $branch
    commit = $commit
    status_short = @($status)
  }
}

function Get-FileSummary {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return [ordered]@{
      path = $Path
      exists = $false
    }
  }

  $item = Get-Item $Path
  return [ordered]@{
    path = $Path
    exists = $true
    length = $item.Length
    last_write_time = $item.LastWriteTimeUtc.ToString("o")
  }
}

$lumberjacksPath = "C:\work\Lumberjacks"
$stewardViewPath = "C:\work\ComfyStewardView"

$discovery = [ordered]@{
  schema_version = 1
  captured_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  repo_root = $RepoRoot
  repositories = @{
    comfy = Get-GitInfo $RepoRoot
    lumberjacks = Get-GitInfo $lumberjacksPath
    comfy_steward_view = Get-GitInfo $stewardViewPath
  }
  expected_paths = @{
    lumberjacks = [ordered]@{
      path = $lumberjacksPath
      exists = Test-Path $lumberjacksPath
      note = "Clone djcdevelopment/Lumberjacks here or override future scenario settings."
    }
    comfy_steward_view = [ordered]@{
      path = $stewardViewPath
      exists = Test-Path $stewardViewPath
    }
  }
  datasets = @{
    era12 = Get-FileSummary (Join-Path $RepoRoot "erasave\ComfyEra12.db")
    era16 = Get-FileSummary (Join-Path $RepoRoot "erasave\ComfyEra16.db")
    waypoints = Get-FileSummary (Join-Path $RepoRoot "waypoints.json")
    classification = Get-FileSummary (Join-Path $RepoRoot "erasave\classification.json")
  }
}

$discovery | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 (Join-Path $rawDir "discovery.json")

$trafficClasses = [ordered]@{
  schema_version = 1
  goal = "Make traffic categorization and prioritization visible for creators and technical peers."
  classes = @(
    [ordered]@{
      id = "reliable_core"
      lane = "Reliable"
      examples = @("session_started", "join_region", "place_structure", "event_emitted", "reward_granted")
      promise = "Preserve game and progression truth."
      degradation = "Must not be dropped under ordinary pressure."
    },
    [ordered]@{
      id = "datagram_fidelity"
      lane = "Datagram"
      examples = @("player_input", "entity_update", "entity_removed")
      promise = "Improve freshness when available."
      degradation = "Can be superseded by newer state."
    },
    [ordered]@{
      id = "fallback"
      lane = "WebSocket"
      examples = @("binary_over_ws", "json_over_ws")
      promise = "Keep baseline play working without enhanced transport."
      degradation = "Higher bandwidth or more latency, but same critical truth."
    },
    [ordered]@{
      id = "low_priority"
      lane = "DeferredOrDropped"
      examples = @("distant_cosmetic_freshness", "far_settlement_detail", "ambient_updates")
      promise = "Give creators richness when budget exists."
      degradation = "Drop or thin first under pressure."
    }
  )
}

$trafficClasses | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 (Join-Path $telemetryDir "traffic-classes.expected.json")

function Invoke-LoggedProcess {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [string[]]$ArgumentList = @(),

    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory,

    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  $stdoutPath = Join-Path $rawDir "$Name.out.log"
  $stderrPath = Join-Path $rawDir "$Name.err.log"

  $process = Start-Process -FilePath $FilePath `
    -ArgumentList $ArgumentList `
    -WorkingDirectory $WorkingDirectory `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath `
    -NoNewWindow `
    -Wait `
    -PassThru

  return [ordered]@{
    name = $Name
    file = $FilePath
    arguments = $ArgumentList
    working_directory = $WorkingDirectory
    exit_code = $process.ExitCode
    stdout = "raw/$Name.out.log"
    stderr = "raw/$Name.err.log"
  }
}

$dotnetPath = if (Test-Path "C:\work\dotnet9\dotnet.exe") {
  "C:\work\dotnet9\dotnet.exe"
} else {
  "dotnet"
}

$testSteps = @()

if (Test-Path $lumberjacksPath) {
  $testSteps += Invoke-LoggedProcess `
    -FilePath $dotnetPath `
    -ArgumentList @("--version") `
    -WorkingDirectory $lumberjacksPath `
    -Name "lumberjacks-dotnet-version"

  $testSteps += Invoke-LoggedProcess `
    -FilePath $dotnetPath `
    -ArgumentList @("test", "Game.sln") `
    -WorkingDirectory $lumberjacksPath `
    -Name "lumberjacks-solution-tests"
}

$testSummary = [ordered]@{
  schema_version = 1
  lumberjacks_path = $lumberjacksPath
  lumberjacks_exists = Test-Path $lumberjacksPath
  dotnet_path = $dotnetPath
  steps = $testSteps
  status = if (-not (Test-Path $lumberjacksPath)) {
    "not_run_missing_lumberjacks"
  } elseif (@($testSteps | Where-Object { $_.exit_code -ne 0 }).Count -eq 0) {
    "pass"
  } else {
    "fail"
  }
}

$testSummary | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 (Join-Path $telemetryDir "lumberjacks-test-summary.json")

$fieldNotes = @(
  "# Discovery Command Plan",
  "",
  "This command plan is intentionally safe. It does not start services, run VMs, or mutate external state.",
  "",
  "Artifacts written:",
  "",
  '- `raw/discovery.json`',
  '- `telemetry/traffic-classes.expected.json`',
  '- `telemetry/lumberjacks-test-summary.json`',
  "",
  "Next build step: add service startup, E2E scripts, and load-test capture once the direct unit test packet is stable."
)

$fieldNotes | Set-Content -Encoding UTF8 (Join-Path $rawDir "command-plan-summary.md")

if ($testSummary.status -eq "fail") {
  exit 1
}

exit 0
