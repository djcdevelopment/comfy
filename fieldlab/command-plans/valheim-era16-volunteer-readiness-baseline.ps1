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

$summaryPath = Join-Path $telemetryDir "volunteer-readiness-summary.json"
$metricsPath = Join-Path $telemetryDir "baseline-metrics.json"
$routeContractPath = Join-Path $telemetryDir "teleport-route-contract.json"
$inventoryPath = Join-Path $rawDir "setup-inventory.json"
$commandSummaryPath = Join-Path $rawDir "command-plan-summary.md"
$checkpointPath = Join-Path $rawDir "readiness-checkpoints.log"

function Add-Checkpoint {
  param([string]$Name)

  "$(Get-Date -Format o) $Name" | Add-Content -Encoding UTF8 $checkpointPath
}

function Write-JsonFile {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Value,

    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $Value | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $Path
}

function Test-EnvFlag {
  param([string]$Name)

  $value = [Environment]::GetEnvironmentVariable($Name)
  if ([string]::IsNullOrWhiteSpace($value)) {
    return $false
  }

  return ($value.Trim() -match "^(1|true|yes|on)$")
}

function Get-NumberStats {
  param([object[]]$Values)

  $numbers = @(
    $Values |
      Where-Object { $null -ne $_ -and -not ($_ -is [string] -and [string]::IsNullOrWhiteSpace($_)) } |
      ForEach-Object {
        try {
          [double]$_
        } catch {
          $null
        }
      } |
      Where-Object { $null -ne $_ -and -not [double]::IsNaN($_) } |
      Sort-Object
  )

  if ($numbers.Count -eq 0) {
    return [ordered]@{
      count = 0
      min = $null
      max = $null
      avg = $null
      p50 = $null
      p95 = $null
    }
  }

  $sum = 0.0
  foreach ($number in $numbers) {
    $sum += $number
  }

  $p50Index = [int]([Math]::Ceiling($numbers.Count * 0.50) - 1)
  if ($p50Index -lt 0) {
    $p50Index = 0
  } elseif ($p50Index -ge $numbers.Count) {
    $p50Index = $numbers.Count - 1
  }

  $p95Index = [int]([Math]::Ceiling($numbers.Count * 0.95) - 1)
  if ($p95Index -lt 0) {
    $p95Index = 0
  } elseif ($p95Index -ge $numbers.Count) {
    $p95Index = $numbers.Count - 1
  }

  return [ordered]@{
    count = $numbers.Count
    min = [Math]::Round($numbers[0], 3)
    max = [Math]::Round($numbers[$numbers.Count - 1], 3)
    avg = [Math]::Round($sum / $numbers.Count, 3)
    p50 = [Math]::Round($numbers[$p50Index], 3)
    p95 = [Math]::Round($numbers[$p95Index], 3)
  }
}

function Convert-TelemetryDate {
  param([object]$Value)

  if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
    return $null
  }

  try {
    return [datetimeoffset]::Parse([string]$Value).UtcDateTime
  } catch {
    return $null
  }
}

function Read-JsonLines {
  param([string]$Path)

  $records = New-Object System.Collections.Generic.List[object]
  $parseErrors = 0

  if (-not (Test-Path $Path)) {
    return [ordered]@{
      path = $Path
      exists = $false
      records = $records
      parse_errors = 0
    }
  }

  Get-Content -Path $Path | ForEach-Object {
    if ([string]::IsNullOrWhiteSpace($_)) {
      return
    }

    try {
      $records.Add(($_ | ConvertFrom-Json)) | Out-Null
    } catch {
      $parseErrors += 1
    }
  }

  return [ordered]@{
    path = $Path
    exists = $true
    records = $records
    parse_errors = $parseErrors
  }
}

function New-Gate {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Id,

    [Parameter(Mandatory = $true)]
    [string]$Status,

    [Parameter(Mandatory = $true)]
    [string]$Requirement,

    [Parameter(Mandatory = $true)]
    [string]$Observed
  )

  return [ordered]@{
    id = $Id
    status = $Status
    requirement = $Requirement
    observed = $Observed
  }
}

function Resolve-NetworkSenseLogDir {
  $candidates = @()
  if ($env:FIELDLAB_NETWORKSENSE_LOG_DIR) {
    $candidates += $env:FIELDLAB_NETWORKSENSE_LOG_DIR
  }

  $candidates += @(
    "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-network-sense",
    "C:\Program Files\Steam\steamapps\common\Valheim\BepInEx\config\comfy-network-sense"
  )

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path $candidate -PathType Container)) {
      return (Resolve-Path $candidate).Path
    }
  }

  return $candidates[0]
}

