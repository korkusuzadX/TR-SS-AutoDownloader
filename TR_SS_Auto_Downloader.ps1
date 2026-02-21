Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool ReleaseCapture();
    [DllImport("user32.dll")]
    public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
}
"@

function Build-RoundedPath([int]$w, [int]$h, [int]$radius) {
    if ($w -le 0 -or $h -le 0) { return $null }
    $cr = [Math]::Min($radius, [Math]::Min($w, $h) / 2)
    $segments = 8
    $angleStep = ([Math]::PI / 2) / $segments
    $corners = @(
        @{ cx = $w - $cr; cy = $cr;      startAngle = -[Math]::PI / 2 },
        @{ cx = $w - $cr; cy = $h - $cr; startAngle = 0 },
        @{ cx = $cr;      cy = $h - $cr; startAngle = [Math]::PI / 2 },
        @{ cx = $cr;      cy = $cr;      startAngle = [Math]::PI }
    )
    $pts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    foreach ($corner in $corners) {
        for ($i = 0; $i -le $segments; $i++) {
            $angle = $corner.startAngle + $i * $angleStep
            $pts.Add([System.Drawing.PointF]::new(
                [float]($corner.cx + $cr * [Math]::Cos($angle)),
                [float]($corner.cy + $cr * [Math]::Sin($angle))
            ))
        }
    }
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.StartFigure()
    $path.AddLines($pts.ToArray())
    $path.CloseFigure()
    return $path
}

function Set-Rounded {
    param(
        [System.Windows.Forms.Control]$Control,
        [int]$Radius,
        [System.Drawing.Color]$BorderColor = [System.Drawing.Color]::Empty,
        [float]$BorderWidth = 1.5
    )
    if ($null -eq $Control) { return }

    $r  = $Radius
    $bc = $BorderColor
    $bw = $BorderWidth

    $path = Build-RoundedPath $Control.Width $Control.Height $r
    if ($null -ne $path) {
        $Control.Region = New-Object System.Drawing.Region($path)
        $path.Dispose()
    }

    $Control.Add_SizeChanged({
        $path = Build-RoundedPath $this.Width $this.Height $r
        if ($null -eq $path) { return }
        $old = $this.Region
        $this.Region = New-Object System.Drawing.Region($path)
        if ($null -ne $old) { $old.Dispose() }
        $path.Dispose()
    })

    if (-not $bc.IsEmpty) {
        $Control.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $path = Build-RoundedPath $s.Width $s.Height $r
            if ($null -eq $path) { return }
            $pen = $null
            try {
                $pen = New-Object System.Drawing.Pen($bc, $bw)
                $pen.Alignment = [System.Drawing.Drawing2D.PenAlignment]::Inset
                $g.DrawPath($pen, $path)
            } finally {
                if ($null -ne $pen)  { $pen.Dispose() }
                if ($null -ne $path) { $path.Dispose() }
            }
        })
    }

    $Control.Add_Disposed({
        if ($null -ne $this.Region) { $this.Region.Dispose() }
    })
}

$tr = @{
    Iptal        = ([char]0x0130) + "ptal"
    IptalEdildi  = ([char]0x0130) + "ptal edildi."
    Baslatiliyor = "Ba" + ([char]0x015F) + "lat" + ([char]0x0131) + "l" + ([char]0x0131) + "yor..."
    Tamamlandi   = "Tamamland" + ([char]0x0131) + "!"
    Hata         = "Hata"
    Indiriliyor  = ([char]0x0130) + "ndiriliyor"
}

