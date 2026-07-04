param(
  [Parameter(Mandatory = $true)]
  [string]$RunDir,

  [Parameter(Mandatory = $true)]
  [string]$RepoRoot
)

$ErrorActionPreference = "Stop"

function Resolve-CommandPath {
  param([Parameter(Mandatory = $true)][string[]]$Names)

  foreach ($name in $Names) {
    $command = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
      return $command.Source
    }
  }

  return $null
}

$rawDir = Join-Path $RunDir "raw"
$telemetryDir = Join-Path $RunDir "telemetry"
New-Item -ItemType Directory -Force $rawDir | Out-Null
New-Item -ItemType Directory -Force $telemetryDir | Out-Null

$lumberjacksPath = if ($env:FIELDLAB_LUMBERJACKS_PATH) { $env:FIELDLAB_LUMBERJACKS_PATH } else { "C:\work\Lumberjacks" }
$dotnetPath = if (Test-Path "C:\work\dotnet9\dotnet.exe") { "C:\work\dotnet9\dotnet.exe" } else { "dotnet" }
$nodePath = Resolve-CommandPath @("node.exe", "node")
$npmPath = Resolve-CommandPath @("npm.cmd", "npm.exe", "npm")
$postgresPort = if ($env:FIELDLAB_PGPORT) { [int]$env:FIELDLAB_PGPORT } else { 5433 }
$postgresHost = if ($env:FIELDLAB_PGHOST) { $env:FIELDLAB_PGHOST } else { "127.0.0.1" }
$connectionStringOverride = $env:FIELDLAB_GAME_DB_CONNECTION
$connectionString = $null
$keepRunning = $env:FIELDLAB_KEEP_RUNNING -eq "1"

function Write-JsonFile {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Value,

    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $Value | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 $Path
}

function Test-TcpPort {
  param(
    [Parameter(Mandatory = $true)]
    [string]$HostName,

    [Parameter(Mandatory = $true)]
    [int]$Port,

    [int]$TimeoutMs = 1000
  )

  $client = [System.Net.Sockets.TcpClient]::new()
  $asyncResult = $null
  try {
    $asyncResult = $client.BeginConnect($HostName, $Port, $null, $null)
    if (-not $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
      return $false
    }
    $client.EndConnect($asyncResult)
    return $client.Connected
  } catch {
    return $false
  } finally {
    if ($asyncResult) {
      $asyncResult.AsyncWaitHandle.Close()
    }
    $client.Close()
    $client.Dispose()
  }
}

function Wait-TcpPort {
  param(
    [Parameter(Mandatory = $true)]
    [string]$HostName,

    [Parameter(Mandatory = $true)]
    [int]$Port,

    [int]$TimeoutSeconds = 60
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    if (Test-TcpPort -HostName $HostName -Port $Port -TimeoutMs 1000) {
      return $true
    }
    Start-Sleep -Milliseconds 500
  } while ((Get-Date) -lt $deadline)

  return $false
}

function Get-WslIpv4Candidates {
  if (-not (Get-Command "wsl" -ErrorAction SilentlyContinue)) {
    return @()
  }

  $output = & wsl -e bash -lc "hostname -I" 2>$null
  if (-not $output) {
    return @()
  }

  return @($output -split "\s+" | Where-Object {
      $_ -match "^\d{1,3}(\.\d{1,3}){3}$" -and $_ -ne "127.0.0.1"
    } | Select-Object -Unique)
}

function Resolve-ReachablePostgresHost {
  param(
    [Parameter(Mandatory = $true)]
    [string]$InitialHost,

    [Parameter(Mandatory = $true)]
    [int]$Port,

    [bool]$AllowWslFallback
  )

  if (Wait-TcpPort -HostName $InitialHost -Port $Port -TimeoutSeconds 45) {
    return [ordered]@{
      host = $InitialHost
      reachable = $true
      source = "configured"
      candidates = @()
    }
  }

  $candidates = @()
  if ($AllowWslFallback) {
    foreach ($candidate in Get-WslIpv4Candidates) {
      $candidates += $candidate
      if (Wait-TcpPort -HostName $candidate -Port $Port -TimeoutSeconds 3) {
        return [ordered]@{
          host = $candidate
          reachable = $true
          source = "wsl_ipv4"
          candidates = $candidates
        }
      }
    }
  }

  return [ordered]@{
    host = $InitialHost
    reachable = $false
    source = "unreachable"
    candidates = $candidates
  }
}

