#Requires -Version 5.1
# claude-usage-tray.ps1 - Show Claude Code usage in Windows system tray

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==================== Config ====================
$TOKEN_LIMIT  = 500000    # token limit per window — adjust by comparing with /usage
$WINDOW_HOURS = 5
$UPDATE_MS    = 60000     # refresh interval (ms) = 1 min

# --- WSL auto-detection (uncomment to override) ---
# $WSL_DISTRO = "Ubuntu"
# $WSL_USER   = "yourname"
# --------------------------------------------------
try {
    if (-not $WSL_DISTRO) {
        $WSL_DISTRO = ((wsl.exe -l -q 2>$null) -replace '\x00','' |
            Where-Object { $_ -match '\S' } | Select-Object -First 1).Trim()
    }
    if (-not $WSL_USER) {
        $WSL_USER = (wsl.exe -d $WSL_DISTRO -- whoami 2>$null).Trim()
    }
} catch {}
# ================================================

$HISTORY_FILE = "\\wsl.localhost\$WSL_DISTRO\home\$WSL_USER\.claude\history.jsonl"
$PROJECTS_DIR = "\\wsl.localhost\$WSL_DISTRO\home\$WSL_USER\.claude\projects"

function Get-Usage {
    $now    = Get-Date
    $cutoff = $now.AddHours(-$WINDOW_HOURS)
    $times  = @()

    if (-not (Test-Path $HISTORY_FILE)) {
        return [PSCustomObject]@{ Error = "File not found:`n$HISTORY_FILE" }
    }

    try {
        [System.IO.File]::ReadAllLines($HISTORY_FILE) | ForEach-Object {
            if ($_ -match '"timestamp"\s*:\s*(\d+)') {
                $ts = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$Matches[1]).LocalDateTime
                if ($ts -gt $cutoff) { $times += $ts }
            }
        }
    } catch {
        return [PSCustomObject]@{ Error = $_.Exception.Message }
    }

    $count   = $times.Count
    $pct     = [math]::Min(100, [math]::Round($count * 100.0 / $MSG_LIMIT))
    $minLeft = 0
    if ($count -gt 0) {
        $oldest  = ($times | Sort-Object)[0]
        $minLeft = [math]::Max(0, [math]::Ceiling(($oldest.AddHours($WINDOW_HOURS) - $now).TotalMinutes))
    }

    return [PSCustomObject]@{
        Count   = $count
        Percent = $pct
        MinLeft = $minLeft
        Error   = $null
    }
}

function Get-TokenUsage {
    $now    = Get-Date
    $cutoff = $now.AddHours(-$WINDOW_HOURS)
    $inTok  = 0
    $outTok = 0

    try {
        $files = [System.IO.Directory]::GetFiles($PROJECTS_DIR, "*.jsonl",
            [System.IO.SearchOption]::AllDirectories)
    } catch {
        return [PSCustomObject]@{ Input = 0; Output = 0; Total = 0 }
    }

    foreach ($file in $files) {
        try {
            foreach ($line in [System.IO.File]::ReadAllLines($file)) {
                if ($line -match '"output_tokens"' -and $line -match '"timestamp"\s*:\s*"([^"]+)"') {
                    try {
                        $ts = [DateTime]::Parse($Matches[1]).ToLocalTime()
                        if ($ts -gt $cutoff) {
                            $obj   = $line | ConvertFrom-Json
                            $usage = if ($obj.message) { $obj.message.usage } else { $null }
                            if ($usage -and $usage.output_tokens) {
                                $inTok  += [int]$usage.input_tokens +
                                           [int]$usage.cache_creation_input_tokens +
                                           [int]$usage.cache_read_input_tokens
                                $outTok += [int]$usage.output_tokens
                            }
                        }
                    } catch {}
                }
            }
        } catch {}
    }

    return [PSCustomObject]@{
        Input  = $inTok
        Output = $outTok
        Total  = $inTok + $outTok
    }
}

