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

$summaryPath = Join-Path $telemetryDir "matrix-summary.json"
$fixturesPath = Join-Path $telemetryDir "era16-density-fixtures.json"
$matrixCsvPath = Join-Path $telemetryDir "era16-pressure-matrix.csv"
$commandSummaryPath = Join-Path $rawDir "command-plan-summary.md"

function Write-JsonFile {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Value,

    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $Value | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $Path
}

function Write-BlockedSummary {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Status,

    [Parameter(Mandatory = $true)]
    [string]$Message,

    [int]$ExitCode = 0
  )

  $summary = [ordered]@{
    schema_version = 1
    status = $Status
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    cache_path = $cachePath
    matrix_row_count = 0
    density_fixture_count = 0
    message = $Message
    outputs = [ordered]@{
      fixtures = "telemetry/era16-density-fixtures.json"
      matrix_csv = "telemetry/era16-pressure-matrix.csv"
      summary = "telemetry/matrix-summary.json"
    }
  }

  Write-JsonFile -Value $summary -Path $summaryPath
  @(
    "# Era16 Density Pressure Matrix",
    "",
    "Status: $Status",
    "",
    $Message
  ) | Set-Content -Encoding UTF8 $commandSummaryPath
  exit $ExitCode
}

function Resolve-JavaTool {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ToolName
  )

  $candidateHomes = @()
  if ($env:FIELDLAB_JAVA_HOME) {
    $candidateHomes += $env:FIELDLAB_JAVA_HOME
  }
  if ($env:JAVA_HOME) {
    $candidateHomes += $env:JAVA_HOME
  }
  $candidateHomes += "C:\work\ComfyStewardView\.tools\jdk-17.0.19+10"

  foreach ($candidateHome in $candidateHomes) {
    if (-not $candidateHome) {
      continue
    }

    $candidate = Join-Path $candidateHome "bin\$ToolName.exe"
    if (Test-Path $candidate) {
      return (Resolve-Path $candidate).Path
    }
  }

  $command = Get-Command $ToolName -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  return $null
}

$cachePath = if ($env:FIELDLAB_ERA16_DUCKDB) {
  $env:FIELDLAB_ERA16_DUCKDB
} else {
  "C:\work\ComfyStewardView\viewer\target\ComfyEra16.duckdb"
}

$duckDbJar = if ($env:FIELDLAB_DUCKDB_JDBC_JAR) {
  $env:FIELDLAB_DUCKDB_JDBC_JAR
} else {
  "C:\work\ComfyStewardView\viewer\lib\duckdb_jdbc-1.5.4.0.jar"
}

$javaExe = Resolve-JavaTool -ToolName "java"
$javacExe = Resolve-JavaTool -ToolName "javac"

if (-not (Test-Path $cachePath)) {
  Write-BlockedSummary -Status "blocked_missing_cache" -Message "Era16 DuckDB cache was not found at $cachePath."
}

if (-not (Test-Path $duckDbJar)) {
  Write-BlockedSummary -Status "blocked_missing_duckdb_jdbc" -Message "DuckDB JDBC jar was not found at $duckDbJar."
}

if (-not $javaExe) {
  Write-BlockedSummary -Status "blocked_missing_java" -Message "java.exe was not found. Set FIELDLAB_JAVA_HOME or JAVA_HOME."
}

if (-not $javacExe) {
  Write-BlockedSummary -Status "blocked_missing_javac" -Message "javac.exe was not found. Set FIELDLAB_JAVA_HOME or JAVA_HOME."
}

$javaSourcePath = Join-Path $rawDir "Era16PressureMatrixGenerator.java"
$compileOutPath = Join-Path $rawDir "era16-pressure-matrix-compile.out.log"
$compileErrPath = Join-Path $rawDir "era16-pressure-matrix-compile.err.log"
$generatorOutPath = Join-Path $rawDir "era16-pressure-matrix-generator.out.log"
$generatorErrPath = Join-Path $rawDir "era16-pressure-matrix-generator.err.log"