function Get-LatestDensityMatrixSummary {
  param([string]$Root)

  $runsPath = Join-Path $Root "fieldlab\runs"
  if (-not (Test-Path $runsPath)) {
    return [ordered]@{
      found = $false
      status = "missing"
    }
  }

  $candidate = Get-ChildItem -Path $runsPath -Directory -Filter "*era16-density-pressure-matrix" |
    Sort-Object LastWriteTime -Descending |
    Where-Object { Test-Path (Join-Path $_.FullName "telemetry\matrix-summary.json") } |
    Select-Object -First 1

  if (-not $candidate) {
    return [ordered]@{
      found = $false
      status = "missing"
    }
  }

  try {
    $summaryPath = Join-Path $candidate.FullName "telemetry\matrix-summary.json"
    $summary = Get-Content -Raw $summaryPath | ConvertFrom-Json
    return [ordered]@{
      found = $true
      run_id = $candidate.Name
      path = $candidate.FullName
      summary_path = $summaryPath
      status = $summary.status
      density_fixture_count = $summary.density_fixture_count
      matrix_row_count = $summary.matrix_row_count
      density_fixtures = @($summary.density_fixtures)
    }
  } catch {
    return [ordered]@{
      found = $true
      run_id = $candidate.Name
      path = $candidate.FullName
      status = "unreadable"
    }
  }
}

function Get-ResourceProfileContract {
  param([object]$HostInventory)

  $requestedProfile = if ($env:FIELDLAB_RESOURCE_PROFILE) { $env:FIELDLAB_RESOURCE_PROFILE } else { "host_full" }
  $requestedWslMemoryGb = if ($env:FIELDLAB_WSL_MEMORY_GB) { $env:FIELDLAB_WSL_MEMORY_GB } else { $null }
  $requestedWslProcessors = if ($env:FIELDLAB_WSL_PROCESSORS) { $env:FIELDLAB_WSL_PROCESSORS } else { $null }
  $requestedClientAffinity = if ($env:FIELDLAB_CLIENT_AFFINITY) { $env:FIELDLAB_CLIENT_AFFINITY } else { $null }
  $requestedClientPriority = if ($env:FIELDLAB_CLIENT_PRIORITY) { $env:FIELDLAB_CLIENT_PRIORITY } else { $null }

  return [ordered]@{
    applied_by_this_packet = $false
    apply_requested_by_this_packet = (Test-EnvFlag "FIELDLAB_APPLY_WSL_LIMITS")
    shutdown_requested_by_this_packet = (Test-EnvFlag "FIELDLAB_WSL_SHUTDOWN")
    clear_requested_by_this_packet = (Test-EnvFlag "FIELDLAB_CLEAR_WSL_LIMITS")
    requested_profile = $requestedProfile
    requested_wsl_memory_gb = $requestedWslMemoryGb
    requested_wsl_processors = $requestedWslProcessors
    requested_client_affinity = $requestedClientAffinity
    requested_client_priority = $requestedClientPriority
    observed_host_memory_gb = $HostInventory.total_memory_gb
    observed_host_logical_processors = $HostInventory.logical_processors
    planned_profiles = @(
      [ordered]@{
        id = "host_full"
        server_limit = "none"
        client_limit = "none"
        purpose = "Best-case host baseline."
      },
      [ordered]@{
        id = "server_8c_32gb"
        server_limit = "WSL processors=8 memory=32GB"
        client_limit = "none"
        purpose = "Healthy dedicated-server envelope."
      },
      [ordered]@{
        id = "server_4c_16gb"
        server_limit = "WSL processors=4 memory=16GB"
        client_limit = "none"
        purpose = "Practical constrained-host envelope."
      },
      [ordered]@{
        id = "server_2c_8gb"
        server_limit = "WSL processors=2 memory=8GB"
        client_limit = "none"
        purpose = "Stress envelope for degradation behavior."
      },
      [ordered]@{
        id = "client_low_priority"
        server_limit = "none"
        client_limit = "Windows process priority/affinity profile"
        purpose = "Client-side headroom sensitivity check."
      }
    )
    notes = @(
      "This packet dry-runs the requested resource envelope by default.",
      "Set FIELDLAB_APPLY_WSL_LIMITS=1 to write WSL CPU/RAM limits through fieldlab/scripts/set-wsl-resource-profile.ps1.",
      "Set FIELDLAB_WSL_SHUTDOWN=1 only when it is acceptable to stop all running WSL distros.",
      "Applying Windows client affinity or priority should be a named run profile, not an implicit background change."
    )
  }
}