function New-TrayIcon([int]$Pct, [int]$MinLeft = 0, [bool]$Err = $false) {
    $sz  = 64
    $bmp = New-Object System.Drawing.Bitmap $sz, $sz
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $g.Clear([System.Drawing.Color]::Transparent)

    if ($Err) {
        $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(80, 80, 80))
        $g.FillRoundedRectangle = $null  # fallback to plain rect
        $g.FillRectangle($brush, 2, 2, $sz-4, $sz-4)
        $brush.Dispose()
        $f = New-Object System.Drawing.Font 'Segoe UI', 14, ([System.Drawing.FontStyle]::Bold)
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment     = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        $g.DrawString('ERR', $f, [System.Drawing.Brushes]::White, [System.Drawing.RectangleF]::new(0,0,$sz,$sz), $sf)
        $f.Dispose(); $sf.Dispose()
    } else {
        $clr = if ($Pct -lt 60) { [System.Drawing.Color]::FromArgb(34, 139, 34) }
               elseif ($Pct -lt 85) { [System.Drawing.Color]::FromArgb(210, 105, 0) }
               else { [System.Drawing.Color]::FromArgb(200, 40, 40) }
        $brush = New-Object System.Drawing.SolidBrush $clr
        $g.FillRectangle($brush, 2, 2, $sz-4, $sz-4)
        $brush.Dispose()

        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = [System.Drawing.StringAlignment]::Center

        # top half: percentage
        $fPct = New-Object System.Drawing.Font 'Segoe UI', 16, ([System.Drawing.FontStyle]::Bold)
        $g.DrawString("$Pct%", $fPct, [System.Drawing.Brushes]::White,
            [System.Drawing.RectangleF]::new(0, 2, $sz, 30), $sf)
        $fPct.Dispose()

        # bottom half: minutes until reset
        $minTxt = if ($MinLeft -gt 0) { "$($MinLeft)m" } else { '--' }
        $fMin = New-Object System.Drawing.Font 'Segoe UI', 15
        $g.DrawString($minTxt, $fMin, [System.Drawing.Brushes]::White,
            [System.Drawing.RectangleF]::new(0, 32, $sz, 30), $sf)
        $fMin.Dispose(); $sf.Dispose()
    }

    $g.Dispose()
    $hicon = $bmp.GetHicon()
    $icon  = [System.Drawing.Icon]::FromHandle($hicon)
    $bmp.Dispose()
    return $icon
}

# ========== Init ==========
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Visible         = $true
$tray.BalloonTipTitle = 'Claude Usage'
$tray.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]::Info

$menu      = New-Object System.Windows.Forms.ContextMenuStrip
$miRefresh = $menu.Items.Add('Refresh now')
$menu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new()) | Out-Null
$miQuit    = $menu.Items.Add('Quit')
$tray.ContextMenuStrip = $menu

$script:prevIcon = $null
$script:lastMsg  = 'Loading...'

function Update-Display {
    $u = Get-Usage

    if ($script:prevIcon) { $script:prevIcon.Dispose() }

    if ($u.Error) {
        $script:prevIcon = New-TrayIcon 0 0 $true
        $tray.Icon       = $script:prevIcon
        $tray.Text       = 'Claude: Error (left-click for details)'
        $script:lastMsg  = $u.Error
        return
    }

    $t      = Get-TokenUsage
    $tokPct = [math]::Min(100, [math]::Round($t.Total * 100.0 / $TOKEN_LIMIT))

    $script:prevIcon = New-TrayIcon $tokPct $u.MinLeft
    $tray.Icon       = $script:prevIcon

    $resetTxt = if ($u.MinLeft -gt 0) {
        "Reset in $($u.MinLeft) min"
    } elseif ($u.Count -eq 0) {
        '0 msgs in window'
    } else {
        'Outside window'
    }

    $fmt = { param($n) if ($n -ge 1000) { "$([math]::Round($n/1000, 1))k" } else { "$n" } }
    $tip       = "Claude $tokPct% ($(& $fmt $t.Total)tok) | $resetTxt"
    $tray.Text = if ($tip.Length -gt 63) { $tip.Substring(0, 63) } else { $tip }

    $script:lastMsg = "Tokens ($($WINDOW_HOURS)h): $tokPct% ($(& $fmt $t.Total) / $(& $fmt $TOKEN_LIMIT))`n  In:    $(& $fmt $t.Input)`n  Out:   $(& $fmt $t.Output)`nReset in: $($u.MinLeft) min`nSessions: $($u.Count)"
}

$tray.Add_Click({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $tray.BalloonTipText = $script:lastMsg
        $tray.ShowBalloonTip(4000)
    }
})

$miRefresh.Add_Click({ Update-Display })

$miQuit.Add_Click({
    $timer.Stop()
    $tray.Visible = $false
    $tray.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

$timer          = New-Object System.Windows.Forms.Timer
$timer.Interval = $UPDATE_MS
$timer.Add_Tick({ Update-Display })
$timer.Start()

Update-Display

[System.Windows.Forms.Application]::Run()
