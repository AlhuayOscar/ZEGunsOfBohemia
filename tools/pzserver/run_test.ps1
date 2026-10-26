<#
    run_test.ps1  -  boots a Project Zomboid dedicated server with the mod and runs the self-test.

        powershell -ExecutionPolicy Bypass -File tools/pzserver/run_test.ps1 [-ServerDir C:\Users\ROG\pzserver]
                   [-Profile C:\Users\ROG\pzserver_test] [-TimeoutSec 600] [-NoMods]

    The server (Steam app 380870, anonymous SteamCMD download) runs headless on a scratch profile
    (-cachedir), so it never touches the real Zomboid folder. The profile's mods/ links to this
    repo's Contents/mods/* and to the Gunworks Workshop folder, so the server loads the working
    copy. Lua/ZGB_autotest.txt makes ZGB_AutoTest.lua run the self-test once the server is up;
    the script waits for "[ZGB][AUTOTEST] DONE", stops the server and copies the report and the
    log to .cache/pzserver/.

    Exit code: 0 when the self-test ran with 0 FAIL, 1 otherwise (or on timeout / Lua errors).
#>
param(
    [string]$ServerDir = "C:\Users\ROG\pzserver",
    [string]$Profile = "C:\Users\ROG\pzserver_test",
    [string]$Workshop = "C:\Program Files (x86)\Steam\steamapps\workshop\content\108600",
    [int]$TimeoutSec = 600,
    [switch]$NoMods
)
$ErrorActionPreference = "Stop"
$Repo = (Resolve-Path "$PSScriptRoot\..\..").Path
$Out = Join-Path $Repo ".cache\pzserver"
New-Item -ItemType Directory -Force $Out, $Profile, "$Profile\mods", "$Profile\Lua", "$Profile\Server" | Out-Null

# --- mods: the working copy and Gunworks (SWMG), copied
$ModIds = @()
if (-not $NoMods) {
    $links = @{}
    Get-ChildItem "$Repo\Contents\mods" -Directory | ForEach-Object { $links[$_.Name] = $_.FullName }
    $gw = Join-Path $Workshop "3722064198\mods\Gunworks_gang_framework"
    if (-not (Test-Path $gw)) { throw "Gunworks not found at $gw (subscribe to Workshop 3722064198)" }
    $links["Gunworks_gang_framework"] = $gw
    # copies, not junctions: through a junction the server lost the path of the AnimSets while
    # checksumming them and aborted its init (no worldgen, "biomes of non-table"). robocopy /MIR
    # only copies what changed.
    foreach ($name in $links.Keys) {
        $dst = Join-Path "$Profile\mods" $name
        $item = Get-Item $dst -ErrorAction SilentlyContinue
        if ($item -and $item.LinkType) { $item.Delete() }            # an old junction: remove the link only
        robocopy $links[$name] $dst /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    }
    # load order: the framework, Core, then the addons (Iso is the view; FP is not built yet)
    $ModIds = @("SWMG", "ZEGunsOfBohemiaCore", "ZEGunsOfBohemiaIso", "ZEGunsOfBohemiaHolding", "ZEGunsOfBohemiaReload", "ZEGunsOfBohemiaCalls")
    Set-Content -Path "$Profile\Lua\ZGB_autotest.txt" -Value "run" -Encoding ascii
}

# --- server config: only the mod list is ours, the rest is the game's default
$ini = "$Profile\Server\zgbtest.ini"
if (Test-Path $ini) {
    $text = Get-Content $ini -Raw
    $mods = ($ModIds | ForEach-Object { "\" + $_ }) -join ";"
    $text = [regex]::Replace($text, "(?m)^Mods=.*$", "Mods=$mods")
    $text = [regex]::Replace($text, "(?m)^WorkshopItems=.*$", "WorkshopItems=")
    Set-Content -Path $ini -Value $text -Encoding ascii
}

# --- run
$log = Join-Path $Out "server_stdout.txt"
$args = @("-Djava.awt.headless=true", "-Dzomboid.steam=0", "-Dzomboid.znetlog=1", "-XX:+UseZGC", "-XX:-CreateCoredumpOnCrash",
          "-Xms2g", "-Xmx4g", "-Djava.library.path=natives/", "-cp", "java/;java/projectzomboid.jar",
          "zombie.network.GameServer", "-statistic", "0", "-nosteam", "-servername", "zgbtest",
          "-cachedir=$Profile", "-adminusername", "zgbadmin", "-adminpassword", "zgbtest-local")
$p = Start-Process -FilePath "$ServerDir\jre64\bin\java.exe" -ArgumentList $args -WorkingDirectory $ServerDir `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -WindowStyle Hidden
Write-Host "server pid $($p.Id), log $log"

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$done = $null
while ((Get-Date) -lt $deadline -and -not $p.HasExited) {
    Start-Sleep -Seconds 3
    if (Test-Path $log) {
        $hit = Select-String -Path $log -Pattern "\[ZGB\]\[AUTOTEST\] DONE|SERVER STARTED|Exception in thread" | Select-Object -Last 1
        if ($hit -and $hit.Line -match "AUTOTEST\] DONE") { $done = $hit.Line; break }
        if ($NoMods -and $hit -and $hit.Line -match "SERVER STARTED") { $done = $hit.Line; break }
    }
}
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
Start-Sleep -Seconds 2

foreach ($f in @("$Profile\console.txt", "$Profile\Lua\ZGB_selftest.txt")) {
    if (Test-Path $f) { Copy-Item $f $Out -Force }
}
$errors = @()
if (Test-Path $log) { $errors = Select-String -Path $log -Pattern "ERROR.*ZGB|\[ZGB\]\[ERROR\]|LuaManager.*ZEGunsOfBohemia|Kahlua.*ZGB" | Select-Object -First 20 }
Write-Host ("result: " + ($(if ($done) { $done } else { "no DONE line (timeout or crash)" })))
$errors | ForEach-Object { Write-Host "  $($_.Line)" }
if ($done -and $done -match " 0 FAIL" -and $errors.Count -eq 0) { exit 0 } else { exit 1 }