function Show-ScriptSelector {
    param([array]$Scripts)

    $sForm = New-Object System.Windows.Forms.Form
    $sForm.Size = New-Object System.Drawing.Size(500, 420)
    $sForm.StartPosition = "CenterScreen"
    $sForm.FormBorderStyle = "None"
    $sForm.BackColor = [System.Drawing.Color]::FromArgb(16, 16, 22)
    $sForm.TopMost = $true

    $sForm.Add_Paint({
        param($s, $e)
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(60, 130, 80, 200), 1)
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
        $pen.Dispose()
    })

    $sHeader = New-Object System.Windows.Forms.Panel
    $sHeader.Dock = "Top"
    $sHeader.Height = 44
    $sHeader.BackColor = [System.Drawing.Color]::FromArgb(22, 20, 35)
    $sForm.Controls.Add($sHeader)

    $dragHandler = {
        [Win32]::ReleaseCapture() | Out-Null
        [Win32]::SendMessage($sForm.Handle, 0xA1, 0x2, 0)
    }
    $sHeader.Add_MouseDown($dragHandler)

    $sTitle = New-Object System.Windows.Forms.Label
    $sTitle.Text = "Script Se" + ([char]0x00E7) + "im"
    $sTitle.Location = New-Object System.Drawing.Point(16, 0)
    $sTitle.Size = New-Object System.Drawing.Size(300, 44)
    $sTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
    $sTitle.ForeColor = [System.Drawing.Color]::FromArgb(185, 130, 255)
    $sTitle.TextAlign = "MiddleLeft"
    $sTitle.BackColor = [System.Drawing.Color]::Transparent
    $sTitle.Add_MouseDown($dragHandler)
    $sHeader.Controls.Add($sTitle)

    $sCloseBtn = New-Object System.Windows.Forms.Panel
    $sCloseBtn.Size = New-Object System.Drawing.Size(44, 30)
    $sCloseBtn.Cursor = "Hand"
    $sCloseBtn.BackColor = [System.Drawing.Color]::FromArgb(28, 26, 44)
    $sCloseBtn.Tag = $false

    $sCloseLbl = New-Object System.Windows.Forms.Label
    $sCloseLbl.Text = "x"
    $sCloseLbl.Dock = "Fill"
    $sCloseLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
    $sCloseLbl.ForeColor = [System.Drawing.Color]::FromArgb(155, 135, 180)
    $sCloseLbl.TextAlign = "MiddleCenter"
    $sCloseLbl.BackColor = [System.Drawing.Color]::FromArgb(28, 26, 44)
    $sCloseBtn.Controls.Add($sCloseLbl)

    $sCloseBtn.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        if ($s.Tag) {
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50, 210, 60, 80))
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
        } else {
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(28, 26, 44))
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
        }
    })
    $sCloseBtn.Add_MouseEnter({ $this.Tag = $true;  $this.Invalidate(); foreach($c in $this.Controls){ $c.ForeColor = [System.Drawing.Color]::White } })
    $sCloseBtn.Add_MouseLeave({ $this.Tag = $false; $this.Invalidate(); foreach($c in $this.Controls){ $c.ForeColor = [System.Drawing.Color]::FromArgb(155,135,180) } })
    $sCloseBtn.Add_Click({ $sForm.Close() })
    $sCloseLbl.Add_Click({ $sForm.Close() })
    $sHeader.Controls.Add($sCloseBtn)

    $contentArea = New-Object System.Windows.Forms.Panel
    $contentArea.Location = New-Object System.Drawing.Point(0, 44)
    $contentArea.Size = New-Object System.Drawing.Size(500, 290)
    $contentArea.BackColor = [System.Drawing.Color]::FromArgb(16, 16, 22)
    $sForm.Controls.Add($contentArea)

    $scrollTrack = New-Object System.Windows.Forms.Panel
    $scrollTrack.Size = New-Object System.Drawing.Size(6, 270)
    $scrollTrack.Location = New-Object System.Drawing.Point(482, 10)
    $scrollTrack.BackColor = [System.Drawing.Color]::FromArgb(30, 28, 48)
    $contentArea.Controls.Add($scrollTrack)

    $scrollThumb = New-Object System.Windows.Forms.Panel
    $scrollThumb.Size = New-Object System.Drawing.Size(6, 60)
    $scrollThumb.Location = New-Object System.Drawing.Point(0, 0)
    $scrollThumb.BackColor = [System.Drawing.Color]::FromArgb(110, 65, 180)
    $scrollThumb.Cursor = "Hand"
    $scrollTrack.Controls.Add($scrollThumb)

    $scrollThumb.Add_Paint({
        param($s, $e)
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $s.ClientRectangle,
            [System.Drawing.Color]::FromArgb(150, 95, 220),
            [System.Drawing.Color]::FromArgb(90, 50, 160),
            [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
        )
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $e.Graphics.FillRectangle($brush, $s.ClientRectangle)
        $brush.Dispose()
    })

    Set-Rounded $scrollTrack 3
    Set-Rounded $scrollThumb 3

    $itemsPanel = New-Object System.Windows.Forms.Panel
    $itemsPanel.Location = New-Object System.Drawing.Point(16, 8)
    $itemsPanel.Size = New-Object System.Drawing.Size(456, 274)
    $itemsPanel.BackColor = [System.Drawing.Color]::FromArgb(16, 16, 22)
    $contentArea.Controls.Add($itemsPanel)

    $checkboxes = @()
    $itemHeight = 44
    $totalHeight = $Scripts.Count * $itemHeight
    $script:scrollOffset = 0
    $visibleHeight = 274

    $updateScroll = {
        $maxScroll = [Math]::Max(0, $totalHeight - $visibleHeight)
        if ($maxScroll -eq 0) {
            $scrollThumb.Visible = $false
            return
        }
        $scrollThumb.Visible = $true
        $thumbRatio = $visibleHeight / $totalHeight
        $thumbH = [Math]::Max(20, [int]($scrollTrack.Height * $thumbRatio))
        $scrollThumb.Height = $thumbH
        $thumbY = [int](($script:scrollOffset / $maxScroll) * ($scrollTrack.Height - $thumbH))
        $scrollThumb.Top = [Math]::Max(0, [Math]::Min($thumbY, $scrollTrack.Height - $thumbH))
        $scrollThumb.Invalidate()

        foreach ($cb in $checkboxes) {
            $cb.Top = $cb.Tag.OriginalY - $script:scrollOffset
            $visible = ($cb.Top + $cb.Height -gt 0) -and ($cb.Top -lt $visibleHeight)
            $cb.Visible = $visible
        }
    }

    $wheelHandler = {
        param($sender, $e)
        $maxS = [Math]::Max(0, $totalHeight - $visibleHeight)
        if ($maxS -eq 0) { return }
        $delta = if ($e.Delta -gt 0) { -40 } else { 40 }
        $script:scrollOffset = [Math]::Max(0, [Math]::Min($script:scrollOffset + $delta, $maxS))
        & $updateScroll
    }

    $contentArea.Add_MouseWheel($wheelHandler)
    $itemsPanel.Add_MouseWheel($wheelHandler)

    $yPos = 0
    foreach ($scr in $Scripts) {
        $row = New-Object System.Windows.Forms.Panel
        $row.Size = New-Object System.Drawing.Size(446, 36)
        $row.Location = New-Object System.Drawing.Point(0, $yPos)
        $row.BackColor = [System.Drawing.Color]::FromArgb(26, 24, 40)
        $row.Tag = @{ Checked = $true; Script = $scr; OriginalY = $yPos }
        $row.Cursor = "Hand"

        $row.Add_MouseWheel($wheelHandler)

        $row.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            if ($s.Tag.Checked) {
                $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(38, 28, 60))
                $g.FillRectangle($brush, $s.ClientRectangle)
                $brush.Dispose()
                $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(50, 140, 80, 220), 1)
                $g.DrawRectangle($pen, 0, 0, $s.Width-1, $s.Height-1)
                $pen.Dispose()
            } else {
                $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(26, 24, 40))
                $g.FillRectangle($brush, $s.ClientRectangle)
                $brush.Dispose()
                $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(25, 100, 60, 160), 1)
                $g.DrawRectangle($pen, 0, 0, $s.Width-1, $s.Height-1)
                $pen.Dispose()
            }
            $cbX = 12; $cbY = 10; $cbSize = 16
            $cbRect = [System.Drawing.Rectangle]::new($cbX, $cbY, $cbSize, $cbSize)
            if ($s.Tag.Checked) {
                $cbBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(130, 75, 210))
                $g.FillRectangle($cbBrush, $cbRect)
                $cbBrush.Dispose()
                $cbPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(180, 120, 255), 1)
                $g.DrawRectangle($cbPen, $cbRect)
                $cbPen.Dispose()
                $tickPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)
                $tickPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
                $tickPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
                $g.DrawLine($tickPen, $cbX+3, $cbY+8, $cbX+6, $cbY+11)
                $g.DrawLine($tickPen, $cbX+6, $cbY+11, $cbX+13, $cbY+4)
                $tickPen.Dispose()
            } else {
                $cbPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 130, 80, 200), 1)
                $g.DrawRectangle($cbPen, $cbRect)
                $cbPen.Dispose()
            }
        })

        $nameLbl = New-Object System.Windows.Forms.Label
        $nameLbl.Text = $scr.Ad
        $nameLbl.Location = New-Object System.Drawing.Point(38, 0)
        $nameLbl.Size = New-Object System.Drawing.Size(400, 36)
        $nameLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        $nameLbl.ForeColor = [System.Drawing.Color]::FromArgb(185, 165, 210)
        $nameLbl.TextAlign = "MiddleLeft"
        $nameLbl.BackColor = [System.Drawing.Color]::Transparent
        $nameLbl.Add_MouseWheel($wheelHandler)
        $row.Controls.Add($nameLbl)

        $toggleAction = {
            $r = if ($this -is [System.Windows.Forms.Panel]) { $this } else { $this.Parent }
            $r.Tag.Checked = -not $r.Tag.Checked
            $r.Invalidate()
            $lbl = $r.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] } | Select-Object -First 1
            $lbl.ForeColor = if ($r.Tag.Checked) { [System.Drawing.Color]::FromArgb(185, 165, 210) } else { [System.Drawing.Color]::FromArgb(90, 80, 110) }
        }
        $row.Add_Click($toggleAction)
        $nameLbl.Add_Click($toggleAction)

        Set-Rounded $row 8
        $itemsPanel.Controls.Add($row)
        $checkboxes += $row
        $yPos += $itemHeight
    }

    & $updateScroll

    $btnSelectAll = New-Object System.Windows.Forms.Panel
    $btnSelectAll.Size = New-Object System.Drawing.Size(130, 36)
    $btnSelectAll.Location = New-Object System.Drawing.Point(16, 346)
    $btnSelectAll.Cursor = "Hand"
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(30, 28, 48)
    $btnSelectAll.Tag = $false

    $btnSelectAllLbl = New-Object System.Windows.Forms.Label
    $btnSelectAllLbl.Text = "T" + ([char]0x00FC) + "m" + ([char]0x00FC) + "n" + ([char]0x00FC) + " Se" + ([char]0x00E7)
    $btnSelectAllLbl.Dock = "Fill"
    $btnSelectAllLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
    $btnSelectAllLbl.ForeColor = [System.Drawing.Color]::FromArgb(160, 130, 200)
    $btnSelectAllLbl.TextAlign = "MiddleCenter"
    $btnSelectAllLbl.BackColor = [System.Drawing.Color]::Transparent
    $btnSelectAll.Controls.Add($btnSelectAllLbl)

    $btnClearAll = New-Object System.Windows.Forms.Panel
    $btnClearAll.Size = New-Object System.Drawing.Size(130, 36)
    $btnClearAll.Location = New-Object System.Drawing.Point(156, 346)
    $btnClearAll.Cursor = "Hand"
    $btnClearAll.BackColor = [System.Drawing.Color]::FromArgb(30, 28, 48)
    $btnClearAll.Tag = $false

    $btnClearAllLbl = New-Object System.Windows.Forms.Label
    $btnClearAllLbl.Text = "T" + ([char]0x00FC) + "m" + ([char]0x00FC) + "n" + ([char]0x00FC) + " Kald" + ([char]0x0131) + "r"
    $btnClearAllLbl.Dock = "Fill"
    $btnClearAllLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
    $btnClearAllLbl.ForeColor = [System.Drawing.Color]::FromArgb(160, 130, 200)
    $btnClearAllLbl.TextAlign = "MiddleCenter"
    $btnClearAllLbl.BackColor = [System.Drawing.Color]::Transparent
    $btnClearAll.Controls.Add($btnClearAllLbl)

    $btnRun = New-Object System.Windows.Forms.Panel
    $btnRun.Size = New-Object System.Drawing.Size(150, 36)
    $btnRun.Location = New-Object System.Drawing.Point(332, 346)
    $btnRun.Cursor = "Hand"
    $btnRun.BackColor = [System.Drawing.Color]::FromArgb(55, 30, 90)
    $btnRun.Tag = $false

    $btnRunLbl = New-Object System.Windows.Forms.Label
    $btnRunLbl.Text = ([char]0x0130) + "ndir ve " + ([char]0x00C7) + "al" + ([char]0x0131) + ([char]0x015F) + "t" + ([char]0x0131) + "r"
    $btnRunLbl.Dock = "Fill"
    $btnRunLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
    $btnRunLbl.ForeColor = [System.Drawing.Color]::FromArgb(210, 170, 255)
    $btnRunLbl.TextAlign = "MiddleCenter"
    $btnRunLbl.BackColor = [System.Drawing.Color]::Transparent
    $btnRun.Controls.Add($btnRunLbl)

    foreach ($sb in @($btnSelectAll, $btnClearAll)) {
        $sb.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $clr = if ($s.Tag) { [System.Drawing.Color]::FromArgb(50, 45, 75) } else { [System.Drawing.Color]::FromArgb(30, 28, 48) }
            $brush = New-Object System.Drawing.SolidBrush($clr)
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(40, 130, 80, 200), 1)
            $g.DrawRectangle($pen, 0, 0, $s.Width-1, $s.Height-1)
            $pen.Dispose()
        })
        $sb.Add_MouseEnter({ $this.Tag = $true;  $this.Invalidate() })
        $sb.Add_MouseLeave({ $this.Tag = $false; $this.Invalidate() })
    }

    $btnRun.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        if ($s.Tag) {
            $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                $s.ClientRectangle,
                [System.Drawing.Color]::FromArgb(95, 55, 165),
                [System.Drawing.Color]::FromArgb(130, 75, 200),
                [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
            )
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
        } else {
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55, 30, 90))
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
        }
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 160, 100, 255), 1)
        $g.DrawRectangle($pen, 0, 0, $s.Width-1, $s.Height-1)
        $pen.Dispose()
    })
    $btnRun.Add_MouseEnter({ $this.Tag = $true;  $this.Invalidate() })
    $btnRun.Add_MouseLeave({ $this.Tag = $false; $this.Invalidate() })

    $selectAllAction = {
        foreach ($cb in $checkboxes) {
            $cb.Tag.Checked = $true
            $cb.Invalidate()
            $lbl = $cb.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] } | Select-Object -First 1
            $lbl.ForeColor = [System.Drawing.Color]::FromArgb(185, 165, 210)
        }
    }
    $clearAllAction = {
        foreach ($cb in $checkboxes) {
            $cb.Tag.Checked = $false
            $cb.Invalidate()
            $lbl = $cb.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] } | Select-Object -First 1
            $lbl.ForeColor = [System.Drawing.Color]::FromArgb(90, 80, 110)
        }
    }
    $runAction = {
        $secilenler = @()
        foreach ($cb in $checkboxes) {
            if ($cb.Tag.Checked) { $secilenler += $cb.Tag.Script }
        }
        if ($secilenler.Count -eq 0) { return }
        $sForm.Close()
        $target = Join-Path $downloadsPath "ScreenShareTools\PSScripts"
        Invoke-TaskWithProgress -Title "TR SS Scripts" -Items $secilenler -TargetPath $target -RunAfterDownload $true
    }

    $btnSelectAll.Add_Click($selectAllAction)
    $btnSelectAllLbl.Add_Click($selectAllAction)
    $btnClearAll.Add_Click($clearAllAction)
    $btnClearAllLbl.Add_Click($clearAllAction)
    $btnRun.Add_Click($runAction)
    $btnRunLbl.Add_Click($runAction)

    $sForm.Controls.Add($btnSelectAll)
    $sForm.Controls.Add($btnClearAll)
    $sForm.Controls.Add($btnRun)

    $sForm.Add_Shown({
        $sCloseBtn.Location = New-Object System.Drawing.Point(($sForm.ClientSize.Width - 52), 7)
        Set-Rounded $sForm 16
        Set-Rounded $btnSelectAll 8
        Set-Rounded $btnClearAll 8
        Set-Rounded $btnRun 8
    })

    $sForm.ShowDialog() | Out-Null
}