function Wait-HttpOk {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Url,

    [int]$TimeoutSeconds = 120
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $lastError = $null

  do {
    try {
      $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
      if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
        return [ordered]@{
          ready = $true
          status_code = $response.StatusCode
          error = $null
        }
      }
    } catch {
      $lastError = $_.Exception.Message
    }
    Start-Sleep -Seconds 1
  } while ((Get-Date) -lt $deadline)

  return [ordered]@{
    ready = $false
    status_code = $null
    error = $lastError
  }
}

function Invoke-LoggedProcess {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [string[]]$ArgumentList = @(),

    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [int]$TimeoutSeconds = 0
  )

  $stdoutPath = Join-Path $rawDir "$Name.out.log"
  $stderrPath = Join-Path $rawDir "$Name.err.log"

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo.FileName = $FilePath
  $process.StartInfo.WorkingDirectory = $WorkingDirectory
  $process.StartInfo.UseShellExecute = $false
  $process.StartInfo.CreateNoWindow = $true
  $process.StartInfo.RedirectStandardOutput = $true
  $process.StartInfo.RedirectStandardError = $true

  if ($ArgumentList.Count -gt 0) {
    $process.StartInfo.Arguments = ($ArgumentList | ForEach-Object {
        if ($_ -match '[\s"]') {
          '"' + ($_ -replace '"', '\"') + '"'
        } else {
          $_
        }
      }) -join " "
  }

  $timedOut = $false
  $stdoutTask = $null
  $stderrTask = $null
  try {
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    if ($TimeoutSeconds -gt 0) {
      if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $timedOut = $true
        try {
          Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        } catch {
        }
        $process.WaitForExit()
      }
    } else {
      $process.WaitForExit()
    }

    $process.WaitForExit()
    $stdoutTask.Wait()
    $stderrTask.Wait()
  } finally {
    $encoding = [System.Text.UTF8Encoding]::new($false)
    $stdout = if ($stdoutTask -and $stdoutTask.IsCompleted) { $stdoutTask.Result } else { "" }
    $stderr = if ($stderrTask -and $stderrTask.IsCompleted) { $stderrTask.Result } else { "" }
    [System.IO.File]::WriteAllText($stdoutPath, $stdout, $encoding)
    [System.IO.File]::WriteAllText($stderrPath, $stderr, $encoding)
  }

  return [ordered]@{
    name = $Name
    file = $FilePath
    arguments = $ArgumentList
    working_directory = $WorkingDirectory
    exit_code = if ($timedOut) { -1 } else { $process.ExitCode }
    timed_out = $timedOut
    stdout = "raw/$Name.out.log"
    stderr = "raw/$Name.err.log"
  }
}

function Parse-LoadSummary {
  param([string]$LogPath)

  $summary = [ordered]@{
    parsed = $false
    udp_inputs_sent = $null
    ws_entity_updates = $null
    udp_entity_updates = $null
    errors = $null
    disconnects = $null
    channel_result = "unknown"
  }

  if (-not (Test-Path $LogPath)) {
    return $summary
  }

  foreach ($line in (Get-Content -Tail 120 $LogPath)) {
    if ($line -match "Total UDP inputs sent:\s+([0-9,]+)") {
      $summary.udp_inputs_sent = [int](($Matches[1]) -replace ",", "")
      $summary.parsed = $true
    } elseif ($line -match "Total WS entity_updates:\s+([0-9,]+)") {
      $summary.ws_entity_updates = [int](($Matches[1]) -replace ",", "")
      $summary.parsed = $true
    } elseif ($line -match "Total UDP entity_updates:\s+([0-9,]+)") {
      $summary.udp_entity_updates = [int](($Matches[1]) -replace ",", "")
      $summary.parsed = $true
    } elseif ($line -match "Errors:\s+([0-9,]+)") {
      $summary.errors = [int](($Matches[1]) -replace ",", "")
      $summary.parsed = $true
    } elseif ($line -match "Disconnects:\s+([0-9,]+)") {
      $summary.disconnects = [int](($Matches[1]) -replace ",", "")
      $summary.parsed = $true
    } elseif ($line -match "UDP channel is ACTIVE") {
      $summary.channel_result = "udp_enhanced"
    } elseif ($line -match "UDP channel NOT receiving") {
      $summary.channel_result = "websocket_fallback"
    } elseif ($line -match "No entity updates received") {
      $summary.channel_result = "no_updates"
    }
  }

  return $summary
}

