$path = "C:\ProgramData\Microsoft\Diagnosis\ETLLogs"

$sizeBefore = (Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
if ($null -eq $sizeBefore) { $sizeBefore = 0 }

$items = Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue
$failed = @()

foreach ($i in $items) {
    try {
        Remove-Item -LiteralPath $i.FullName -Recurse -Force -ErrorAction Stop
    }
    catch {
        $ex = $_.Exception
        $failed += [pscustomobject]@{
            Path    = $i.FullName
            Type    = $ex.GetType().FullName
            HResult = ('0x{0:X8}' -f $ex.HResult)
            Message = $ex.Message
        }
    }
}

$telegrafLog = "C:\Program Files\telegraf\telegraf.log"
$telegrafResult = $null

if (Test-Path -LiteralPath $telegrafLog) {
    try {
        $before = (Get-Item -LiteralPath $telegrafLog -ErrorAction Stop).Length
        Set-Content -LiteralPath $telegrafLog -Value $null -Encoding UTF8 -ErrorAction Stop
        $after = (Get-Item -LiteralPath $telegrafLog -ErrorAction SilentlyContinue).Length
        if ($null -eq $after) { $after = 0 }
        $telegrafResult = [pscustomobject]@{
            Path    = $telegrafLog
            Cleared = $true
            FreedMB = [math]::Round((($before - $after) / 1MB), 2)
        }
    }
    catch {
        $ex = $_.Exception
        $telegrafResult = [pscustomobject]@{
            Path    = $telegrafLog
            Cleared = $false
            Type    = $ex.GetType().FullName
            HResult = ('0x{0:X8}' -f $ex.HResult)
            Message = $ex.Message
        }
    }
}

$sizeAfter = (Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
if ($null -eq $sizeAfter) { $sizeAfter = 0 }

$freed = $sizeBefore - $sizeAfter
"{0:N2} MB freed (ETLLogs)" -f ($freed / 1MB)
"Failed items (ETLLogs): $($failed.Count)"
if ($failed.Count -gt 0) { $failed | Format-Table -Auto }

if ($null -ne $telegrafResult) {
    if ($telegrafResult.Cleared) { "Telegraf log cleared: $($telegrafResult.FreedMB) MB freed" }
    else { "Telegraf log clear failed: $($telegrafResult.Message) [$($telegrafResult.HResult)]" }
}