function Get-WslResourceProfileState {
  param([object]$ResourceProfile)

  $scriptPath = Join-Path $RepoRoot "fieldlab\scripts\set-wsl-resource-profile.ps1"
  if (-not (Test-Path $scriptPath)) {
    return [ordered]@{
      schema_version = 1
      status = "missing_tool"
      script_path = $scriptPath
      profile = $ResourceProfile.requested_profile
      notes = @("set-wsl-resource-profile.ps1 was not found.")
    }
  }

  $arguments = @{
    Profile = [string]$ResourceProfile.requested_profile
    Json = $true
  }

  if ($ResourceProfile.requested_wsl_memory_gb) {
    $arguments.MemoryGb = [int]$ResourceProfile.requested_wsl_memory_gb
  }

  if ($ResourceProfile.requested_wsl_processors) {
    $arguments.Processors = [int]$ResourceProfile.requested_wsl_processors
  }

  if (Test-EnvFlag "FIELDLAB_APPLY_WSL_LIMITS") {
    $arguments.Apply = $true
  }

  if (Test-EnvFlag "FIELDLAB_WSL_SHUTDOWN") {
    $arguments.ShutdownWsl = $true
  }

  if (Test-EnvFlag "FIELDLAB_CLEAR_WSL_LIMITS") {
    $arguments.ClearLimits = $true
  }

  try {
    $raw = (& $scriptPath @arguments 2>&1 | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($raw)) {
      throw "set-wsl-resource-profile.ps1 returned no output."
    }

    return ($raw | ConvertFrom-Json)
  } catch {
    return [ordered]@{
      schema_version = 1
      status = "error"
      script_path = $scriptPath
      profile = $ResourceProfile.requested_profile
      apply_requested = (Test-EnvFlag "FIELDLAB_APPLY_WSL_LIMITS")
      shutdown_requested = (Test-EnvFlag "FIELDLAB_WSL_SHUTDOWN")
      error = $_.Exception.Message
    }
  }
}

function New-TeleportRouteContract {
  param(
    [object]$DensityMatrix,
    [object]$ResourceProfile
  )

  $fixtures = @()
  if ($DensityMatrix.found -and $DensityMatrix.density_fixtures) {
    $fixtures = @($DensityMatrix.density_fixtures)
  }

  $bandOrder = @{
    open_control = 0
    sparse = 1
    light = 2
    mixed = 3
    dense = 4
    extreme = 5
  }

  $routeSteps = @($fixtures |
    Sort-Object { if ($bandOrder.ContainsKey($_.band)) { $bandOrder[$_.band] } else { 99 } } |
    ForEach-Object -Begin { $index = 0 } -Process {
      $index += 1
      $stepId = "route_{0:00}_{1}" -f $index, $_.band
      [ordered]@{
        step = $index
        id = $stepId
        density_band = $_.band
        world_x = $_.world_x
        world_z = $_.world_z
        build_zdos_500m = $_.build_zdos_500m
        total_zdos_500m = $_.total_zdos_500m
        container_item_rows_500m = $_.container_item_rows_500m
        settle_seconds = 20
        benchmark_seconds = 60
        marker_start = "$stepId start"
        marker_end = "$stepId end"
        operator_actions = @(
          "network_sense_mcp_mark $stepId start",
          "teleport instrumented client to world_x/world_z",
          "wait 20 seconds for stream-in and settlement",
          "network_sense_benchmark",
          "network_sense_mcp_mark $stepId end"
        )
      }
    })

  return [ordered]@{
    schema_version = 1
    status = if ($routeSteps.Count -gt 0) { "pass" } else { "missing_density_fixtures" }
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    purpose = "Move one instrumented rendered client through known Era16 density fixtures for repeatable baseline capture."
    execution_mode = "manual_or_scripted_teleport"
    resource_profile = $ResourceProfile
    route_steps = $routeSteps
    notes = @(
      "The route contract records the resource profile used for the run.",
      "A later executor should translate the teleport action into the available Valheim console/mod command.",
      "Each resource profile should produce a separate run packet so degradation curves remain comparable."
    )
  }
}