$javaSource = @'
import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public final class Era16PressureMatrixGenerator {
  private static final int DENSITY_CELL_SIZE = 500;

  private static final class DensityCell {
    String band;
    String label;
    int cx;
    int cz;
    int cellSize;
    double worldX;
    double worldZ;
    double minX;
    double maxX;
    double minZ;
    double maxZ;
    long buildZdos;
    long totalZdos;
    long containerRows;
    long creatorCount;
    long portalCount;
    long signCount;
    Map<String, Long> topItems = new LinkedHashMap<>();
    Map<String, Long> topPrefabs = new LinkedHashMap<>();
    Map<String, Long> topCreators = new LinkedHashMap<>();
  }

  private static final class ObserverRange {
    final String name;
    final int distanceMeters;
    final String interestBucket;
    final double maxUpdateHz;

    ObserverRange(String name, int distanceMeters, String interestBucket, double maxUpdateHz) {
      this.name = name;
      this.distanceMeters = distanceMeters;
      this.interestBucket = interestBucket;
      this.maxUpdateHz = maxUpdateHz;
    }
  }

  private static final class EventProfile {
    final String name;
    final double movementHz;
    final double reliableHz;
    final double lowPriorityHz;

    EventProfile(String name, double movementHz, double reliableHz, double lowPriorityHz) {
      this.name = name;
      this.movementHz = movementHz;
      this.reliableHz = reliableHz;
      this.lowPriorityHz = lowPriorityHz;
    }
  }

  public static void main(String[] args) throws Exception {
    if (args.length != 4) {
      throw new IllegalArgumentException("Usage: Era16PressureMatrixGenerator <duckdb> <fixtures.json> <matrix.csv> <summary.json>");
    }

    Path cachePath = Path.of(args[0]);
    Path fixturesPath = Path.of(args[1]);
    Path matrixPath = Path.of(args[2]);
    Path summaryPath = Path.of(args[3]);
    String cacheForJdbc = cachePath.toAbsolutePath().toString().replace('\\', '/');

    try (Connection conn = DriverManager.getConnection("jdbc:duckdb:" + cacheForJdbc)) {
      long snapshotId = queryLong(conn, "SELECT COALESCE(MAX(snapshot_id), 1) FROM world_snapshot");
      Map<String, Long> tableCounts = tableCounts(conn);
      Map<String, Long> categoryCounts = categoryCounts(conn, snapshotId);
      List<String> notes = new ArrayList<>();
      List<DensityCell> densityCells = selectDensityCells(conn, snapshotId, notes);

      long realFixtureCount = densityCells.stream().filter(c -> !"open_control".equals(c.band)).count();
      if (realFixtureCount == 0) {
        writeFailure(summaryPath, cachePath, "fail_no_density_fixtures", "No real 500m build-density cells were selected from render_cell.");
        System.exit(2);
      }

      int[] actorPlayers = new int[] { 1, 5, 25, 50, 100 };
      int[] rttMs = new int[] { 0, 50, 100, 200 };
      int[] processMs = new int[] { 2, 8, 16, 33, 55 };
      ObserverRange[] ranges = new ObserverRange[] {
        new ObserverRange("self", 0, "near_20hz", 20.0),
        new ObserverRange("near", 50, "near_20hz", 20.0),
        new ObserverRange("mid", 200, "mid_5hz", 5.0),
        new ObserverRange("far", 500, "far_suppressed", 0.0)
      };
      EventProfile[] profiles = new EventProfile[] {
        new EventProfile("movement_only", 20.0, 0.05, 0.2),
        new EventProfile("build_social", 10.0, 1.2, 8.0),
        new EventProfile("combat_build", 20.0, 3.0, 12.0),
        new EventProfile("event_surge", 20.0, 4.0, 20.0)
      };

      writeFixtures(fixturesPath, cachePath, snapshotId, tableCounts, categoryCounts, densityCells, notes);
      int rowCount = writeMatrix(matrixPath, densityCells, actorPlayers, ranges, rttMs, processMs, profiles);
      writeSummary(summaryPath, cachePath, snapshotId, tableCounts, categoryCounts, densityCells, actorPlayers, ranges, rttMs, processMs, profiles, rowCount, notes);
    }
  }

  private static List<DensityCell> selectDensityCells(Connection conn, long snapshotId, List<String> notes) throws SQLException {
    List<DensityCell> cells = new ArrayList<>();

    DensityCell open = new DensityCell();
    open.band = "open_control";
    open.label = "synthetic open control";
    open.cx = 0;
    open.cz = 0;
    open.cellSize = DENSITY_CELL_SIZE;
    open.worldX = 0.0;
    open.worldZ = 0.0;
    open.minX = -250.0;
    open.maxX = 250.0;
    open.minZ = -250.0;
    open.maxZ = 250.0;
    cells.add(open);

    addSelected(cells, selectCell(conn, snapshotId, "sparse", "sparse real 500m cell", "count_value BETWEEN 1 AND 250", "count_value ASC"), notes);
    addSelected(cells, selectCell(conn, snapshotId, "light", "light real 500m cell", "count_value BETWEEN 500 AND 2500", "ABS(count_value - 1500) ASC"), notes);
    addSelected(cells, selectCell(conn, snapshotId, "mixed", "mixed real 500m cell", "count_value BETWEEN 5000 AND 10000", "ABS(count_value - 7500) ASC"), notes);
    addSelected(cells, selectCell(conn, snapshotId, "dense", "dense real 500m cell", "count_value BETWEEN 10000 AND 18000", "ABS(count_value - 14000) ASC"), notes);
    addSelected(cells, selectCell(conn, snapshotId, "extreme", "extreme real 500m cell", "count_value >= 18000", "count_value DESC"), notes);

    for (DensityCell cell : cells) {
      if (!"open_control".equals(cell.band)) {
        enrichCell(conn, snapshotId, cell);
      }
    }

    return cells;
  }

  private static void addSelected(List<DensityCell> cells, DensityCell cell, List<String> notes) {
    if (cell == null) {
      notes.add("A requested density band could not be selected from render_cell.");
    } else {
      cells.add(cell);
    }
  }

  private static DensityCell selectCell(Connection conn, long snapshotId, String band, String label, String whereClause, String orderBy) throws SQLException {
    String sql = "SELECT cx, cz, cell_size, count_value FROM render_cell " +
      "WHERE snapshot_id = ? AND layer = 'build-density' AND cell_size = 500 AND " + whereClause +
      " ORDER BY " + orderBy + " LIMIT 1";

    try (PreparedStatement ps = conn.prepareStatement(sql)) {
      ps.setLong(1, snapshotId);
      try (ResultSet rs = ps.executeQuery()) {
        if (!rs.next()) {
          return null;
        }

        DensityCell cell = new DensityCell();
        cell.band = band;
        cell.label = label;
        cell.cx = rs.getInt("cx");
        cell.cz = rs.getInt("cz");
        cell.cellSize = rs.getInt("cell_size");
        cell.buildZdos = rs.getLong("count_value");
        cell.minX = cell.cx * (double) cell.cellSize;
        cell.maxX = cell.minX + cell.cellSize;
        cell.minZ = cell.cz * (double) cell.cellSize;
        cell.maxZ = cell.minZ + cell.cellSize;
        cell.worldX = cell.minX + (cell.cellSize / 2.0);
        cell.worldZ = cell.minZ + (cell.cellSize / 2.0);
        return cell;
      }
    }
  }

  private static void enrichCell(Connection conn, long snapshotId, DensityCell cell) throws SQLException {
    cell.totalZdos = queryLong(conn,
      "SELECT COUNT(*) FROM zdo WHERE snapshot_id = ? AND x >= ? AND x < ? AND z >= ? AND z < ?",
      snapshotId, cell.minX, cell.maxX, cell.minZ, cell.maxZ);
    cell.containerRows = queryLong(conn,
      "SELECT COUNT(*) FROM container_item WHERE snapshot_id = ? AND container_x >= ? AND container_x < ? AND container_z >= ? AND container_z < ?",
      snapshotId, cell.minX, cell.maxX, cell.minZ, cell.maxZ);
    cell.creatorCount = queryLong(conn,
      "SELECT COUNT(DISTINCT creator_id) FROM zdo WHERE snapshot_id = ? AND creator_id IS NOT NULL AND creator_id <> 0 AND x >= ? AND x < ? AND z >= ? AND z < ?",
      snapshotId, cell.minX, cell.maxX, cell.minZ, cell.maxZ);
    cell.portalCount = queryLong(conn,
      "SELECT COUNT(*) FROM zdo WHERE snapshot_id = ? AND category = 'PORTAL' AND x >= ? AND x < ? AND z >= ? AND z < ?",
      snapshotId, cell.minX, cell.maxX, cell.minZ, cell.maxZ);
    cell.signCount = queryLong(conn,
      "SELECT COUNT(*) FROM zdo WHERE snapshot_id = ? AND category = 'SIGN' AND x >= ? AND x < ? AND z >= ? AND z < ?",
      snapshotId, cell.minX, cell.maxX, cell.minZ, cell.maxZ);
    cell.topItems = topStringLong(conn,
      "SELECT item_name AS k, CAST(SUM(stack) AS BIGINT) AS v FROM container_item " +
      "WHERE snapshot_id = ? AND container_x >= ? AND container_x < ? AND container_z >= ? AND container_z < ? " +
      "GROUP BY item_name ORDER BY v DESC LIMIT 5",
      snapshotId, cell.minX, cell.maxX, cell.minZ, cell.maxZ);
    cell.topPrefabs = topStringLong(conn,
      "SELECT COALESCE(prefab_name, 'hash:' || CAST(prefab_hash AS VARCHAR)) AS k, COUNT(*) AS v FROM zdo " +
      "WHERE snapshot_id = ? AND x >= ? AND x < ? AND z >= ? AND z < ? " +
      "GROUP BY k ORDER BY v DESC LIMIT 5",
      snapshotId, cell.minX, cell.maxX, cell.minZ, cell.maxZ);
    cell.topCreators = topStringLong(conn,
      "SELECT CAST(creator_id AS VARCHAR) AS k, COUNT(*) AS v FROM zdo " +
      "WHERE snapshot_id = ? AND creator_id IS NOT NULL AND creator_id <> 0 AND x >= ? AND x < ? AND z >= ? AND z < ? " +
      "GROUP BY creator_id ORDER BY v DESC LIMIT 5",
      snapshotId, cell.minX, cell.maxX, cell.minZ, cell.maxZ);
  }

  private static int writeMatrix(Path matrixPath, List<DensityCell> cells, int[] actorPlayers, ObserverRange[] ranges, int[] rttMs, int[] processMs, EventProfile[] profiles) throws IOException {
    int rowCount = 0;

    try (BufferedWriter writer = Files.newBufferedWriter(matrixPath, StandardCharsets.UTF_8)) {
      writer.write(String.join(",",
        "density_band",
        "density_label",
        "world_x",
        "world_z",
        "build_zdos_500m",
        "total_zdos_500m",
        "container_item_rows_500m",
        "creator_count_500m",
        "actor_players",
        "observer_range",
        "observer_distance_m",
        "interest_bucket",
        "rtt_ms",
        "server_process_ms",
        "process_budget",
        "event_profile",
        "modeled_movement_events_per_sec",
        "modeled_reliable_events_per_sec",
        "modeled_low_priority_events_per_sec",
        "estimated_datagram_updates_per_sec",
        "estimated_udp_kbps",
        "priority_expectation"));
      writer.newLine();

      for (DensityCell cell : cells) {
        double densityMultiplier = densityMultiplier(cell);
        for (int players : actorPlayers) {
          for (ObserverRange range : ranges) {
            for (int rtt : rttMs) {
              for (int process : processMs) {
                for (EventProfile profile : profiles) {
                  double movementEvents = players * profile.movementHz;
                  double reliableEvents = players * profile.reliableHz;
                  double lowPriorityEvents = players * profile.lowPriorityHz * densityMultiplier;
                  double datagramUpdates = players * Math.min(profile.movementHz, range.maxUpdateHz);
                  double udpKbps = datagramUpdates * 96.0 * 8.0 / 1000.0;
                  String processBudget = processBudget(process);
                  String expectation = priorityExpectation(range, process, rtt, profile);

                  writer.write(String.join(",",
                    csv(cell.band),
                    csv(cell.label),
                    number(cell.worldX),
                    number(cell.worldZ),
                    Long.toString(cell.buildZdos),
                    Long.toString(cell.totalZdos),
                    Long.toString(cell.containerRows),
                    Long.toString(cell.creatorCount),
                    Integer.toString(players),
                    csv(range.name),
                    Integer.toString(range.distanceMeters),
                    csv(range.interestBucket),
                    Integer.toString(rtt),
                    Integer.toString(process),
                    csv(processBudget),
                    csv(profile.name),
                    number(movementEvents),
                    number(reliableEvents),
                    number(lowPriorityEvents),
                    number(datagramUpdates),
                    number(udpKbps),
                    csv(expectation)));
                  writer.newLine();
                  rowCount++;
                }
              }
            }
          }
        }
      }
    }

    return rowCount;
  }

  private static double densityMultiplier(DensityCell cell) {
    if (cell.totalZdos <= 0) {
      return 0.5;
    }

    double raw = 1.0 + Math.max(0.0, Math.log10(cell.totalZdos) - 2.0);
    return Math.min(5.0, raw);
  }

  private static String processBudget(int processMs) {
    if (processMs <= 16) {
      return "green_under_tick";
    }
    if (processMs <= 33) {
      return "yellow_near_tick";
    }
    if (processMs <= 50) {
      return "orange_over_tick";
    }
    return "red_over_budget";
  }

  private static String priorityExpectation(ObserverRange range, int processMs, int rttMs, EventProfile profile) {
    if ("far".equals(range.name)) {
      return "suppress_far_datagrams_defer_world_detail";
    }
    if (processMs > 50 || ("event_surge".equals(profile.name) && rttMs >= 100)) {
      return "protect_reliable_core_drop_low_priority";
    }
    if ("mid".equals(range.name)) {
      return "thin_datagrams_to_5hz_defer_detail";
    }
    if (processMs <= 16 && rttMs <= 50) {
      return "full_near_datagram_budget";
    }
    return "protect_reliable_core_limit_low_priority";
  }

  private static void writeFixtures(Path path, Path cachePath, long snapshotId, Map<String, Long> tableCounts, Map<String, Long> categoryCounts, List<DensityCell> cells, List<String> notes) throws IOException {
    StringBuilder sb = new StringBuilder();
    sb.append("{\n");
    appendNumberProp(sb, 1, "schema_version", 1, true);
    appendStringProp(sb, 1, "generated_at_utc", Instant.now().toString(), true);
    appendStringProp(sb, 1, "source_cache", cachePath.toAbsolutePath().toString(), true);
    appendNumberProp(sb, 1, "snapshot_id", snapshotId, true);
    appendStringLongMapProp(sb, 1, "table_counts", tableCounts, true);
    appendStringLongMapProp(sb, 1, "category_counts", categoryCounts, true);
    appendNotesProp(sb, 1, notes, true);
    indent(sb, 1).append("\"density_cells\": [\n");
    for (int i = 0; i < cells.size(); i++) {
      appendDensityCell(sb, 2, cells.get(i));
      if (i + 1 < cells.size()) {
        sb.append(",");
      }
      sb.append("\n");
    }
    indent(sb, 1).append("]\n");
    sb.append("}\n");
    Files.writeString(path, sb.toString(), StandardCharsets.UTF_8);
  }

  private static void writeSummary(Path path, Path cachePath, long snapshotId, Map<String, Long> tableCounts, Map<String, Long> categoryCounts, List<DensityCell> cells, int[] actorPlayers, ObserverRange[] ranges, int[] rttMs, int[] processMs, EventProfile[] profiles, int rowCount, List<String> notes) throws IOException {
    StringBuilder sb = new StringBuilder();
    sb.append("{\n");
    appendNumberProp(sb, 1, "schema_version", 1, true);
    appendStringProp(sb, 1, "status", "pass", true);
    appendStringProp(sb, 1, "generated_at_utc", Instant.now().toString(), true);
    appendStringProp(sb, 1, "cache_path", cachePath.toAbsolutePath().toString(), true);
    appendNumberProp(sb, 1, "snapshot_id", snapshotId, true);
    appendStringLongMapProp(sb, 1, "table_counts", tableCounts, true);
    appendStringLongMapProp(sb, 1, "category_counts", categoryCounts, true);
    appendNumberProp(sb, 1, "density_fixture_count", cells.size(), true);
    appendNumberProp(sb, 1, "matrix_row_count", rowCount, true);
    appendAxes(sb, actorPlayers, ranges, rttMs, processMs, profiles);
    appendOutputs(sb);
    appendFixtureSummary(sb, cells);
    appendNotesProp(sb, 1, notes, false);
    sb.append("}\n");
    Files.writeString(path, sb.toString(), StandardCharsets.UTF_8);
  }

  private static void writeFailure(Path path, Path cachePath, String status, String message) throws IOException {
    StringBuilder sb = new StringBuilder();
    sb.append("{\n");
    appendNumberProp(sb, 1, "schema_version", 1, true);
    appendStringProp(sb, 1, "status", status, true);
    appendStringProp(sb, 1, "generated_at_utc", Instant.now().toString(), true);
    appendStringProp(sb, 1, "cache_path", cachePath.toAbsolutePath().toString(), true);
    appendNumberProp(sb, 1, "density_fixture_count", 0, true);
    appendNumberProp(sb, 1, "matrix_row_count", 0, true);
    appendStringProp(sb, 1, "message", message, false);
    sb.append("}\n");
    Files.writeString(path, sb.toString(), StandardCharsets.UTF_8);
  }

  private static void appendAxes(StringBuilder sb, int[] actorPlayers, ObserverRange[] ranges, int[] rttMs, int[] processMs, EventProfile[] profiles) {
    indent(sb, 1).append("\"axes\": {\n");
    appendIntArrayProp(sb, 2, "actor_players", actorPlayers, true);
    indent(sb, 2).append("\"observer_ranges\": [");
    for (int i = 0; i < ranges.length; i++) {
      if (i > 0) {
        sb.append(", ");
      }
      sb.append(quote(ranges[i].name));
    }
    sb.append("],\n");
    appendIntArrayProp(sb, 2, "rtt_ms", rttMs, true);
    appendIntArrayProp(sb, 2, "server_process_ms", processMs, true);
    indent(sb, 2).append("\"event_profiles\": [");
    for (int i = 0; i < profiles.length; i++) {
      if (i > 0) {
        sb.append(", ");
      }
      sb.append(quote(profiles[i].name));
    }
    sb.append("]\n");
    indent(sb, 1).append("},\n");
  }

  private static void appendOutputs(StringBuilder sb) {
    indent(sb, 1).append("\"outputs\": {\n");
    appendStringProp(sb, 2, "fixtures", "telemetry/era16-density-fixtures.json", true);
    appendStringProp(sb, 2, "matrix_csv", "telemetry/era16-pressure-matrix.csv", true);
    appendStringProp(sb, 2, "summary", "telemetry/matrix-summary.json", false);
    indent(sb, 1).append("},\n");
  }

  private static void appendFixtureSummary(StringBuilder sb, List<DensityCell> cells) {
    indent(sb, 1).append("\"density_fixtures\": [\n");
    for (int i = 0; i < cells.size(); i++) {
      DensityCell c = cells.get(i);
      indent(sb, 2).append("{\n");
      appendStringProp(sb, 3, "band", c.band, true);
      appendStringProp(sb, 3, "label", c.label, true);
      appendNumberProp(sb, 3, "world_x", c.worldX, true);
      appendNumberProp(sb, 3, "world_z", c.worldZ, true);
      appendNumberProp(sb, 3, "build_zdos_500m", c.buildZdos, true);
      appendNumberProp(sb, 3, "total_zdos_500m", c.totalZdos, true);
      appendNumberProp(sb, 3, "container_item_rows_500m", c.containerRows, false);
      indent(sb, 2).append("}");
      if (i + 1 < cells.size()) {
        sb.append(",");
      }
      sb.append("\n");
    }
    indent(sb, 1).append("],\n");
  }

  private static void appendDensityCell(StringBuilder sb, int level, DensityCell c) {
    indent(sb, level).append("{\n");
    appendStringProp(sb, level + 1, "band", c.band, true);
    appendStringProp(sb, level + 1, "label", c.label, true);
    appendNumberProp(sb, level + 1, "cell_size", c.cellSize, true);
    appendNumberProp(sb, level + 1, "cx", c.cx, true);
    appendNumberProp(sb, level + 1, "cz", c.cz, true);
    appendNumberProp(sb, level + 1, "world_x", c.worldX, true);
    appendNumberProp(sb, level + 1, "world_z", c.worldZ, true);
    appendNumberProp(sb, level + 1, "build_zdos_500m", c.buildZdos, true);
    appendNumberProp(sb, level + 1, "total_zdos_500m", c.totalZdos, true);
    appendNumberProp(sb, level + 1, "container_item_rows_500m", c.containerRows, true);
    appendNumberProp(sb, level + 1, "creator_count_500m", c.creatorCount, true);
    appendNumberProp(sb, level + 1, "portal_count_500m", c.portalCount, true);
    appendNumberProp(sb, level + 1, "sign_count_500m", c.signCount, true);
    appendStringLongMapProp(sb, level + 1, "top_container_items", c.topItems, true);
    appendStringLongMapProp(sb, level + 1, "top_prefabs", c.topPrefabs, true);
    appendStringLongMapProp(sb, level + 1, "top_creators", c.topCreators, false);
    indent(sb, level).append("}");
  }

  private static Map<String, Long> tableCounts(Connection conn) throws SQLException {
    Map<String, Long> counts = new LinkedHashMap<>();
    for (String table : Arrays.asList("world_snapshot", "render_cell", "zdo", "container_item")) {
      counts.put(table, queryLong(conn, "SELECT COUNT(*) FROM " + table));
    }
    return counts;
  }

  private static Map<String, Long> categoryCounts(Connection conn, long snapshotId) throws SQLException {
    Map<String, Long> counts = new LinkedHashMap<>();
    try (PreparedStatement ps = conn.prepareStatement("SELECT COALESCE(category, 'UNKNOWN') AS k, COUNT(*) AS v FROM zdo WHERE snapshot_id = ? GROUP BY k ORDER BY v DESC")) {
      ps.setLong(1, snapshotId);
      try (ResultSet rs = ps.executeQuery()) {
        while (rs.next()) {
          counts.put(rs.getString("k"), rs.getLong("v"));
        }
      }
    }
    return counts;
  }

  private static long queryLong(Connection conn, String sql, Object... args) throws SQLException {
    try (PreparedStatement ps = conn.prepareStatement(sql)) {
      bind(ps, args);
      try (ResultSet rs = ps.executeQuery()) {
        if (rs.next()) {
          return rs.getLong(1);
        }
        return 0L;
      }
    }
  }

  private static long queryLong(Connection conn, String sql) throws SQLException {
    try (Statement st = conn.createStatement(); ResultSet rs = st.executeQuery(sql)) {
      if (rs.next()) {
        return rs.getLong(1);
      }
      return 0L;
    }
  }

  private static Map<String, Long> topStringLong(Connection conn, String sql, Object... args) throws SQLException {
    Map<String, Long> values = new LinkedHashMap<>();
    try (PreparedStatement ps = conn.prepareStatement(sql)) {
      bind(ps, args);
      try (ResultSet rs = ps.executeQuery()) {
        while (rs.next()) {
          values.put(rs.getString("k"), rs.getLong("v"));
        }
      }
    }
    return values;
  }

  private static void bind(PreparedStatement ps, Object... args) throws SQLException {
    for (int i = 0; i < args.length; i++) {
      Object arg = args[i];
      if (arg instanceof Long) {
        ps.setLong(i + 1, (Long) arg);
      } else if (arg instanceof Integer) {
        ps.setInt(i + 1, (Integer) arg);
      } else if (arg instanceof Double) {
        ps.setDouble(i + 1, (Double) arg);
      } else {
        ps.setObject(i + 1, arg);
      }
    }
  }

  private static void appendStringProp(StringBuilder sb, int level, String name, String value, boolean comma) {
    indent(sb, level).append(quote(name)).append(": ").append(quote(value));
    if (comma) {
      sb.append(",");
    }
    sb.append("\n");
  }

  private static void appendNumberProp(StringBuilder sb, int level, String name, long value, boolean comma) {
    indent(sb, level).append(quote(name)).append(": ").append(value);
    if (comma) {
      sb.append(",");
    }
    sb.append("\n");
  }

  private static void appendNumberProp(StringBuilder sb, int level, String name, double value, boolean comma) {
    indent(sb, level).append(quote(name)).append(": ").append(number(value));
    if (comma) {
      sb.append(",");
    }
    sb.append("\n");
  }

  private static void appendStringLongMapProp(StringBuilder sb, int level, String name, Map<String, Long> map, boolean comma) {
    indent(sb, level).append(quote(name)).append(": {");
    if (!map.isEmpty()) {
      sb.append("\n");
      int index = 0;
      for (Map.Entry<String, Long> entry : map.entrySet()) {
        indent(sb, level + 1).append(quote(entry.getKey())).append(": ").append(entry.getValue());
        if (++index < map.size()) {
          sb.append(",");
        }
        sb.append("\n");
      }
      indent(sb, level).append("}");
    } else {
      sb.append("}");
    }
    if (comma) {
      sb.append(",");
    }
    sb.append("\n");
  }

  private static void appendIntArrayProp(StringBuilder sb, int level, String name, int[] values, boolean comma) {
    indent(sb, level).append(quote(name)).append(": [");
    for (int i = 0; i < values.length; i++) {
      if (i > 0) {
        sb.append(", ");
      }
      sb.append(values[i]);
    }
    sb.append("]");
    if (comma) {
      sb.append(",");
    }
    sb.append("\n");
  }

  private static void appendNotesProp(StringBuilder sb, int level, List<String> notes, boolean comma) {
    indent(sb, level).append("\"notes\": [");
    for (int i = 0; i < notes.size(); i++) {
      if (i > 0) {
        sb.append(", ");
      }
      sb.append(quote(notes.get(i)));
    }
    sb.append("]");
    if (comma) {
      sb.append(",");
    }
    sb.append("\n");
  }

  private static StringBuilder indent(StringBuilder sb, int level) {
    for (int i = 0; i < level; i++) {
      sb.append("  ");
    }
    return sb;
  }

  private static String quote(String value) {
    if (value == null) {
      return "null";
    }

    StringBuilder sb = new StringBuilder();
    sb.append('"');
    for (int i = 0; i < value.length(); i++) {
      char c = value.charAt(i);
      switch (c) {
        case '"':
          sb.append("\\\"");
          break;
        case '\\':
          sb.append("\\\\");
          break;
        case '\b':
          sb.append("\\b");
          break;
        case '\f':
          sb.append("\\f");
          break;
        case '\n':
          sb.append("\\n");
          break;
        case '\r':
          sb.append("\\r");
          break;
        case '\t':
          sb.append("\\t");
          break;
        default:
          if (c < 0x20) {
            sb.append(String.format(Locale.ROOT, "\\u%04x", (int) c));
          } else {
            sb.append(c);
          }
      }
    }
    sb.append('"');
    return sb.toString();
  }

  private static String csv(String value) {
    String escaped = value == null ? "" : value.replace("\"", "\"\"");
    return "\"" + escaped + "\"";
  }

  private static String number(double value) {
    return String.format(Locale.ROOT, "%.2f", value);
  }
}
'@

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($javaSourcePath, $javaSource, $utf8NoBom)