function Stop-ProcessTree {
  param([Parameter(Mandatory = $true)][int]$ProcessId)

  $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue)
  foreach ($child in $children) {
    Stop-ProcessTree -ProcessId $child.ProcessId
  }

  try {
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
  } catch {
  }
}

function Stop-RuntimeProcesses {
  param([object[]]$Processes)

  foreach ($svc in @($Processes)) {
    if ($svc.process -and -not $svc.process.HasExited) {
      Stop-ProcessTree -ProcessId $svc.process.Id
    }
  }
}

$runtimeSummary = [ordered]@{
  schema_version = 1
  started_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  repo_root = $RepoRoot
  lumberjacks_path = $lumberjacksPath
  keep_running = $keepRunning
  prerequisites = [ordered]@{}
  infrastructure = [ordered]@{}
  services = @()
  probes = @()
  load_summary = $null
  status = "unknown"
}

try {
  $runtimeSummary.prerequisites.lumberjacks_exists = Test-Path $lumberjacksPath
  $runtimeSummary.prerequisites.dotnet_path = $dotnetPath
  $runtimeSummary.prerequisites.dotnet_available = [bool](Get-Command $dotnetPath -ErrorAction SilentlyContinue)
  $runtimeSummary.prerequisites.node_path = $nodePath
  $runtimeSummary.prerequisites.node_available = [bool]$nodePath
  $runtimeSummary.prerequisites.npm_path = $npmPath
  $runtimeSummary.prerequisites.npm_available = [bool]$npmPath
  $runtimeSummary.prerequisites.docker_available = [bool](Get-Command "docker" -ErrorAction SilentlyContinue)

  if (-not $runtimeSummary.prerequisites.lumberjacks_exists) {
    $runtimeSummary.status = "blocked_missing_lumberjacks"
    Write-JsonFile $runtimeSummary (Join-Path $telemetryDir "runtime-summary.json")
    exit 0
  }

  if (-not $runtimeSummary.prerequisites.dotnet_available -or -not $runtimeSummary.prerequisites.node_available -or -not $runtimeSummary.prerequisites.npm_available) {
    $runtimeSummary.status = "blocked_missing_tooling"
    Write-JsonFile $runtimeSummary (Join-Path $telemetryDir "runtime-summary.json")
    exit 0
  }

  $dockerStartedPostgres = $false
  if ($runtimeSummary.prerequisites.docker_available) {
    $previousPgPort = $env:PGPORT
    $env:PGPORT = [string]$postgresPort
    try {
      $composeStep = Invoke-LoggedProcess `
        -FilePath "docker" `
        -ArgumentList @("compose", "-f", "infra/docker/docker-compose.yml", "up", "-d", "postgres") `
        -WorkingDirectory $lumberjacksPath `
        -Name "runtime-docker-postgres-up" `
        -TimeoutSeconds 120
      $runtimeSummary.infrastructure.docker_compose = $composeStep
      $dockerStartedPostgres = $composeStep.exit_code -eq 0
    } finally {
      if ($null -eq $previousPgPort) {
        Remove-Item Env:PGPORT -ErrorAction SilentlyContinue
      } else {
        $env:PGPORT = $previousPgPort
      }
    }
  }

  $postgresResolution = Resolve-ReachablePostgresHost `
    -InitialHost $postgresHost `
    -Port $postgresPort `
    -AllowWslFallback (-not $env:FIELDLAB_PGHOST)
  $postgresHost = $postgresResolution.host
  $postgresReachable = $postgresResolution.reachable
  $connectionString = if ($connectionStringOverride) {
    $connectionStringOverride
  } else {
    "Host=$postgresHost;Port=$postgresPort;Database=game;Username=game;Password=game"
  }
  $runtimeSummary.infrastructure.postgres_host = $postgresHost
  $runtimeSummary.infrastructure.postgres_port = $postgresPort
  $runtimeSummary.infrastructure.connection_string = $connectionString
  $runtimeSummary.infrastructure.postgres_host_source = $postgresResolution.source
  $runtimeSummary.infrastructure.wsl_ipv4_candidates = $postgresResolution.candidates
  $runtimeSummary.infrastructure.postgres_reachable = $postgresReachable
  $runtimeSummary.infrastructure.postgres_mode = if ($dockerStartedPostgres) { "docker" } elseif ($postgresReachable) { "external" } else { "missing" }

  if (-not $postgresReachable) {
    $runtimeSummary.status = "blocked_missing_database"
    Write-JsonFile $runtimeSummary (Join-Path $telemetryDir "runtime-summary.json")
    @(
      "# Runtime Command Plan",
      "",
      "Status: blocked_missing_database",
      "",
      "Docker was not available or could not start Postgres, and no external Postgres answered at ${postgresHost}:${postgresPort}.",
      "",
      "Set one of these before rerunning:",
      "",
      "- Install/start Docker so ``docker compose -f infra/docker/docker-compose.yml up -d postgres`` works.",
      "- Start an external Postgres and set ``FIELDLAB_GAME_DB_CONNECTION`` plus ``FIELDLAB_PGHOST``/``FIELDLAB_PGPORT``."
    ) | Set-Content -Encoding UTF8 (Join-Path $rawDir "command-plan-summary.md")
    exit 0
  }

  if (-not (Test-Path (Join-Path $lumberjacksPath "node_modules\ws"))) {
    $npmArguments = if (Test-Path (Join-Path $lumberjacksPath "package-lock.json")) {
      @("ci")
    } else {
      @("install", "--no-save", "--package-lock=false")
    }

    $runtimeSummary.probes += Invoke-LoggedProcess `
      -FilePath $npmPath `
      -ArgumentList $npmArguments `
      -WorkingDirectory $lumberjacksPath `
      -Name "runtime-npm-install" `
      -TimeoutSeconds 180
  }

  $services = @(
    [ordered]@{ name = "eventlog"; project = "src/Game.EventLog"; url = "http://localhost:4002"; health = "http://localhost:4002/health" },
    [ordered]@{ name = "progression"; project = "src/Game.Progression"; url = "http://localhost:4003"; health = "http://localhost:4003/health" },
    [ordered]@{ name = "operatorapi"; project = "src/Game.OperatorApi"; url = "http://localhost:4004"; health = "http://localhost:4004/health" },
    [ordered]@{ name = "gateway"; project = "src/Game.Gateway"; url = "http://localhost:4000"; health = "http://localhost:4000/health" }
  )

  $startedServices = @()
  foreach ($svc in $services) {
    $stdoutPath = Join-Path $rawDir "service-$($svc.name).out.log"
    $stderrPath = Join-Path $rawDir "service-$($svc.name).err.log"

    $previousUrls = $env:Urls
    $previousConnectionString = $env:ConnectionStrings__GameDb
    $previousGateway = $env:ServiceUrls__Gateway
    $previousEventLog = $env:ServiceUrls__EventLog
    $previousProgression = $env:ServiceUrls__Progression

    $env:Urls = $svc.url
    $env:ConnectionStrings__GameDb = $connectionString
    $env:ServiceUrls__Gateway = "http://localhost:4000"
    $env:ServiceUrls__EventLog = "http://localhost:4002"
    $env:ServiceUrls__Progression = "http://localhost:4003"

    try {
      $process = Start-Process -FilePath $dotnetPath `
        -ArgumentList @("run", "--project", $svc.project) `
        -WorkingDirectory $lumberjacksPath `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -NoNewWindow `
        -PassThru
    } finally {
      if ($null -eq $previousUrls) { Remove-Item Env:Urls -ErrorAction SilentlyContinue } else { $env:Urls = $previousUrls }
      if ($null -eq $previousConnectionString) { Remove-Item Env:ConnectionStrings__GameDb -ErrorAction SilentlyContinue } else { $env:ConnectionStrings__GameDb = $previousConnectionString }
      if ($null -eq $previousGateway) { Remove-Item Env:ServiceUrls__Gateway -ErrorAction SilentlyContinue } else { $env:ServiceUrls__Gateway = $previousGateway }
      if ($null -eq $previousEventLog) { Remove-Item Env:ServiceUrls__EventLog -ErrorAction SilentlyContinue } else { $env:ServiceUrls__EventLog = $previousEventLog }
      if ($null -eq $previousProgression) { Remove-Item Env:ServiceUrls__Progression -ErrorAction SilentlyContinue } else { $env:ServiceUrls__Progression = $previousProgression }
    }

    $serviceRecord = [ordered]@{
      name = $svc.name
      project = $svc.project
      pid = $process.Id
      url = $svc.url
      health = $svc.health
      stdout = "raw/service-$($svc.name).out.log"
      stderr = "raw/service-$($svc.name).err.log"
      process = $process
      readiness = $null
    }
    $startedServices += $serviceRecord
  }

  foreach ($svc in $startedServices) {
    $svc.readiness = Wait-HttpOk -Url $svc.health -TimeoutSeconds 120
  }

  $runtimeSummary.services = @($startedServices | ForEach-Object {
    [ordered]@{
      name = $_.name
      project = $_.project
      pid = $_.pid
      url = $_.url
      health = $_.health
      stdout = $_.stdout
      stderr = $_.stderr
      readiness = $_.readiness
    }
  })

  $notReady = @($startedServices | Where-Object { -not $_.readiness.ready })
  if ($notReady.Count -gt 0) {
    $runtimeSummary.status = "fail_service_readiness"
    Write-JsonFile $runtimeSummary (Join-Path $telemetryDir "runtime-summary.json")
    exit 1
  }

  $runtimeSummary.probes += Invoke-LoggedProcess `
    -FilePath $nodePath `
    -ArgumentList @("scripts/test-vertical-slice.js", "ws://localhost:4000") `
    -WorkingDirectory $lumberjacksPath `
    -Name "runtime-vertical-slice" `
    -TimeoutSeconds 45

  $runtimeSummary.probes += Invoke-LoggedProcess `
    -FilePath $nodePath `
    -ArgumentList @("scripts/test-multiplayer.js", "5", "ws://localhost:4000") `
    -WorkingDirectory $lumberjacksPath `
    -Name "runtime-multiplayer-5" `
    -TimeoutSeconds 75

  $runtimeSummary.probes += Invoke-LoggedProcess `
    -FilePath $nodePath `
    -ArgumentList @("scripts/load-test-dual-channel.js", "ws://localhost:4000", "20", "10") `
    -WorkingDirectory $lumberjacksPath `
    -Name "runtime-load-dual-channel-20x10" `
    -TimeoutSeconds 45

  $runtimeSummary.load_summary = Parse-LoadSummary (Join-Path $rawDir "runtime-load-dual-channel-20x10.out.log")

  $failedProbeCount = @($runtimeSummary.probes | Where-Object { $_.exit_code -ne 0 }).Count
  $runtimeSummary.status = if ($failedProbeCount -eq 0) { "pass" } else { "fail_probe" }

  @(
    "# Runtime Command Plan",
    "",
    "Status: $($runtimeSummary.status)",
    "",
    "Artifacts written:",
    "",
    '- `telemetry/runtime-summary.json`',
    '- `raw/service-*.out.log`',
    '- `raw/runtime-vertical-slice.out.log`',
    '- `raw/runtime-multiplayer-5.out.log`',
    '- `raw/runtime-load-dual-channel-20x10.out.log`',
    "",
    "Channel result: $($runtimeSummary.load_summary.channel_result)"
  ) | Set-Content -Encoding UTF8 (Join-Path $rawDir "command-plan-summary.md")

  Write-JsonFile $runtimeSummary (Join-Path $telemetryDir "runtime-summary.json")

  if ($runtimeSummary.status -ne "pass") {
    exit 1
  }
} finally {
  if (-not $keepRunning -and $startedServices) {
    Stop-RuntimeProcesses -Processes $startedServices
  }
}

exit 0