function Get-WslInventory {
  $command = Get-Command wsl.exe -ErrorAction SilentlyContinue
  if (-not $command) {
    return [ordered]@{
      available = $false
      distro_count = 0
      raw_status = "wsl.exe not found"
    }
  }

  $raw = (& $command.Source -l -v 2>&1 | Out-String) -replace "`0", ""
  $lines = @($raw -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  $distroLines = @($lines | Where-Object { $_ -notmatch "^\s*NAME\s+STATE\s+VERSION" })

  return [ordered]@{
    available = $true
    distro_count = $distroLines.Count
    raw_status = ($lines -join "`n")
  }
}

function Get-HostInventory {
  $computer = Get-CimInstance Win32_ComputerSystem
  $os = Get-CimInstance Win32_OperatingSystem
  $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
  $gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object {
      [ordered]@{
        name = $_.Name
        adapter_ram_bytes = $_.AdapterRAM
        driver_version = $_.DriverVersion
      }
    })

  return [ordered]@{
    machine = $env:COMPUTERNAME
    user = $env:USERNAME
    manufacturer = $computer.Manufacturer
    model = $computer.Model
    os = $os.Caption
    os_version = $os.Version
    cpu = $cpu.Name
    logical_processors = $cpu.NumberOfLogicalProcessors
    total_memory_gb = [Math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
    gpus = $gpus
  }
}

function Get-ValheimInventory {
  $clientRoot = if ($env:FIELDLAB_VALHEIM_CLIENT_ROOT) {
    $env:FIELDLAB_VALHEIM_CLIENT_ROOT
  } else {
    "C:\Program Files (x86)\Steam\steamapps\common\Valheim"
  }

  $serverRoot = if ($env:FIELDLAB_VALHEIM_SERVER_ROOT) {
    $env:FIELDLAB_VALHEIM_SERVER_ROOT
  } else {
    "C:\Program Files (x86)\Steam\steamapps\common\Valheim dedicated server"
  }

  $processes = @(Get-CimInstance Win32_Process | Where-Object {
      $_.Name -match "^(valheim|valheim_server)\.exe$" -or $_.CommandLine -match "(?i)(\\|/)(valheim|valheim_server)\.exe(\s|$)"
    } | ForEach-Object {
      [ordered]@{
        process_id = $_.ProcessId
        name = $_.Name
        command_line = $_.CommandLine
      }
    })

  $udpPorts = @(Get-NetUDPEndpoint -LocalPort 2456, 2457, 2458 -ErrorAction SilentlyContinue | ForEach-Object {
      [ordered]@{
        local_address = $_.LocalAddress
        local_port = $_.LocalPort
        owning_process = $_.OwningProcess
      }
    })

  return [ordered]@{
    client_root = $clientRoot
    client_root_exists = Test-Path $clientRoot
    server_root = $serverRoot
    server_root_exists = Test-Path $serverRoot
    valheim_processes = $processes
    udp_ports = $udpPorts
  }
}

function Get-FileInventory {
  param([string]$LogDir)

  if (-not (Test-Path $LogDir -PathType Container)) {
    return @()
  }

  $trimChars = [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  $rootFullPath = [System.IO.Path]::GetFullPath($LogDir).TrimEnd($trimChars)
  $rootPrefix = $rootFullPath + [System.IO.Path]::DirectorySeparatorChar

  return @(Get-ChildItem -Path $LogDir -Recurse -File | ForEach-Object {
      $fileFullPath = [System.IO.Path]::GetFullPath($_.FullName)
      $relativePath = if ($fileFullPath.ToLowerInvariant().StartsWith($rootPrefix.ToLowerInvariant())) {
        $fileFullPath.Substring($rootPrefix.Length)
      } else {
        $_.Name
      }

      [ordered]@{
        path = $_.FullName
        relative_path = $relativePath
        length = $_.Length
        last_write_time_utc = $_.LastWriteTimeUtc.ToString("o")
      }
    })
}

function Get-ClientMetrics {
  param([object[]]$Records, [int]$ParseErrors)

  Add-Checkpoint "client_metrics_start"
  $dates = @($Records | ForEach-Object { Convert-TelemetryDate $_.timestamp_utc } | Where-Object { $null -ne $_ } | Sort-Object)
  Add-Checkpoint "client_metrics_dates"
  $first = if ($dates.Count -gt 0) { $dates[0] } else { $null }
  $latest = if ($dates.Count -gt 0) { $dates[$dates.Count - 1] } else { $null }
  $captureMinutes = if ($first -and $latest) { [Math]::Round(($latest - $first).TotalMinutes, 2) } else { 0.0 }

  $sessionSummaries = @($Records |
    Group-Object { if ($_.session_id) { $_.session_id } else { "unknown" } } |
    ForEach-Object {
      $sessionDates = @($_.Group | ForEach-Object { Convert-TelemetryDate $_.timestamp_utc } | Where-Object { $null -ne $_ } | Sort-Object)
      $sessionFirst = if ($sessionDates.Count -gt 0) { $sessionDates[0] } else { $null }
      $sessionLatest = if ($sessionDates.Count -gt 0) { $sessionDates[$sessionDates.Count - 1] } else { $null }
      [ordered]@{
        session_id = $_.Name
        sample_count = $_.Count
        first_sample_utc = if ($sessionFirst) { $sessionFirst.ToString("o") } else { $null }
        latest_sample_utc = if ($sessionLatest) { $sessionLatest.ToString("o") } else { $null }
        duration_minutes = if ($sessionFirst -and $sessionLatest) { [Math]::Round(($sessionLatest - $sessionFirst).TotalMinutes, 2) } else { 0.0 }
      }
    } | Sort-Object duration_minutes -Descending)
  Add-Checkpoint "client_metrics_sessions"

  $longestSessionMinutes = if ($sessionSummaries.Count -gt 0) { [double]$sessionSummaries[0].duration_minutes } else { 0.0 }
  $latestAgeMinutes = if ($latest) { [Math]::Round(((Get-Date).ToUniversalTime() - $latest).TotalMinutes, 2) } else { $null }
  Add-Checkpoint "client_metrics_time_windows"

  $fpsStats = Get-NumberStats -Values @($Records | ForEach-Object { $_.fps })
  Add-Checkpoint "client_metrics_fps"
  $frameTimeStats = Get-NumberStats -Values @($Records | ForEach-Object { $_.frame_time_ms })
  Add-Checkpoint "client_metrics_frame_time"
  $frameTimeP95Stats = Get-NumberStats -Values @($Records | ForEach-Object { $_.frame_time_p95_ms })
  Add-Checkpoint "client_metrics_frame_time_p95"
  $rttStats = Get-NumberStats -Values @($Records | ForEach-Object { $_.rtt_ms })
  Add-Checkpoint "client_metrics_rtt"
  $jitterStats = Get-NumberStats -Values @($Records | ForEach-Object { $_.jitter_ms })
  Add-Checkpoint "client_metrics_jitter"
  $bytesInStats = Get-NumberStats -Values @($Records | ForEach-Object { $_.bytes_in_per_sec })
  $bytesOutStats = Get-NumberStats -Values @($Records | ForEach-Object { $_.bytes_out_per_sec })
  $packetsInStats = Get-NumberStats -Values @($Records | ForEach-Object { $_.packets_in_per_sec })
  $packetsOutStats = Get-NumberStats -Values @($Records | ForEach-Object { $_.packets_out_per_sec })
  Add-Checkpoint "client_metrics_traffic"

  return [ordered]@{
    sample_count = $Records.Count
    parse_error_count = $ParseErrors
    session_count = $sessionSummaries.Count
    first_sample_utc = if ($first) { $first.ToString("o") } else { $null }
    latest_sample_utc = if ($latest) { $latest.ToString("o") } else { $null }
    latest_sample_age_minutes = $latestAgeMinutes
    capture_window_minutes = $captureMinutes
    longest_session_minutes = $longestSessionMinutes
    sessions = @($sessionSummaries | Select-Object -First 10)
    fps = $fpsStats
    frame_time_ms = $frameTimeStats
    frame_time_p95_ms = $frameTimeP95Stats
    rtt_ms = $rttStats
    jitter_ms = $jitterStats
    bytes_in_per_sec = $bytesInStats
    bytes_out_per_sec = $bytesOutStats
    packets_in_per_sec = $packetsInStats
    packets_out_per_sec = $packetsOutStats
    max_nearby_players = (@($Records | ForEach-Object { $_.nearby_players }) | Measure-Object -Maximum).Maximum
    max_nearby_entities = (@($Records | ForEach-Object { $_.nearby_entities }) | Measure-Object -Maximum).Maximum
    max_nearby_build_pieces = (@($Records | ForEach-Object { $_.nearby_build_pieces }) | Measure-Object -Maximum).Maximum
    danger_sample_count = @($Records | Where-Object { $_.danger_nearby -eq $true }).Count
    region_count = @($Records | Where-Object { $_.region_id } | Select-Object -ExpandProperty region_id -Unique).Count
  }
}

function Get-ServerMetrics {
  param([object[]]$Records, [int]$ParseErrors)

  return [ordered]@{
    pulse_count = $Records.Count
    parse_error_count = $ParseErrors
    heartbeat_gap_ms = Get-NumberStats -Values @($Records | ForEach-Object { $_.heartbeat_gap_ms })
    messages_sent_per_sec = Get-NumberStats -Values @($Records | ForEach-Object { $_.messages_sent_per_sec })
    bytes_sent_per_sec = Get-NumberStats -Values @($Records | ForEach-Object { $_.bytes_sent_per_sec })
    region_pressure_score = Get-NumberStats -Values @($Records | ForEach-Object { $_.region_pressure_score })
    max_region_observers = (@($Records | ForEach-Object { $_.region_observer_count }) | Measure-Object -Maximum).Maximum
    max_region_players = (@($Records | ForEach-Object { $_.region_player_count }) | Measure-Object -Maximum).Maximum
    max_region_entities = (@($Records | ForEach-Object { $_.region_entity_count }) | Measure-Object -Maximum).Maximum
    max_region_builds = (@($Records | ForEach-Object { $_.region_build_count }) | Measure-Object -Maximum).Maximum
  }
}

function Get-BenchmarkMetrics {
  param([object[]]$Records, [int]$ParseErrors)

  $latestRecord = $null
  if ($Records.Count -gt 0) {
    $latestRecord = $Records |
      Sort-Object { Convert-TelemetryDate $_.timestamp_utc } |
      Select-Object -Last 1
  }

  return [ordered]@{
    benchmark_count = $Records.Count
    parse_error_count = $ParseErrors
    latest_timestamp_utc = if ($latestRecord) { $latestRecord.timestamp_utc } else { $null }
    latest_headroom_tier = if ($latestRecord) { $latestRecord.recommended_headroom_tier } else { $null }
    tier_counts = @($Records | Group-Object recommended_headroom_tier | ForEach-Object {
        [ordered]@{
          tier = $_.Name
          count = $_.Count
        }
      })
    avg_fps = Get-NumberStats -Values @($Records | ForEach-Object { $_.avg_fps })
    p95_frame_time_ms = Get-NumberStats -Values @($Records | ForEach-Object { $_.p95_frame_time_ms })
    cpu_bound_estimate = Get-NumberStats -Values @($Records | ForEach-Object { $_.cpu_bound_estimate })
  }
}

function Get-EventMetrics {
  param([object[]]$Records, [int]$ParseErrors)

  return [ordered]@{
    event_count = $Records.Count
    parse_error_count = $ParseErrors
    event_counts = @($Records | Group-Object event_name | Sort-Object Count -Descending | ForEach-Object {
        [ordered]@{
          event_name = $_.Name
          count = $_.Count
        }
      })
    marker_count = @($Records | Where-Object { $_.event_name -eq "dev_marker" }).Count
    benchmark_start_count = @($Records | Where-Object { $_.event_name -eq "benchmark_start" }).Count
    benchmark_end_count = @($Records | Where-Object { $_.event_name -eq "benchmark_end" }).Count
  }
}

$logDir = Resolve-NetworkSenseLogDir
$clientPath = Join-Path $logDir "telemetry-client.jsonl"
$serverPath = Join-Path $logDir "telemetry-server.jsonl"
$benchmarkPath = Join-Path $logDir "benchmark-results.jsonl"
$eventPath = Join-Path $logDir "event-timeline.jsonl"
Add-Checkpoint "paths_resolved"

$hostInventory = Get-HostInventory
Add-Checkpoint "host_inventory"
$wslInventory = Get-WslInventory
Add-Checkpoint "wsl_inventory"
$valheimInventory = Get-ValheimInventory
Add-Checkpoint "valheim_inventory"
$fileInventory = Get-FileInventory -LogDir $logDir
Add-Checkpoint "file_inventory"
$densityMatrix = Get-LatestDensityMatrixSummary -Root $RepoRoot
Add-Checkpoint "density_matrix"
$resourceProfile = Get-ResourceProfileContract -HostInventory $hostInventory
Add-Checkpoint "resource_profile"
$wslResourceProfile = Get-WslResourceProfileState -ResourceProfile $resourceProfile
Add-Checkpoint "wsl_resource_profile"
$resourceProfile["applied_by_this_packet"] = [bool]$wslResourceProfile.applied
$teleportRouteContract = New-TeleportRouteContract -DensityMatrix $densityMatrix -ResourceProfile $resourceProfile
Add-Checkpoint "teleport_route_contract"

$clientLog = Read-JsonLines -Path $clientPath
Add-Checkpoint "client_log_read"
$serverLog = Read-JsonLines -Path $serverPath
Add-Checkpoint "server_log_read"
$benchmarkLog = Read-JsonLines -Path $benchmarkPath
Add-Checkpoint "benchmark_log_read"
$eventLog = Read-JsonLines -Path $eventPath
Add-Checkpoint "event_log_read"

$clientRecords = @($clientLog["records"].ToArray())
$serverRecords = @($serverLog["records"].ToArray())
$benchmarkRecords = @($benchmarkLog["records"].ToArray())
$eventRecords = @($eventLog["records"].ToArray())
Add-Checkpoint "records_materialized"

$clientMetrics = Get-ClientMetrics -Records $clientRecords -ParseErrors ([int]$clientLog["parse_errors"])
Add-Checkpoint "client_metrics"
$serverMetrics = Get-ServerMetrics -Records $serverRecords -ParseErrors ([int]$serverLog["parse_errors"])
Add-Checkpoint "server_metrics"
$benchmarkMetrics = Get-BenchmarkMetrics -Records $benchmarkRecords -ParseErrors ([int]$benchmarkLog["parse_errors"])
Add-Checkpoint "benchmark_metrics"
$eventMetrics = Get-EventMetrics -Records $eventRecords -ParseErrors ([int]$eventLog["parse_errors"])
Add-Checkpoint "event_metrics"

$gates = New-Object System.Collections.Generic.List[object]
Add-Checkpoint "gates_start"

$logDirStatus = if (Test-Path $logDir -PathType Container) { "pass" } else { "fail" }
$gates.Add((New-Gate -Id "networksense_log_dir" -Status $logDirStatus -Requirement "NetworkSense log directory exists." -Observed $logDir)) | Out-Null

$clientSampleStatus = if ($clientMetrics.sample_count -ge 600) { "pass" } elseif ($clientMetrics.sample_count -gt 0) { "warn" } else { "fail" }
$gates.Add((New-Gate -Id "client_telemetry" -Status $clientSampleStatus -Requirement "At least 600 client telemetry samples are available." -Observed "$($clientMetrics.sample_count) samples, $($clientMetrics.parse_error_count) parse errors.")) | Out-Null

$freshnessStatus = if ($null -eq $clientMetrics.latest_sample_age_minutes) {
  "fail"
} elseif ($clientMetrics.latest_sample_age_minutes -le 1440) {
  "pass"
} elseif ($clientMetrics.latest_sample_age_minutes -le 10080) {
  "warn"
} else {
  "fail"
}
$gates.Add((New-Gate -Id "telemetry_freshness" -Status $freshnessStatus -Requirement "Latest client sample is less than 24 hours old." -Observed "Latest sample age: $($clientMetrics.latest_sample_age_minutes) minutes.")) | Out-Null

$windowStatus = if ($clientMetrics.longest_session_minutes -ge 30) {
  "pass"
} elseif ($clientMetrics.longest_session_minutes -ge 10) {
  "warn"
} else {
  "fail"
}
$gates.Add((New-Gate -Id "continuous_client_window" -Status $windowStatus -Requirement "At least one continuous 30 minute client telemetry window exists." -Observed "Longest session: $($clientMetrics.longest_session_minutes) minutes.")) | Out-Null

$benchmarkStatus = if ($benchmarkMetrics.benchmark_count -ge 1) { "pass" } else { "fail" }
$gates.Add((New-Gate -Id "benchmark_capture" -Status $benchmarkStatus -Requirement "At least one NetworkSense benchmark was captured." -Observed "$($benchmarkMetrics.benchmark_count) benchmark results.")) | Out-Null

$densityStatus = if ($densityMatrix.found -and $densityMatrix.status -eq "pass") { "pass" } elseif ($densityMatrix.found) { "warn" } else { "fail" }
$gates.Add((New-Gate -Id "density_matrix" -Status $densityStatus -Requirement "Latest Era16 density pressure matrix exists and passed." -Observed "found=$($densityMatrix.found), status=$($densityMatrix.status), run=$($densityMatrix.run_id)")) | Out-Null

$routeStatus = if ($teleportRouteContract.status -eq "pass") { "pass" } else { "fail" }
$gates.Add((New-Gate -Id "teleport_route_contract" -Status $routeStatus -Requirement "Teleport route contract can be generated from density fixtures." -Observed "status=$($teleportRouteContract.status), steps=$(@($teleportRouteContract.route_steps).Count), resource_profile=$($resourceProfile.requested_profile).")) | Out-Null

$wslStatus = if ($wslInventory.available -and $wslInventory.distro_count -gt 0) { "pass" } elseif ($wslInventory.available) { "warn" } else { "fail" }
$gates.Add((New-Gate -Id "wsl_available" -Status $wslStatus -Requirement "WSL is installed and has at least one distro." -Observed "available=$($wslInventory.available), distro_count=$($wslInventory.distro_count).")) | Out-Null

$wslProfileStatus = if ($wslResourceProfile.status -in @("apply_failed", "shutdown_failed", "error", "missing_tool", "unknown_profile")) {
  "warn"
} elseif ($wslResourceProfile.status -in @("dry_run_change_pending", "applied_restart_pending")) {
  "warn"
} elseif ($wslResourceProfile.matches_requested -or $wslResourceProfile.target_kind -eq "none") {
  "pass"
} else {
  "warn"
}
$gates.Add((New-Gate -Id "wsl_resource_profile" -Status $wslProfileStatus -Requirement "Requested WSL resource profile is observed, explicitly pending, or explicitly applied." -Observed "status=$($wslResourceProfile.status), profile=$($wslResourceProfile.profile), target_memory=$($wslResourceProfile.target_memory_value), target_processors=$($wslResourceProfile.target_processors_value), apply_requested=$($wslResourceProfile.apply_requested), shutdown_requested=$($wslResourceProfile.shutdown_requested).")) | Out-Null

$serverPulseStatus = if ($serverMetrics.pulse_count -ge 60) { "pass" } elseif ($serverMetrics.pulse_count -gt 0) { "warn" } else { "warn" }
$gates.Add((New-Gate -Id "server_pulse_capture" -Status $serverPulseStatus -Requirement "Server pulse telemetry is present for host/server visibility." -Observed "$($serverMetrics.pulse_count) server pulse samples.")) | Out-Null

$serverProcessStatus = if (@($valheimInventory.valheim_processes).Count -gt 0 -or @($valheimInventory.udp_ports).Count -gt 0) { "pass" } else { "warn" }
$gates.Add((New-Gate -Id "live_server_visibility" -Status $serverProcessStatus -Requirement "A live Valheim/server process or UDP listener is visible during a rehearsal run." -Observed "$(@($valheimInventory.valheim_processes).Count) Valheim processes, $(@($valheimInventory.udp_ports).Count) Valheim UDP listeners.")) | Out-Null

$frameP95 = $clientMetrics.frame_time_p95_ms.p95
$frameStatus = if ($null -eq $frameP95) {
  "fail"
} elseif ($frameP95 -le 33.3) {
  "pass"
} elseif ($frameP95 -le 50.0) {
  "warn"
} else {
  "fail"
}
$gates.Add((New-Gate -Id "client_headroom" -Status $frameStatus -Requirement "Client frame-time p95 baseline is at or below 33.3 ms, warning up to 50 ms." -Observed "frame_time_p95_ms.p95=$frameP95.")) | Out-Null

$rttP95 = $clientMetrics.rtt_ms.p95
$jitterP95 = $clientMetrics.jitter_ms.p95
$networkStatus = if ($null -eq $rttP95 -or $null -eq $jitterP95) {
  "fail"
} elseif ($rttP95 -le 150 -and $jitterP95 -le 50) {
  "pass"
} elseif ($rttP95 -le 250 -and $jitterP95 -le 100) {
  "warn"
} else {
  "fail"
}
$gates.Add((New-Gate -Id "network_stability" -Status $networkStatus -Requirement "Local baseline RTT p95 <= 150 ms and jitter p95 <= 50 ms." -Observed "rtt_ms.p95=$rttP95, jitter_ms.p95=$jitterP95.")) | Out-Null

$failCount = @($gates | Where-Object { $_.status -eq "fail" }).Count
$warnCount = @($gates | Where-Object { $_.status -eq "warn" }).Count

$status = if (-not (Test-Path $logDir -PathType Container) -or $clientMetrics.sample_count -eq 0) {
  "blocked_missing_networksense_telemetry"
} elseif ($failCount -gt 0) {
  "baseline_incomplete"
} elseif ($warnCount -gt 0) {
  "baseline_ready_with_warnings"
} else {
  "pass"
}

$metrics = [ordered]@{
  schema_version = 1
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  log_dir = $logDir
  client = $clientMetrics
  server = $serverMetrics
  benchmark = $benchmarkMetrics
  events = $eventMetrics
  density_matrix = $densityMatrix
  resource_profile = $resourceProfile
  wsl_resource_profile = $wslResourceProfile
  teleport_route = [ordered]@{
    status = $teleportRouteContract.status
    step_count = @($teleportRouteContract.route_steps).Count
    path = "telemetry/teleport-route-contract.json"
  }
}

$summary = [ordered]@{
  schema_version = 1
  status = $status
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  log_dir = $logDir
  readiness = [ordered]@{
    ready_to_invite_volunteers = ($status -eq "pass")
    ready_for_internal_rehearsal = ($failCount -eq 0)
    fail_count = $failCount
    warn_count = $warnCount
    gates = $gates
  }
  headline_metrics = [ordered]@{
    client_samples = $clientMetrics.sample_count
    longest_session_minutes = $clientMetrics.longest_session_minutes
    latest_sample_age_minutes = $clientMetrics.latest_sample_age_minutes
    fps_avg = $clientMetrics.fps.avg
    frame_time_p95_ms = $clientMetrics.frame_time_p95_ms.p95
    rtt_p95_ms = $clientMetrics.rtt_ms.p95
    jitter_p95_ms = $clientMetrics.jitter_ms.p95
    max_nearby_players = $clientMetrics.max_nearby_players
    max_nearby_entities = $clientMetrics.max_nearby_entities
    max_nearby_build_pieces = $clientMetrics.max_nearby_build_pieces
    benchmark_count = $benchmarkMetrics.benchmark_count
    latest_benchmark_tier = $benchmarkMetrics.latest_headroom_tier
    server_pulse_count = $serverMetrics.pulse_count
    density_matrix_run = $densityMatrix.run_id
    density_matrix_rows = $densityMatrix.matrix_row_count
    teleport_route_steps = @($teleportRouteContract.route_steps).Count
    resource_profile = $resourceProfile.requested_profile
    wsl_resource_profile_status = $wslResourceProfile.status
  }
  outputs = [ordered]@{
    summary = "telemetry/volunteer-readiness-summary.json"
    metrics = "telemetry/baseline-metrics.json"
    teleport_route_contract = "telemetry/teleport-route-contract.json"
    setup_inventory = "raw/setup-inventory.json"
  }
}

$inventory = [ordered]@{
  schema_version = 1
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  host = $hostInventory
  wsl = $wslInventory
  valheim = $valheimInventory
  resource_profile = $resourceProfile
  wsl_resource_profile = $wslResourceProfile
  network_sense_log_files = $fileInventory
}

Write-JsonFile -Value $metrics -Path $metricsPath
Write-JsonFile -Value $summary -Path $summaryPath
Write-JsonFile -Value $teleportRouteContract -Path $routeContractPath
Write-JsonFile -Value $inventory -Path $inventoryPath

@(
  "# Valheim Era16 Volunteer Readiness Baseline",
  "",
  "Status: $status",
  "",
  "Ready to invite volunteers: $($summary.readiness.ready_to_invite_volunteers)",
  "Ready for internal rehearsal: $($summary.readiness.ready_for_internal_rehearsal)",
  "",
  "Headline metrics:",
  "",
  "- Client samples: $($summary.headline_metrics.client_samples)",
  "- Longest session minutes: $($summary.headline_metrics.longest_session_minutes)",
  "- Latest sample age minutes: $($summary.headline_metrics.latest_sample_age_minutes)",
  "- FPS avg: $($summary.headline_metrics.fps_avg)",
  "- Frame p95 ms: $($summary.headline_metrics.frame_time_p95_ms)",
  "- RTT p95 ms: $($summary.headline_metrics.rtt_p95_ms)",
  "- Jitter p95 ms: $($summary.headline_metrics.jitter_p95_ms)",
  "- Benchmarks: $($summary.headline_metrics.benchmark_count)",
  "- Server pulses: $($summary.headline_metrics.server_pulse_count)",
  "- Teleport route steps: $($summary.headline_metrics.teleport_route_steps)",
  "- Resource profile: $($summary.headline_metrics.resource_profile)",
  "- WSL resource profile status: $($summary.headline_metrics.wsl_resource_profile_status)",
  "",
  "Artifacts:",
  "",
  "- ``telemetry/volunteer-readiness-summary.json``",
  "- ``telemetry/baseline-metrics.json``",
  "- ``telemetry/teleport-route-contract.json``",
  "- ``raw/setup-inventory.json``"
) | Set-Content -Encoding UTF8 $commandSummaryPath

exit 0
