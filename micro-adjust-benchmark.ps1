$INCREMENT = 0.002
$START = 0.5
$END = 0.8
$SAMPLES = 20

function Is-Admin() {
    $current_principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $current_principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function main() {
    $iterations = ($END - $START) / $INCREMENT
    $total_ms = $iterations * 102 * $SAMPLES

    Write-Host "Approximate worst-case estimated time for completion: $([math]::Round($total_ms / 6E4, 2))mins)"
    Write-Host "Worst-case is determined by assuming Sleep(1) = ~2ms with 1ms Timer Resolution"

    if (-not (Is-Admin)) {
        Write-Host "error: administrator privileges required"
        return 1
    }

    Stop-Process -Name "SetTimerResolution" -ErrorAction SilentlyContinue

    Set-Location $PSScriptRoot

    foreach ($dependency in @("SetTimerResolution.exe", "MeasureSleep.exe")) {
        if (-not (Test-Path $dependency)) {
            Write-Host "error: $($dependency) not exists in current directory"
            return 1
        }
    }

    "RequestedResolutionMs,DeltaMs,STDEV" | Out-File results.csv

    for ($i = $START; $i -le $END; $i += $INCREMENT) {
        $i = [math]::Round($i, 3)

        Write-Host "info: benchmarking $($i)ms"

        Start-Process ".\SetTimerResolution.exe" -ArgumentList @("--resolution", ($i * 1E4), "--no-console")
        Start-Sleep 2

        $output = .\MeasureSleep.exe --samples $SAMPLES
        $outputLines = $output -split "`n"

        foreach ($line in $outputLines) {
            if ($line -match "Avg: (.*)") {
                $avg = $Matches[1]
            } elseif ($line -match "STDEV: (.*)") {
                $stdev = $Matches[1]
            }
        }

        $avg = $avg -replace "Avg: "
        $stdev = $stdev -replace "STDEV: "

        "$($i), $([math]::Round([double]$avg, 3)), $($stdev)" | Out-File results.csv -Append

        Stop-Process -Name "SetTimerResolution" -ErrorAction SilentlyContinue
    }

    Write-Host "info: results saved in results.csv"
    return 0
}

exit main