$compileProcess = Start-Process -FilePath $javacExe `
  -ArgumentList @("-classpath", $duckDbJar, $javaSourcePath) `
  -RedirectStandardOutput $compileOutPath `
  -RedirectStandardError $compileErrPath `
  -NoNewWindow `
  -Wait `
  -PassThru
if ($compileProcess.ExitCode -ne 0) {
  Write-BlockedSummary -Status "fail_generator_compile" -Message "Era16 pressure matrix generator failed to compile. Inspect raw/era16-pressure-matrix-compile.err.log." -ExitCode 1
}

$classPath = "$rawDir;$duckDbJar"
$generatorProcess = Start-Process -FilePath $javaExe `
  -ArgumentList @("-Xmx4g", "-classpath", $classPath, "Era16PressureMatrixGenerator", $cachePath, $fixturesPath, $matrixCsvPath, $summaryPath) `
  -RedirectStandardOutput $generatorOutPath `
  -RedirectStandardError $generatorErrPath `
  -NoNewWindow `
  -Wait `
  -PassThru
if ($generatorProcess.ExitCode -ne 0) {
  if (-not (Test-Path $summaryPath)) {
    Write-BlockedSummary -Status "fail_generator_run" -Message "Era16 pressure matrix generator failed. Inspect raw/era16-pressure-matrix-generator.err.log." -ExitCode 1
  }
  exit 1
}

$summary = Get-Content -Raw $summaryPath | ConvertFrom-Json
@(
  "# Era16 Density Pressure Matrix",
  "",
  "Status: $($summary.status)",
  "",
  "Source cache: $cachePath",
  "",
  "Generated artifacts:",
  "",
  "- ``telemetry/era16-density-fixtures.json``",
  "- ``telemetry/era16-pressure-matrix.csv``",
  "- ``telemetry/matrix-summary.json``",
  "",
  "Matrix rows: $($summary.matrix_row_count)",
  "Density fixtures: $($summary.density_fixture_count)"
) | Set-Content -Encoding UTF8 $commandSummaryPath

if ($summary.status -ne "pass") {
  exit 1
}

exit 0