function Invoke-TaskWithProgress {
    param(
        [string]$Title,
        [array]$Items,
        [string]$TargetPath,
        [bool]$RunAfterDownload = $false
    )

    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null

    $syncHash = [hashtable]::Synchronized(@{
        Cancel      = $false
        Current     = $tr.Baslatiliyor
        Index       = 0
        Total       = $Items.Count
        Done        = $false
        Error       = ""
        TargetPath  = $TargetPath
    })

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions  = "ReuseThread"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("syncHash", $syncHash)
    $runspace.SessionStateProxy.SetVariable("Items", $Items)
    $runspace.SessionStateProxy.SetVariable("TargetPath", $TargetPath)
    $runspace.SessionStateProxy.SetVariable("RunAfterDownload", $RunAfterDownload)
    $runspace.SessionStateProxy.SetVariable("tr", $tr)

    $psCmd = [powershell]::Create()
    $psCmd.Runspace = $runspace
    $psCmd.AddScript({
        $client = New-Object System.Net.WebClient
        $client.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")

        for ($i = 0; $i -lt $Items.Count; $i++) {
            if ($syncHash.Cancel) { break }

            $item = $Items[$i]
            $syncHash.Current = $item.Ad
            $syncHash.Index   = $i
            $itemFolder = if ($item.Klasor) { Join-Path $TargetPath $item.Klasor } else { $TargetPath }
            New-Item -ItemType Directory -Path $itemFolder -Force | Out-Null
            $dest = Join-Path $itemFolder $item.Ad

            try {
                $client.DownloadFile($item.Url, $dest)

                if ($RunAfterDownload -and (-not $syncHash.Cancel)) {
                    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$dest`""
                }
            } catch {
                if (Test-Path $dest) {
                    try { Remove-Item $dest -Force -ErrorAction SilentlyContinue } catch {}
                }
                if (-not $syncHash.Cancel) {
                    $syncHash.Error = "$($item.Ad)"
                }
            }
        }

        try { $client.Dispose() } catch {}
        $syncHash.Done = $true
    }) | Out-Null

    $asyncResult = $psCmd.BeginInvoke()

    $pForm = New-Object System.Windows.Forms.Form
    $pForm.Size = New-Object System.Drawing.Size(560, 240)
    $pForm.StartPosition = "CenterScreen"
    $pForm.FormBorderStyle = "None"
    $pForm.BackColor = [System.Drawing.Color]::FromArgb(16, 16, 22)
    $pForm.TopMost = $true

    $pForm.Add_MouseDown({
        [Win32]::ReleaseCapture() | Out-Null
        [Win32]::SendMessage($this.Handle, 0xA1, 0x2, 0)
    })

    $pForm.Add_Paint({
        param($s, $e)
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(60, 130, 80, 200), 1)
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
        $pen.Dispose()
    })

    $titleLbl = New-Object System.Windows.Forms.Label
    $titleLbl.Text = $Title
    $titleLbl.Location = New-Object System.Drawing.Point(24, 22)
    $titleLbl.Size = New-Object System.Drawing.Size(510, 32)
    $titleLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 13)
    $titleLbl.ForeColor = [System.Drawing.Color]::FromArgb(190, 140, 255)
    $titleLbl.BackColor = [System.Drawing.Color]::Transparent
    $pForm.Controls.Add($titleLbl)

    $currentLbl = New-Object System.Windows.Forms.Label
    $currentLbl.Text = $tr.Baslatiliyor
    $currentLbl.Location = New-Object System.Drawing.Point(24, 68)
    $currentLbl.Size = New-Object System.Drawing.Size(510, 24)
    $currentLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $currentLbl.ForeColor = [System.Drawing.Color]::FromArgb(160, 140, 185)
    $currentLbl.BackColor = [System.Drawing.Color]::Transparent
    $pForm.Controls.Add($currentLbl)

    $trackPanel = New-Object System.Windows.Forms.Panel
    $trackPanel.Location = New-Object System.Drawing.Point(24, 104)
    $trackPanel.Size = New-Object System.Drawing.Size(510, 14)
    $trackPanel.BackColor = [System.Drawing.Color]::FromArgb(35, 32, 55)
    $pForm.Controls.Add($trackPanel)

    $fillPanel = New-Object System.Windows.Forms.Panel
    $fillPanel.Location = New-Object System.Drawing.Point(0, 0)
    $fillPanel.Size = New-Object System.Drawing.Size(2, 14)
    $trackPanel.Controls.Add($fillPanel)

    $fillPanel.Add_Paint({
        param($s, $e)
        if ($s.Width -lt 4) { return }
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $s.ClientRectangle,
            [System.Drawing.Color]::FromArgb(160, 100, 255),
            [System.Drawing.Color]::FromArgb(100, 55, 190),
            [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
        )
        $e.Graphics.FillRectangle($brush, $s.ClientRectangle)
        $brush.Dispose()
    })

    $countLbl = New-Object System.Windows.Forms.Label
    $countLbl.Text = "0 / $($Items.Count)"
    $countLbl.Location = New-Object System.Drawing.Point(24, 126)
    $countLbl.Size = New-Object System.Drawing.Size(510, 20)
    $countLbl.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $countLbl.ForeColor = [System.Drawing.Color]::FromArgb(100, 85, 130)
    $countLbl.BackColor = [System.Drawing.Color]::Transparent
    $countLbl.TextAlign = "MiddleRight"
    $pForm.Controls.Add($countLbl)

    $cancelBtn = New-Object System.Windows.Forms.Panel
    $cancelBtn.Size = New-Object System.Drawing.Size(120, 36)
    $cancelBtn.Location = New-Object System.Drawing.Point(220, 170)
    $cancelBtn.Cursor = "Hand"
    $cancelBtn.Tag = $false

    $cancelLbl = New-Object System.Windows.Forms.Label
    $cancelLbl.Text = $tr.Iptal
    $cancelLbl.Dock = "Fill"
    $cancelLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
    $cancelLbl.ForeColor = [System.Drawing.Color]::FromArgb(220, 100, 120)
    $cancelLbl.TextAlign = "MiddleCenter"
    $cancelLbl.BackColor = [System.Drawing.Color]::Transparent
    $cancelBtn.Controls.Add($cancelLbl)

    $cancelBtn.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        if ($s.Tag) {
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 35, 40))
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(100, 200, 80, 100), 1)
            $g.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
            $pen.Dispose()
        } else {
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50, 30, 30))
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(60, 180, 70, 90), 1)
            $g.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
            $pen.Dispose()
        }
    })

    $cancelBtn.Add_MouseEnter({ $this.Tag = $true;  $this.Invalidate() })
    $cancelBtn.Add_MouseLeave({ $this.Tag = $false; $this.Invalidate() })
    $cancelLbl.Add_MouseEnter({ $this.Parent.Tag = $true;  $this.Parent.Invalidate() })
    $cancelLbl.Add_MouseLeave({ $this.Parent.Tag = $false; $this.Parent.Invalidate() })

    $cancelBtn.Add_Click({ $syncHash.Cancel = $true })
    $cancelLbl.Add_Click({ $syncHash.Cancel = $true })

    $pForm.Controls.Add($cancelBtn)

    Set-Rounded $pForm 16
    Set-Rounded $trackPanel 7
    Set-Rounded $cancelBtn 10

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 80

    $script:closeCountdown = 0

    $timer.Add_Tick({
        if ($pForm.IsDisposed) { $timer.Stop(); return }

        $idx    = $syncHash.Index
        $total  = $syncHash.Total
        $done   = $syncHash.Done
        $cancel = $syncHash.Cancel

        $currentLbl.Text = $syncHash.Current
        $countLbl.Text   = "$($idx + 1) / $total"

        $pct  = if ($total -gt 0) { $idx / $total } else { 0 }
        $newW = [Math]::Max(2, [int]($trackPanel.Width * $pct))
        if ($fillPanel.Width -ne $newW) {
            $fillPanel.Width = $newW
            $fillPanel.Invalidate()
        }

        if ($cancel -and -not $done) { return }

        if ($cancel -and $done) {
            $currentLbl.Text = $tr.IptalEdildi
            $script:closeCountdown++
            if ($script:closeCountdown -ge 8) {
                $timer.Stop()
                if (-not $pForm.IsDisposed) { $pForm.Close() }
            }
            return
        }

        if ($done) {
            $fillPanel.Width = $trackPanel.Width
            $fillPanel.Invalidate()
            $currentLbl.Text = $tr.Tamamlandi
            $countLbl.Text   = "$total / $total"
            $script:closeCountdown++
            if ($script:closeCountdown -ge 11) {
                $timer.Stop()
                if (-not $pForm.IsDisposed) { $pForm.Close() }
                Start-Process explorer.exe $TargetPath
            }
        }
    })

    $timer.Start()
    $pForm.ShowDialog() | Out-Null

    $timer.Stop()
    $timer.Dispose()
    $syncHash.Cancel = $true

    try { $psCmd.EndInvoke($asyncResult) } catch {}
    $psCmd.Dispose()
    $runspace.Close()
    $runspace.Dispose()
}


$form = New-Object System.Windows.Forms.Form
$form.Size = New-Object System.Drawing.Size(760, 480)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor = [System.Drawing.Color]::FromArgb(16, 16, 22)
$form.ShowInTaskbar = $true

$header = New-Object System.Windows.Forms.Panel
$header.Dock = "Top"
$header.Height = 48
$header.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 34)
$form.Controls.Add($header)

$header.Add_MouseDown({
    [Win32]::ReleaseCapture() | Out-Null
    [Win32]::SendMessage($form.Handle, 0xA1, 0x2, 0)
})

# titlenin glowunun başlangıcı
# 2 yorum satırı attık hemen yapay zeka demeyin 
# yapay zeka diyenlerin 
$script:glowStep = 0
$script:glowDir  = 1

$title = New-Object System.Windows.Forms.Label
$title.Text = "TR SS Auto Downloader"
$title.Location = New-Object System.Drawing.Point(20, 0)
$title.Size = New-Object System.Drawing.Size(300, 48)
$title.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 16)
$title.TextAlign = "MiddleLeft"
$title.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 34)

$title.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $bg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(24, 24, 34))
    $g.FillRectangle($bg, 0, 0, $s.Width, $s.Height)
    $bg.Dispose()

    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment     = [System.Drawing.StringAlignment]::Near
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

    $alpha = [int](8 + ($script:glowStep / 20.0) * 55)

    foreach ($ox in @(-2, -1, 1, 2)) {
        foreach ($oy in @(-2, -1, 1, 2)) {
            $dist = [Math]::Sqrt($ox * $ox + $oy * $oy)
            $layerAlpha = [int]($alpha / $dist)
            if ($layerAlpha -lt 3) { continue }
            $glowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($layerAlpha, 168, 85, 247))
            $g.DrawString($s.Text, $s.Font, $glowBrush, [System.Drawing.RectangleF]::new($ox, $oy, $s.Width, $s.Height), $sf)
            $glowBrush.Dispose()
        }
    }

    $innerAlpha = [int]($alpha * 0.75)
    foreach ($ox in @(-1, 1)) {
        foreach ($oy in @(-1, 1)) {
            $glowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($innerAlpha, 192, 120, 255))
            $g.DrawString($s.Text, $s.Font, $glowBrush, [System.Drawing.RectangleF]::new($ox, $oy, $s.Width, $s.Height), $sf)
            $glowBrush.Dispose()
        }
    }

    $mainBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(185, 125, 255))
    $g.DrawString($s.Text, $s.Font, $mainBrush, [System.Drawing.RectangleF]::new(0, 0, $s.Width, $s.Height), $sf)
    $mainBrush.Dispose()

    $sf.Dispose()
})

$glowTimer = New-Object System.Windows.Forms.Timer
$glowTimer.Interval = 40
$glowTimer.Add_Tick({
    $script:glowStep += $script:glowDir
    if ($script:glowStep -ge 20) { $script:glowDir = -1 }
    if ($script:glowStep -le 0)  { $script:glowDir =  1 }
    if ($null -ne $script:titleRef -and -not $script:titleRef.IsDisposed) {
        $script:titleRef.Invalidate()
    }
})

$script:titleRef = $title
$header.Controls.Add($title)

$form.Add_Shown({ $glowTimer.Start() })
$form.Add_FormClosing({ $glowTimer.Stop(); $glowTimer.Dispose() })
# glow bitiştir
function New-WindowButton($iconChar, $hoverColor, $action) {
    $btn = New-Object System.Windows.Forms.Panel
    $btn.Size = New-Object System.Drawing.Size(50, 34)
    $btn.Cursor = "Hand"
    $btn.BackColor = [System.Drawing.Color]::FromArgb(28, 26, 44)
    $btn.Tag = @{ Hovered = $false; HoverColor = $hoverColor }

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $iconChar
    $lbl.Dock = "Fill"
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(155, 135, 180)
    $lbl.TextAlign = "MiddleCenter"
    $lbl.BackColor = [System.Drawing.Color]::FromArgb(28, 26, 44)
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 13)

    $btn.Controls.Add($lbl)

    $btn.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $hc = $s.Tag.HoverColor
        if ($s.Tag.Hovered) {
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50, $hc.R, $hc.G, $hc.B))
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, $hc.R, $hc.G, $hc.B), 1)
            $g.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
            $pen.Dispose()
        } else {
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(28, 26, 44))
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
        }
    })

    $btn.Add_MouseEnter({
        $this.Tag.Hovered = $true
        $hc = $this.Tag.HoverColor
        foreach ($c in $this.Controls) {
            $c.ForeColor = [System.Drawing.Color]::FromArgb(255, [Math]::Min(255, $hc.R + 160), [Math]::Min(255, $hc.G + 150), 255)
            $c.BackColor = [System.Drawing.Color]::Transparent
        }
        $this.Invalidate()
    })
    $btn.Add_MouseLeave({
        $this.Tag.Hovered = $false
        foreach ($c in $this.Controls) {
            $c.ForeColor = [System.Drawing.Color]::FromArgb(155, 135, 180)
            $c.BackColor = [System.Drawing.Color]::FromArgb(28, 26, 44)
        }
        $this.Invalidate()
    })
    $lbl.Add_MouseEnter({
        $p = $this.Parent
        $p.Tag.Hovered = $true
        $hc = $p.Tag.HoverColor
        $this.ForeColor = [System.Drawing.Color]::FromArgb(255, [Math]::Min(255, $hc.R + 160), [Math]::Min(255, $hc.G + 150), 255)
        $this.BackColor = [System.Drawing.Color]::Transparent
        $p.Invalidate()
    })
    $lbl.Add_MouseLeave({
        $p = $this.Parent
        $p.Tag.Hovered = $false
        $this.ForeColor = [System.Drawing.Color]::FromArgb(155, 135, 180)
        $this.BackColor = [System.Drawing.Color]::FromArgb(28, 26, 44)
        $p.Invalidate()
    })

    $btn.Add_Click($action)
    $lbl.Add_Click($action)

    $header.Controls.Add($btn)
    return $btn
}

$btnClose = New-WindowButton "x" ([System.Drawing.Color]::FromArgb(210, 60, 80))  { $form.Close() }
$btnMin   = New-WindowButton "_" ([System.Drawing.Color]::FromArgb(130, 80, 210)) { $form.WindowState = "Minimized" }

$buttons = @()
function New-PurpleButton($text, $top, $action) {
    $btn = New-Object System.Windows.Forms.Panel
    $btn.Size = New-Object System.Drawing.Size(360, 48)
    $btn.Location = New-Object System.Drawing.Point(200, $top)
    $btn.Cursor = "Hand"
    $btn.BackColor = [System.Drawing.Color]::FromArgb(34, 34, 52)
    $btn.Tag = $false

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $text
    $lbl.Dock = "Fill"
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI Variable Display Semib", 11)
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(220, 185, 255)
    $lbl.TextAlign = "MiddleCenter"
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    $btn.Controls.Add($lbl)

    $btn.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

        if ($s.Tag -eq $true) {
            $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                $s.ClientRectangle,
                [System.Drawing.Color]::FromArgb(75, 45, 130),
                [System.Drawing.Color]::FromArgb(110, 65, 175),
                [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
            )
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()

            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(80, 160, 100, 255), 1)
            $g.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
            $pen.Dispose()
        } else {
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(34, 34, 52))
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
        }
    })

    $btn.Add_MouseEnter({
        $this.Tag = $true
        $this.Invalidate()
        foreach ($child in $this.Controls) { $child.Invalidate() }
    })
    $btn.Add_MouseLeave({
        $this.Tag = $false
        $this.Invalidate()
        foreach ($child in $this.Controls) { $child.Invalidate() }
    })

    $lbl.Add_MouseEnter({ $this.Parent.Tag = $true;  $this.Parent.Invalidate(); $this.Invalidate() })
    $lbl.Add_MouseLeave({ $this.Parent.Tag = $false; $this.Parent.Invalidate(); $this.Invalidate() })

    if ($action) {
        $btn.Add_Click($action)
        $lbl.Add_Click($action)
    }

    $form.Controls.Add($btn)
    $script:buttons += $btn
    return $btn
}

$downloadsPath = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path

New-PurpleButton "SS Tools" 120 {
$dosyalar = @(
        @{ Url = "https://www.nirsoft.net/utils/winprefetchview-x64.zip"; Ad = "WinPrefetchView_x64.zip"; Klasor = "NirSoft" }
        @{ Url = "https://www.nirsoft.net/utils/lastactivityview.zip"; Ad = "LastActivityView.zip"; Klasor = "NirSoft" }
        @{ Url = "https://www.nirsoft.net/utils/usbdrivelog.zip"; Ad = "UsbDriveLog.zip"; Klasor = "NirSoft" }
        @{ Url = "https://www.nirsoft.net/utils/windeflogview.zip"; Ad = "WinDefLogView.zip"; Klasor = "NirSoft" }
        @{ Url = "https://www.nirsoft.net/utils/shellbagsview.zip"; Ad = "ShellBagsView.zip"; Klasor = "NirSoft" }
        @{ Url = "https://www.nirsoft.net/utils/uninstallview-x64.zip"; Ad = "UninstallView_x64.zip"; Klasor = "NirSoft" }
        @{ Url = "https://www.nirsoft.net/utils/loadeddllsview-x64.zip"; Ad = "LoadedDllsView_x64.zip"; Klasor = "NirSoft" }
        @{ Url = "https://www.nirsoft.net/utils/jumplistsview.zip"; Ad = "JumpListsView.zip"; Klasor = "NirSoft" }
        @{ Url = "https://www.nirsoft.net/utils/clipboardic.zip"; Ad = "Clipboardic.zip"; Klasor = "NirSoft" }

        @{ Url = "https://download.ericzimmermanstools.com/net9/TimelineExplorer.zip"; Ad = "TimelineExplorer.zip"; Klasor = "EricZimmerman" }
        @{ Url = "https://download.ericzimmermanstools.com/SrumECmd.zip"; Ad = "SrumECmd.zip"; Klasor = "EricZimmerman" }
        @{ Url = "https://download.ericzimmermanstools.com/AmcacheParser.zip"; Ad = "AmcacheParser.zip"; Klasor = "EricZimmerman" }
        @{ Url = "https://download.ericzimmermanstools.com/net6/WxTCmd.zip"; Ad = "WxTCmd.zip"; Klasor = "EricZimmerman" }
        @{ Url = "https://download.ericzimmermanstools.com/net9/RegistryExplorer.zip"; Ad = "RegistryExplorer.zip"; Klasor = "EricZimmerman" }
        @{ Url = "https://download.ericzimmermanstools.com/net9/MFTECmd.zip"; Ad = "MFTECmd.zip"; Klasor = "EricZimmerman" }

        @{ Url = "https://github.com/spokwn/BAM-parser/releases/download/v1.2.9/BAMParser.exe"; Ad = "BAMParser.exe"; Klasor = "Spokwn" }
        @{ Url = "https://github.com/spokwn/prefetch-parser/releases/download/v1.5.5/PrefetchParser.exe"; Ad = "PrefetchParser.exe"; Klasor = "Spokwn" }
        @{ Url = "https://github.com/spokwn/process-parser/releases/download/v0.5.5/ProcessParser.exe"; Ad = "ProcessParser.exe"; Klasor = "Spokwn" }
        @{ Url = "https://github.com/spokwn/pcasvc-executed/releases/download/v0.8.7/PcaSvcExecuted.exe"; Ad = "PcaSvcExecuted.exe"; Klasor = "Spokwn" }
        @{ Url = "https://github.com/spokwn/JournalTrace/releases/download/1.2/JournalTraceNormal.exe"; Ad = "JournalTraceNormal.exe"; Klasor = "Spokwn" }
        @{ Url = "https://github.com/spokwn/PathsParser/releases/download/v1.2/PathsParser.exe"; Ad = "PathsParser.exe"; Klasor = "Spokwn" }
        @{ Url = "https://github.com/spokwn/KernelLiveDumpTool/releases/download/v1.1/KernelLiveDumpTool.exe"; Ad = "KernelLiveDumpTool.exe"; Klasor = "Spokwn" }
        @{ Url = "https://github.com/spokwn/Tool/releases/download/v1.1.2/espouken.exe"; Ad = "espouken.exe"; Klasor = "Spokwn" }
        @{ Url = "https://github.com/spokwn/BamDeletedKeys/releases/download/v1.0/BamDeletedKeys.exe"; Ad = "BamDeletedKeys.exe"; Klasor = "Spokwn" }

        @{ Url = "https://dl.echo.ac/tool/journal"; Ad = "Journal.exe"; Klasor = "Echo" }
        @{ Url = "https://dl.echo.ac/tool/userassist"; Ad = "UserAssist.exe"; Klasor = "Echo" }
        @{ Url = "https://dl.echo.ac/tool/usb"; Ad = "UsbTool.exe"; Klasor = "Echo" }

        @{ Url = "https://github.com/ItzIceHere/RedLotus-Mod-Analyzer/releases/download/RL/RedLotusModAnalyzer.exe"; Ad = "RedLotusModAnalyzer.exe"; Klasor = "RedLotus" }
        @{ Url = "https://github.com/ItzIceHere/RedLotus-Task-Sentinel/releases/download/RL/RedLotusTaskSentinel.exe"; Ad = "RedLotusTaskSentinel.exe"; Klasor = "RedLotus" }

        @{ Url = "https://github.com/trSScommunity/PathDuzenleyiciV2/raw/refs/heads/main/PathDuzenleyicisiV2.exe"; Ad = "PathDuzenleyicisiV2.exe"; Klasor = "TRSSCommunity" }
        @{ Url = "https://github.com/trSScommunity/MZHunter/raw/refs/heads/main/MzHunter.exe"; Ad = "MzHunter.exe"; Klasor = "TRSSCommunity" }

        @{ Url = "https://go.magnetforensics.com/e/52162/MagnetEncryptedDiskDetector/kpt9bg/1663239667/h/LtXFtTL-Soawv5C1oL3BIEghi7e1Lx93yesZLR--Ok0"; Ad = "MagnetEncryptedDiskDetector.exe"; Klasor = "Magnet" }
        @{ Url = "https://go.magnetforensics.com/e/52162/mail-utm-campaign-UTMC-0000044/llr4bg/1663358653/h/4kZ9Y4i2yPRqBzuQMrywA_v5bfkpG3rG8gEiSWrYU70"; Ad = "Magnet_tool.html"; Klasor = "Magnet" }

        @{ Url = "https://archive.org/download/access-data-ftk-imager-4.7.1/AccessData_FTK_Imager_4.7.1.exe"; Ad = "FTK_Imager_4.7.1.exe"; Klasor = "Forensics" }
        @{ Url = "https://github.com/Yamato-Security/hayabusa/releases/download/v3.6.0/hayabusa-3.6.0-win-aarch64.zip"; Ad = "hayabusa-3.6.0-win-aarch64.zip"; Klasor = "Forensics" }
        @{ Url = "https://github.com/Velocidex/velociraptor/releases/download/v0.75/velociraptor-v0.75.1-windows-amd64.exe"; Ad = "Velociraptor.exe"; Klasor = "Forensics" }

        @{ Url = "https://github.com/winsiderss/si-builds/releases/download/3.2.25275.112/systeminformer-build-canary-setup.exe"; Ad = "SystemInformer_Canary_Setup.exe"; Klasor = "SystemTools" }
        @{ Url = "https://www.voidtools.com/Everything-1.4.1.1029.x86-Setup.exe"; Ad = "Everything-Setup.exe"; Klasor = "SystemTools" }
        @{ Url = "https://win.cleverfiles.com/disk-drill-win5-full.exe"; Ad = "DiskDrill_win5_full.exe"; Klasor = "SystemTools" }

        @{ Url = "https://github.com/NotRequiem/InjGen/releases/download/v2.0/InjGen.exe"; Ad = "InjGen.exe"; Klasor = "Analysis" }
        @{ Url = "https://github.com/deathmarine/Luyten/releases/download/v0.5.4_Rebuilt_with_Latest_depenencies/luyten-0.5.4.exe"; Ad = "Luyten.exe"; Klasor = "Analysis" }
        @{ Url = "https://github.com/nay-cat/dpsanalyzer/releases/download/1.3/dpsanalyzer.exe"; Ad = "dpsanalyzer.exe"; Klasor = "Analysis" }
        @{ Url = "https://github.com/horsicq/DIE-engine/releases/download/3.09/die_win64_portable_3.09_x64.zip"; Ad = "DIE_engine_portable.zip"; Klasor = "Analysis" }
        @{ Url = "https://downloads.appsvoid.com/latest/stream-detector/setup"; Ad = "StreamDetector_Setup.exe"; Klasor = "Analysis" }

        @{ Url = "https://github.com/nay-cat/Jarabel/releases/download/light/Jarabel.Light.exe"; Ad = "Jarabel.Light.exe"; Klasor = "Misc" }
        @{ Url = "https://github.com/RRancio/Exec/raw/main/Files/Unicode.exe"; Ad = "Unicode.exe"; Klasor = "Misc" }
        @{ Url = "https://github.com/ponei/CachedProgramsList/releases/download/1.1/CachedProgramsList.exe"; Ad = "CachedProgramsList.exe"; Klasor = "Misc" }
        @{ Url = "https://github.com/santiagolin/TimeChangeDetect/releases/download/1.0/TimeChangeDetect.exe"; Ad = "TimeChangeDetect.exe"; Klasor = "Misc" }
    )

    $target = Join-Path $downloadsPath "ScreenShareTools"
    Invoke-TaskWithProgress -Title "TR SS Tools indiriliyor..." -Items $dosyalar -TargetPath $target -ActionPerItem {
        param($item, $path)
        $kayitYolu = Join-Path $path $item.Ad
        Invoke-WebRequest -Uri $item.Url -OutFile $kayitYolu -UseBasicParsing -TimeoutSec 120 -UserAgent "Mozilla/5.0"
    }
}

New-PurpleButton "TR SS PowerShell Scripts" 175 {
    $psScripts = @(
        @{ Url = "https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/Drive-Executions.ps1"; Ad = "Drive-Executions.ps1" }
        @{ Url = "https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/Services.ps1"; Ad = "Services.ps1" }
        @{ Url = "https://raw.githubusercontent.com/spokwn/powershells/refs/heads/main/Streams.ps1"; Ad = "Streams.ps1" }
        @{ Url = "https://raw.githubusercontent.com/bacanoicua/Screenshare/main/RedLotusPrefetchIntegrityAnalyzer.ps1"; Ad = "RedLotusPrefetchIntegrityAnalyzer.ps1" }
        @{ Url = "https://raw.githubusercontent.com/trSScommunity/BaglantiAnalizi/refs/heads/main/BaglantiAnalizi.ps1"; Ad = "BaglantiAnalizi.ps1" }
        @{ Url = "https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/DoomsdayFinder.ps1"; Ad = "DoomsdayFinder.ps1" }
    )
    Show-ScriptSelector -Scripts $psScripts
}

New-PurpleButton "Soon..." 230 $null
New-PurpleButton "Soon..." 285 $null
New-PurpleButton "Soon..." 340 $null

$form.Add_Shown({
    $btnClose.Location = New-Object System.Drawing.Point(($form.ClientSize.Width - 58), 7)
    $btnMin.Location   = New-Object System.Drawing.Point(($form.ClientSize.Width - 114), 7)
    Set-Rounded $form 18
    Set-Rounded $btnClose 10
    Set-Rounded $btnMin   10
    foreach ($b in $buttons) { Set-Rounded $b 14 }
})

[void]$form.ShowDialog()