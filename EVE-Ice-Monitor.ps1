param([string]$DataDirectory=$PSScriptRoot,[switch]$NoRun)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$ErrorActionPreference='Stop'
[Threading.Thread]::CurrentThread.CurrentCulture=[Globalization.CultureInfo]::GetCultureInfo('en-US')
[Threading.Thread]::CurrentThread.CurrentUICulture=[Globalization.CultureInfo]::GetCultureInfo('en-US')
. (Join-Path $PSScriptRoot 'EVE-Mining-Core.ps1')
. (Join-Path $PSScriptRoot 'EVE-Mining-AppCore.ps1')
. (Join-Path $PSScriptRoot 'EVE-Mining-Activity.ps1')
. (Join-Path $PSScriptRoot 'EVE-Mining-Alerts.ps1')
. (Join-Path $PSScriptRoot 'EVE-Mining-ETA.ps1')
. (Join-Path $PSScriptRoot 'EVE-Mining-FleetSpace.ps1')
$script:dataDirectory=$DataDirectory
$null=New-Item -ItemType Directory -Path $DataDirectory -Force
$script:statePath=Join-Path $DataDirectory 'EVE-Ice-Monitor.state.json'
$script:pricePath=Join-Path $DataDirectory 'EVE-Mining-Prices.json'
$script:volumes=@{}
try {
    $data=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'EVE-Mining-Volumes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($item in $data.Items) {$script:volumes[$item.Name]=$item}
    Initialize-Monitor
} catch { [Windows.Forms.MessageBox]::Show('Cannot load monitor files or saved state: '+$_.Exception.Message) | Out-Null; exit 1 }
$script:rows=@{};$script:loading=$false;$script:trend=@();$script:headlineUpdated=[datetime]::MinValue
$bg=[Drawing.Color]::FromArgb(16,22,29)
$muted=[Drawing.Color]::FromArgb(143,160,181)
$accent=[Drawing.Color]::FromArgb(100,232,178)
function New-Label($Parent,$Text,$X,$Y,$Width,$Height=22) {
    $l=New-Object Windows.Forms.Label;$l.Text=$Text;$l.SetBounds($X,$Y,$Width,$Height);$l.BackColor=$Parent.BackColor;$l.ForeColor=[Drawing.Color]::WhiteSmoke
    $Parent.Controls.Add($l);return $l
}
function New-Button($Parent,$Text,$X,$Y,$Width,$Height=26) {
    $b=New-Object Windows.Forms.Button;$b.Text=$Text;$b.SetBounds($X,$Y,$Width,$Height)
    $b.FlatStyle='Flat';$b.FlatAppearance.BorderColor=[Drawing.Color]::FromArgb(55,69,84);$b.BackColor=[Drawing.Color]::FromArgb(30,39,50);$b.ForeColor=[Drawing.Color]::WhiteSmoke
    $Parent.Controls.Add($b);return $b
}
function Set-GridStyle($Grid) {
    $Grid.BackgroundColor=$bg;$Grid.BorderStyle='None';$Grid.AutoGenerateColumns=$false
    $Grid.RowHeadersVisible=$false;$Grid.AllowUserToResizeRows=$false;$Grid.SelectionMode='FullRowSelect'
    $Grid.DefaultCellStyle.BackColor=[Drawing.Color]::FromArgb(28,36,46)
    $Grid.DefaultCellStyle.ForeColor=[Drawing.Color]::WhiteSmoke
    $Grid.DefaultCellStyle.SelectionBackColor=[Drawing.Color]::FromArgb(49,76,96)
    $Grid.DefaultCellStyle.SelectionForeColor=[Drawing.Color]::White
    $Grid.ColumnHeadersDefaultCellStyle.BackColor=[Drawing.Color]::FromArgb(35,46,59)
    $Grid.ColumnHeadersDefaultCellStyle.ForeColor=[Drawing.Color]::White
    $Grid.EnableHeadersVisualStyles=$false;$Grid.GridColor=[Drawing.Color]::FromArgb(46,56,69)
    $Grid.Add_DataError({})
}
function Add-TextColumn($Grid,$Name,$Header,$Width,[bool]$ReadOnly=$false) {
    $c=New-Object Windows.Forms.DataGridViewTextBoxColumn;$c.Name=$Name;$c.HeaderText=$Header;$c.Width=$Width;$c.ReadOnly=$ReadOnly;$null=$Grid.Columns.Add($c)
}
function Format-ISK([double]$Value) {
    if ([math]::Abs($Value) -ge 1000000000) {return ('{0:N2} B' -f ($Value/1000000000))}
    return ('{0:N2} M' -f ($Value/1000000))
}
$form=New-Object Windows.Forms.Form
$iconPath=Join-Path $PSScriptRoot 'EVE-Mining.ico';if (Test-Path -LiteralPath $iconPath) {$form.Icon=New-Object Drawing.Icon($iconPath)}
$form.Text='EVE Mining v1.0';$form.BackColor=$bg;$form.ForeColor=[Drawing.Color]::WhiteSmoke
$form.Font=New-Object Drawing.Font('Segoe UI',9);$form.FormBorderStyle='FixedSingle';$form.MaximizeBox=$false;$form.StartPosition='CenterScreen';$form.TopMost=$script:topMost
$null=New-Label $form 'MINING INCOME - ESTIMATE' 12 10 245
$settings=New-Button $form 'Fleet / prices' 350 7 128
$headline=New-Label $form '0.00 M ISK/h' 12 34 470 38
$headline.Font=New-Object Drawing.Font('Segoe UI',22,[Drawing.FontStyle]::Bold);$headline.ForeColor=$accent
$fleetSpace=New-Label $form '' 270 38 208 36
$fleetSpace.Font=New-Object Drawing.Font('Segoe UI',8);$fleetSpace.TextAlign='TopRight';$fleetSpace.ForeColor=$muted
$summary=New-Label $form '' 12 76 470 20
$priceInfo=New-Label $form '' 12 98 470 19;$priceInfo.Font=New-Object Drawing.Font('Segoe UI',8);$priceInfo.ForeColor=$muted
$chart=New-Object Windows.Forms.Panel;$chart.SetBounds(12,122,466,50);$chart.BackColor=[Drawing.Color]::FromArgb(12,18,25);$form.Controls.Add($chart)
$chart.Add_Paint({
    param($sender,$eventArgs)
    $g=$eventArgs.Graphics;$pen=New-Object Drawing.Pen([Drawing.Color]::FromArgb(62,87,106),1)
    $g.DrawLine($pen,0,($sender.Height-2),$sender.Width,($sender.Height-2));$pen.Dispose()
    $v=$script:trend;if ($null -eq $v -or $v.Count -lt 2) {return}
    $max=[math]::Max([double]1,[double](($v | Measure-Object -Maximum).Maximum))
    $points=New-Object 'Drawing.PointF[]' $v.Count
    for ($i=0;$i -lt $v.Count;$i++) {$points[$i]=New-Object Drawing.PointF(([single](4+$i*($sender.Width-8)/($v.Count-1))),([single]($sender.Height-5-$v[$i]/$max*($sender.Height-12))))}
    $pen=New-Object Drawing.Pen($accent,1.6);$g.DrawLines($pen,$points);$pen.Dispose()
})
$trendCaption=New-Label $form '10 MIN TREND - estimated ISK/h per minute' 12 176 470 18;$trendCaption.Font=New-Object Drawing.Font('Segoe UI',8);$trendCaption.ForeColor=$muted
$profileBox=New-Object Windows.Forms.ComboBox;$profileBox.DropDownStyle='DropDownList';$profileBox.SetBounds(12,200,230,25);$form.Controls.Add($profileBox)
$modeBox=New-Object Windows.Forms.ComboBox;$modeBox.DropDownStyle='DropDownList';$modeBox.SetBounds(252,200,75,25);$null=$modeBox.Items.AddRange(@('ICE','ORE'));$form.Controls.Add($modeBox)
$resetAll=New-Button $form 'Reset all' 337 198 141
$fleetPanel=New-Object Windows.Forms.Panel;$fleetPanel.SetBounds(12,236,466,100);$fleetPanel.AutoScroll=$true;$fleetPanel.BackColor=$bg;$form.Controls.Add($fleetPanel)
$sessionReset=New-Button $form 'New session' 12 0 108
$pauseButton=New-Button $form 'Pause session' 12 0 155
$compactButton=New-Button $form 'Expand' 128 0 80
$topCheck=New-Object Windows.Forms.CheckBox;$topCheck.Text='On top';$topCheck.Checked=$script:topMost;$topCheck.AutoSize=$true;$form.Controls.Add($topCheck)
$soundCheck=New-Object Windows.Forms.CheckBox;$soundCheck.Text='Attack sound';$soundCheck.Checked=$script:attackSound;$soundCheck.AutoSize=$true;$form.Controls.Add($soundCheck)
$status=New-Label $form '' 12 0 466 36;$status.Font=New-Object Drawing.Font('Segoe UI',8);$status.ForeColor=$muted
$tooltip=New-Object Windows.Forms.ToolTip;$tooltip.AutoPopDelay=15000
$corpLogo=New-Object Windows.Forms.PictureBox;$corpLogo.SizeMode='Zoom';$corpLogo.BackColor=$bg;$form.Controls.Add($corpLogo)
$logoPath=Join-Path $PSScriptRoot 'Corp-Logo.png';if (Test-Path -LiteralPath $logoPath) {$corpLogo.Image=[Drawing.Image]::FromFile($logoPath)}
$credit=New-Label $form 'Tool created by Marcel Ijonen [NO.W8]' 48 0 350 18;$credit.Font=New-Object Drawing.Font('Segoe UI',8);$credit.ForeColor=$muted
$setupLink=New-Label $form 'Quick setup' 48 0 110 18;$setupLink.Font=New-Object Drawing.Font('Segoe UI',8,[Drawing.FontStyle]::Underline);$setupLink.ForeColor=$accent;$setupLink.Cursor=[Windows.Forms.Cursors]::Hand
$versionLabel=New-Label $form 'v1.0' 420 0 58 20;$versionLabel.TextAlign='MiddleRight';$versionLabel.ForeColor=$muted
function Show-QuickSetup([Windows.Forms.Form]$Owner=$form) {
    $dialog=New-Object Windows.Forms.Form;$dialog.Text='EVE Mining 1.0 - Quick setup';$dialog.ClientSize=New-Object Drawing.Size(640,500)
    $dialog.BackColor=$bg;$dialog.ForeColor=[Drawing.Color]::WhiteSmoke;$dialog.Font=$form.Font;$dialog.Icon=$form.Icon;$dialog.StartPosition='CenterParent';$dialog.FormBorderStyle='FixedDialog';$dialog.MaximizeBox=$false;$dialog.MinimizeBox=$false
    $logo=New-Object Windows.Forms.PictureBox;$logo.SetBounds(20,16,84,84);$logo.SizeMode='Zoom';$logo.Image=$corpLogo.Image;$dialog.Controls.Add($logo)
    $title=New-Label $dialog 'EVE Mining 1.0' 120 18 490 32;$title.Font=New-Object Drawing.Font('Segoe UI',18,[Drawing.FontStyle]::Bold);$title.ForeColor=$accent
    $null=New-Label $dialog 'Tool created by Marcel Ijonen [NO.W8]' 120 55 490 22
    $pricesText='Default BUY prices are included. Update them later via Janice.'
    if ($script:defaultPriceDate) {$pricesText='BUY price snapshot: '+$script:defaultPriceDate+' UTC. Prices are not live.'}
    $priceLabel=New-Label $dialog $pricesText 120 80 490 35;$priceLabel.Font=New-Object Drawing.Font('Segoe UI',8);$priceLabel.ForeColor=$muted
    $steps=@"
1. Open Fleet / prices and select your EVE Gamelogs folder.
2. Click Add pilots from logs to import your characters.
3. Select each pilot's ship class.
4. Enter the actual in-game cargo capacity (including your skills).
5. Set Lasers: usually 2 for barges/exhumers, 0 for a boost-only ship.
6. Raw cycle (s): enter the slower unboosted cycle, or 0 for auto.
7. Give the profile a name, choose ICE / ORE, then Save and activate.
8. Confirm the starting cargo: Reset if empty; otherwise right-click
   a pilot to set or confirm its current cargo.

EVE mining/combat messages must be in English.
The included BUY prices let you start immediately; no login is needed.
"@
    $instructions=New-Label $dialog $steps 20 125 605 305;$instructions.Font=New-Object Drawing.Font('Segoe UI',10)
    $configure=New-Button $dialog 'Open fleet settings' 20 455 185;$configure.DialogResult='Yes'
    if ($Owner -ne $form) {$configure.Text='Back to fleet settings'}
    $close=New-Button $dialog 'Close' 500 455 120;$close.DialogResult='Cancel';$dialog.CancelButton=$close
    $result=$dialog.ShowDialog($Owner);$dialog.Dispose()
    if ($result -eq 'Yes' -and $Owner -eq $form) {Show-Settings}
}
$setupLink.Add_Click({Show-QuickSetup $form});$corpLogo.Cursor=[Windows.Forms.Cursors]::Hand;$corpLogo.Add_Click({Show-QuickSetup $form})
function Sync-ProfileBoxes {
    $script:loading=$true
    $profileBox.Items.Clear()
    foreach ($p in $script:profiles) {$null=$profileBox.Items.Add($p.Name)}
    if ($script:activeProfile) {$profileBox.SelectedItem=$script:activeProfile}
    $modeBox.SelectedItem=$script:mode
    $script:loading=$false
}
function Build-Rows {
    foreach ($c in @($fleetPanel.Controls)) {$c.Dispose()};$fleetPanel.Controls.Clear();$script:rows=@{}
    $members=@(Get-Members);$height=if ($script:compact) {44} else {80}
    $width=if ($script:compact) {466} else {826}
    $visibleHeight=[math]::Max(72,[math]::Min(430,$members.Count*$height))
    $profileTop=if ($script:compact) {180} else {200}
    $fleetTop=$profileTop+36
    $form.ClientSize=New-Object Drawing.Size(($width+24),($fleetTop+$visibleHeight+116))
    $chart.Height=if ($script:compact) {32} else {50}
    $trendCaption.Top=if ($script:compact) {158} else {176}
    $profileBox.Top=$profileTop;$modeBox.Top=$profileTop;$resetAll.Top=$profileTop-2
    $fleetPanel.Top=$fleetTop
    $chart.Width=$width;$headline.Width=$width-220;$summary.Width=$width;$priceInfo.Width=$width;$trendCaption.Width=$width
    $fleetSpace.Left=$width+12-208
    $settings.Left=$width+12-$settings.Width;$resetAll.Left=$width+12-$resetAll.Width
    $fleetPanel.Size=New-Object Drawing.Size($width,$visibleHeight)
    $fleetPanel.AutoScrollMinSize=New-Object Drawing.Size(0,($members.Count*$height))
    $rowWidth=$width-20
    $y=0
    foreach ($m in $members) {
        $n=$m.Character
        $name=New-Label $fleetPanel ($n+' - '+$m.ShipClass) 0 $y ($rowWidth-65) 20
        $name.AutoEllipsis=$true;$name.Font=New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Bold)
        $reset=New-Button $fleetPanel 'Reset' ($rowWidth-58) $y 58 23;$reset.Tag=$n
        $reset.Add_Click({try {Poll-Logs;Reset-Cargo $script:ships[$this.Tag];Update-Rows;Save-State} catch {$script:notice=$_.Exception.Message}})
        $barTop=if ($script:compact) {18} else {22}
        $track=New-Object Windows.Forms.Panel;$track.SetBounds(0,($y+$barTop),($rowWidth-65),6);$track.BackColor=[Drawing.Color]::FromArgb(47,58,71)
        $fill=New-Object Windows.Forms.Panel;$fill.SetBounds(0,0,0,6);$track.Controls.Add($fill);$fleetPanel.Controls.Add($track)
        $cargoTop=if ($script:compact) {25} else {32}
        $cargo=New-Label $fleetPanel '' 0 ($y+$cargoTop) $rowWidth 18;$cargo.Font=New-Object Drawing.Font('Segoe UI',8)
        $details=$null;if (-not $script:compact) {$details=New-Label $fleetPanel '' 0 ($y+52) $rowWidth 23;$details.Font=New-Object Drawing.Font('Segoe UI',8)}
        $menu=New-Object Windows.Forms.ContextMenuStrip
        $set=$menu.Items.Add('Set current cargo...');$set.Tag=$n;$set.Add_Click({Show-CargoDialog ([string]$this.Tag)})
        $confirm=$menu.Items.Add('Confirm displayed cargo');$confirm.Tag=$n
        $confirm.Add_Click({try {Poll-Logs;$s=$script:ships[$this.Tag];if ($s.Unknown) {throw 'Correct this cargo with Set current cargo first.'};$s.Known=$true;Update-Rows;Save-State} catch {$script:notice=$_.Exception.Message}})
        $name.ContextMenuStrip=$menu;$track.ContextMenuStrip=$menu;$cargo.ContextMenuStrip=$menu
        $script:rows[$n]=@{Name=$name;Track=$track;Fill=$fill;Cargo=$cargo;Details=$details;Reset=$reset;Menu=$menu}
        $y+=$height
    }
    if (-not $members.Count) {$null=New-Label $fleetPanel 'No active pilots. Open Fleet / prices to create a fleet.' 0 12 ($rowWidth) 50}
    $bottom=$fleetTop+$visibleHeight+8
    $sessionReset.Top=$bottom;$compactButton.Top=$bottom;$compactButton.Text=if ($script:compact) {'Expand'} else {'Compact'}
    $topCheck.SetBounds(220,($bottom+4),95,24);$status.SetBounds(12,($bottom+32),$width,39)
    $soundCheck.SetBounds(315,($bottom+4),145,24)
    $pauseButton.Top=$bottom+32;$status.SetBounds(180,($bottom+32),($width-168),39)
    $corpLogo.SetBounds(12,($bottom+74),28,28);$credit.SetBounds(48,($bottom+72),($width-110),18)
    $setupLink.Top=$bottom+88;$versionLabel.SetBounds(($width-46),($bottom+80),58,20)
}
function Update-Rows {
    foreach ($m in Get-Members) {
        $n=$m.Character;$s=$script:ships[$n];$r=$script:rows[$n];if (-not $r) {continue}
        $ratio=[double]($s.Volume/$s.Capacity);$r.Fill.Width=[int][math]::Round($r.Track.Width*[math]::Min([double]1,[math]::Max([double]0,$ratio)))
        $color=Get-CargoColor $s $script:mode
        $r.Fill.BackColor=switch ($color) {'Red' {[Drawing.Color]::FromArgb(235,75,75)} 'Yellow' {[Drawing.Color]::FromArgb(255,210,55)} default {[Drawing.Color]::FromArgb(58,190,120)}}
        $free=[math]::Max([decimal]0,($s.Capacity-$s.Volume));$flag=''
        if (-not $s.Known) {$flag='VERIFY CARGO | '};if ($s.Unknown) {$flag='UNCOUNTED | '}
        $warning=Get-ActivityWarning $m
        $attack=Get-AttackMessage $n
        if ($warning) {$flag='IRREGULAR | '+$flag}
        if ($color -eq 'Yellow') {$flag='CRIT | '+$flag};if ($color -eq 'Red') {$flag='95%+ | '+$flag}
        if ($attack) {$flag='ATTACK | '+$flag}
        $r.Name.ForeColor=if ($attack) {[Drawing.Color]::Salmon} else {[Drawing.Color]::WhiteSmoke}
        $r.Cargo.Text=('{0}{1:N0} / {2:N0} m3 ({3:P0})' -f $flag,$s.Volume,$s.Capacity,$ratio)
        if ($script:mode -eq 'ICE') {$r.Cargo.Text+=(' | {0:N0} blocks fit' -f [math]::Floor($free/1000))}
        $eta=Get-CargoEta $m
        $r.Cargo.Text+=' | '+$eta.Text
        $r.Cargo.ForeColor=if ($s.Known -and -not $s.Unknown -and -not $warning) {$muted} else {[Drawing.Color]::Orange}
        $income=Get-Income $n
        $detail=('{0:N2} m3 free | Session {1} ISK | Last: {2}' -f $free,(Format-ISK $income.Value),$s.Last)
        if ($s.Unknown) {$detail='Uncounted material: '+$s.Unknown+'; correct cargo manually.'}
        if ($warning) {$detail=$warning+' | '+$detail}
        $cycleNote=Get-CycleNote $m
        if ($r.Details) {$r.Details.Text=$detail;if ($cycleNote) {$r.Details.Text=$cycleNote}}
        $tip=$detail+"`n"+$eta.Note+"`n"+$cycleNote+"`n"+$attack+"`nRight-click to set cargo. Reset after transfer / jettison."
        if (-not $s.Known -and -not $s.Unknown) {$tip="Cargo start value is unconfirmed; this is not an irregular-mining warning.`nRight-click > Confirm displayed cargo if the amount matches EVE.`n"+$tip}
        $tooltip.SetToolTip($r.Name,$tip);$tooltip.SetToolTip($r.Cargo,$tip)
    }
    $income=Get-Income
    $paused=Test-SessionPaused
    $pauseButton.Text=if ($paused) {'Resume session'} else {'Pause session'}
    $headline.ForeColor=if ($paused) {$muted} else {$accent}
    $space=Get-FleetFreeSpace;$fleetSpace.Text=$space.Text
    $fleetSpace.ForeColor=if ($space.Unconfirmed) {[Drawing.Color]::Orange} else {$accent}
    $tooltip.SetToolTip($fleetSpace,$space.Note)
    if (([datetime]::UtcNow-$script:headlineUpdated).TotalSeconds -ge 60) {
        $headline.Text=(Format-ISK $income.Rate)+' ISK/h';$script:headlineUpdated=[datetime]::UtcNow
    }
    $duration=[timespan]::FromSeconds($income.Seconds)
    $summary.Text=('Session {0} ISK | {1:00}:{2:00}:{3:00} | {4:N0} units mined' -f (Format-ISK $income.Value),[math]::Floor($duration.TotalHours),$duration.Minutes,$duration.Seconds,$income.Units)
    if ($paused) {$summary.Text='PAUSED | '+$summary.Text}
    $unpriced='';if ($income.Missing -gt 0) {$unpriced=(' | {0:N0} unpriced units - PARTIAL' -f $income.Missing)}
    $priceInfo.Text='Compressed BUY estimate; before fees'+$unpriced
    $priceInfo.ForeColor=if ($income.Missing -gt 0) {[Drawing.Color]::Orange} else {$muted}
    $script:trend=Get-TrendValues;$chart.Invalidate()
    $status.Text=$script:notice
    $status.ForeColor=$muted
    foreach ($m in Get-Members) {$attack=Get-AttackMessage $m.Character;if ($attack) {$status.Text=$attack;$status.ForeColor=[Drawing.Color]::Salmon;break}}
}
function Show-CargoDialog([string]$Name) {
    $timer.Stop()
    try {
        Poll-Logs;$s=$script:ships[$Name]
        $d=New-Object Windows.Forms.Form;$d.Text='Set cargo - '+$Name;$d.ClientSize=New-Object Drawing.Size(380,145);$d.StartPosition='CenterParent'
        $l=New-Label $d 'Current cargo (m3). Use Reset for a fully empty hold.' 12 12 360 35;$l.ForeColor=[Drawing.Color]::Black
        $v=New-Object Windows.Forms.NumericUpDown;$v.Maximum=1000000000;$v.DecimalPlaces=2;$v.ThousandsSeparator=$true;$v.Value=$s.Volume;$v.SetBounds(12,55,350,28);$d.Controls.Add($v)
        $ok=New-Button $d 'Apply' 252 100 110;$ok.DialogResult='OK';$d.AcceptButton=$ok
        if ($d.ShowDialog($form) -eq 'OK') {Poll-Logs;Reset-Cargo $s;$s.Volume=[decimal]$v.Value;$s.UnassignedVolume=$s.Volume;if ($script:mode -eq 'ICE') {$s.IceBlocks=$s.Volume/1000;$s.Units=$s.IceBlocks};Update-Rows;Save-State}
        $d.Dispose()
    } catch {$script:notice=$_.Exception.Message} finally {$timer.Start()}
}
function Show-Settings {
    $timer.Stop()
    try {
        if (Test-Path -LiteralPath $script:folder) {Poll-Logs}
        $d=New-Object Windows.Forms.Form;$d.Text='EVE Mining - Fleet profiles and prices';$d.BackColor=$bg;$d.ForeColor=[Drawing.Color]::WhiteSmoke
        $d.Font=$form.Font;$d.ClientSize=New-Object Drawing.Size(820,620);$d.StartPosition='CenterParent';$d.FormBorderStyle='FixedDialog';$d.MaximizeBox=$false;$d.MinimizeBox=$false
        $tabs=New-Object Windows.Forms.TabControl;$tabs.SetBounds(10,10,800,560);$d.Controls.Add($tabs)
        $fleetTab=New-Object Windows.Forms.TabPage;$fleetTab.Text='Fleet profiles';$fleetTab.BackColor=$bg;$tabs.TabPages.Add($fleetTab)
        $pricesTab=New-Object Windows.Forms.TabPage;$pricesTab.Text='Prices / Janice';$pricesTab.BackColor=$bg;$tabs.TabPages.Add($pricesTab)
        $null=New-Label $fleetTab 'Saved profile' 12 14 90
        $savedBox=New-Object Windows.Forms.ComboBox;$savedBox.DropDownStyle='DropDownList';$savedBox.SetBounds(110,10,250,26);foreach ($p in $script:profiles) {$null=$savedBox.Items.Add($p.Name)};$fleetTab.Controls.Add($savedBox)
        $load=New-Button $fleetTab 'Load into editor' 375 10 145
        $delete=New-Button $fleetTab 'Delete profile' 630 10 142
        $null=New-Label $fleetTab 'Profile name' 12 50 90
        $profileName=New-Object Windows.Forms.TextBox;$profileName.SetBounds(110,47,250,26);$fleetTab.Controls.Add($profileName)
        $editMode=New-Object Windows.Forms.ComboBox;$editMode.DropDownStyle='DropDownList';$editMode.SetBounds(375,47,95,26);$null=$editMode.Items.AddRange(@('ICE','ORE'));$editMode.SelectedItem=$script:mode;$fleetTab.Controls.Add($editMode)
        $quickSetup=New-Button $fleetTab 'Quick setup' 630 47 142;$quickSetup.Add_Click({Show-QuickSetup $d})
        $null=New-Label $fleetTab 'Lasers = expected harvesters (0 disables alerts). Raw cycle = unboosted reference; actual timing is learned.' 12 85 760 25
        $grid=New-Object Windows.Forms.DataGridView;$grid.SetBounds(12,114,760,270);Set-GridStyle $grid
        $enabled=New-Object Windows.Forms.DataGridViewCheckBoxColumn;$enabled.Name='Enabled';$enabled.HeaderText='Use';$enabled.Width=42;$null=$grid.Columns.Add($enabled)
        Add-TextColumn $grid 'Character' 'Character (exact log name)' 205
        $class=New-Object Windows.Forms.DataGridViewComboBoxColumn;$class.Name='ShipClass';$class.HeaderText='Ship class';$class.Width=155
        $classes=@('Custom','Venture','Prospect','Endurance','Procurer','Retriever','Covetor','Skiff','Mackinaw','Hulk','Porpoise','Orca','Rorqual')
        foreach ($p in $script:profiles) {foreach ($m in $p.Members) {if ($m.ShipClass -notin $classes) {$classes+=$m.ShipClass}}}
        $class.Items.AddRange([object[]]$classes);$null=$grid.Columns.Add($class)
        Add-TextColumn $grid 'Capacity' 'Capacity (m3)' 130
        Add-TextColumn $grid 'Lasers' 'Lasers' 60
        Add-TextColumn $grid 'Cycle' 'Raw cycle (s)' 95;$fleetTab.Controls.Add($grid)
        $discover=New-Button $fleetTab 'Add pilots from logs' 12 395 180
        $saveProfile=New-Button $fleetTab 'Save and activate profile' 502 395 270
        $folderBox=New-Object Windows.Forms.TextBox;$folderBox.ReadOnly=$true;$folderBox.Text=$script:folder;$folderBox.SetBounds(12,438,620,25);$fleetTab.Controls.Add($folderBox)
        $folderButton=New-Button $fleetTab 'Log folder...' 642 436 130
        $fleetMessage=New-Label $fleetTab 'Rename the profile before saving to create another setup. Select a row and press Delete to remove it.' 12 477 760 50
        $fleetMessage.ForeColor=$muted
        $loadEditor={
            $p=@($script:profiles | Where-Object {$_.Name -eq [string]$savedBox.SelectedItem})[0]
            $grid.Rows.Clear()
            if ($p) {$profileName.Text=$p.Name;$editMode.SelectedItem=$p.Mode;foreach ($m in $p.Members) {$cycle=0;if ($m.ContainsKey('CycleSeconds')) {$cycle=$m.CycleSeconds};$null=$grid.Rows.Add([bool]$m.Enabled,$m.Character,$m.ShipClass,([string]$m.Capacity),([string](Get-ExpectedLasers $m)),([string]$cycle))}}
            else {$profileName.Text='My fleet'}
        }
        $load.Add_Click($loadEditor)
        $delete.Add_Click({
            try {
                $remove=[string]$savedBox.SelectedItem;if (-not $remove) {return}
                if (Test-Path -LiteralPath $script:folder) {Poll-Logs}
                $script:profiles=@($script:profiles | Where-Object {$_.Name -ne $remove})
                if ($script:activeProfile -eq $remove) {
                    $script:activeProfile=''
                    if ($script:profiles.Count) {Use-Profile $script:profiles[0].Name}
                }
                $savedBox.Items.Clear();foreach ($p in $script:profiles) {$null=$savedBox.Items.Add($p.Name)}
                if ($script:activeProfile) {$savedBox.SelectedItem=$script:activeProfile}
                & $loadEditor;Sync-ProfileBoxes;Build-Rows;Update-Rows;Save-State
                $fleetMessage.Text='Profile deleted. Cargo and session history were kept.'
            } catch {$fleetMessage.Text=$_.Exception.Message}
        })
        if ($script:activeProfile) {$savedBox.SelectedItem=$script:activeProfile}; & $loadEditor
        $discover.Add_Click({
            try {
                $existing=@($grid.Rows | Where-Object {-not $_.IsNewRow} | ForEach-Object {[string]$_.Cells['Character'].Value})
                foreach ($n in Find-Pilots) {if ($n -notin $existing) {$null=$grid.Rows.Add($true,$n,'Custom','0')}}
                $fleetMessage.Text='Pilots added. Set ship class and actual cargo capacity before saving.'
            } catch {$fleetMessage.Text=$_.Exception.Message}
        })
        $folderButton.Add_Click({
            $browse=New-Object Windows.Forms.FolderBrowserDialog;$browse.SelectedPath=$script:folder
            if ($browse.ShowDialog($d) -eq 'OK') {
                $script:folder=$browse.SelectedPath;$folderBox.Text=$script:folder
                foreach ($m in Get-Members) {$script:ships[$m.Character].Known=$false}
                Set-WatchBaseline @(Get-Members | ForEach-Object {$_.Character});Save-State
            };$browse.Dispose()
        })
        $saveProfile.Add_Click({
            try {
                $null=$grid.EndEdit();$newName=$profileName.Text.Trim();if (-not $newName) {throw 'Enter a profile name.'}
                $members=@();$seen=@{}
                foreach ($row in $grid.Rows) {
                    if ($row.IsNewRow) {continue}
                    $n=([string]$row.Cells['Character'].Value).Trim();if (-not $n) {throw 'Every row needs a character name, or delete the empty row.'}
                    if ($seen.ContainsKey($n)) {throw ('Duplicate character: '+$n)};$seen[$n]=$true
                    $capacity=[decimal]0
                    if (-not [decimal]::TryParse([string]$row.Cells['Capacity'].Value,[Globalization.NumberStyles]::Number,[Globalization.CultureInfo]::GetCultureInfo('en-US'),[ref]$capacity) -or $capacity -lt 1000 -or $capacity -gt 1000000000) {throw ('Enter a capacity of at least 1,000 m3 for '+$n)}
                    $shipClass=[string]$row.Cells['ShipClass'].Value;if (-not $shipClass) {$shipClass='Custom'}
                    $member=@{Character=$n;ShipClass=$shipClass;Capacity=$capacity;Enabled=[bool]$row.Cells['Enabled'].Value;CycleSeconds=0}
                    $laserText=([string]$row.Cells['Lasers'].Value).Trim();$cycleText=([string]$row.Cells['Cycle'].Value).Trim()
                    if ($laserText) {$laserCount=0;if (-not [int]::TryParse($laserText,[ref]$laserCount) -or $laserCount -lt 0 -or $laserCount -gt 8) {throw 'Lasers must be 0 to 8.'};$member.Lasers=$laserCount}
                    if ($cycleText) {$seconds=[double]0;if (-not [double]::TryParse($cycleText,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::GetCultureInfo('en-US'),[ref]$seconds) -or $seconds -lt 0 -or $seconds -gt 600) {throw 'Cycle must be 0 (auto) or up to 600 seconds.'};$member.CycleSeconds=$seconds}
                    $members+=$member
                }
                if (-not @($members | Where-Object {$_.Enabled}).Count) {throw 'Enable at least one pilot.'}
                if (Test-Path -LiteralPath $script:folder) {Poll-Logs}
                $previous=@(Get-Members | ForEach-Object {$_.Character})
                $script:profiles=@($script:profiles | Where-Object {$_.Name -ne $newName})+@(@{Name=$newName;Mode=[string]$editMode.SelectedItem;Members=$members})
                Use-Profile $newName -PreviousCharacters $previous
                Sync-ProfileBoxes;Build-Rows;Update-Rows;Save-State
                $savedBox.Items.Clear();foreach ($p in $script:profiles) {$null=$savedBox.Items.Add($p.Name)};$savedBox.SelectedItem=$newName
                $fleetMessage.Text='Profile saved and activated. Check cargo after changing a ship. Existing cargo totals were kept.'
            } catch {$fleetMessage.Text=$_.Exception.Message}
        })
        $null=New-Label $pricesTab 'BUY prices only. Mined raw units are valued using the matching Compressed item (1:1 units).' 12 12 760 24
        $priceGrid=New-Object Windows.Forms.DataGridView;$priceGrid.SetBounds(12,78,760,305);Set-GridStyle $priceGrid;$priceGrid.AllowUserToAddRows=$false;$priceGrid.AllowUserToDeleteRows=$false
        Add-TextColumn $priceGrid 'Material' 'Material' 300 $true
        Add-TextColumn $priceGrid 'Average' 'Used buy / unit' 140 $true
        Add-TextColumn $priceGrid 'Custom' 'Buy ISK / unit' 150
        Add-TextColumn $priceGrid 'Source' 'Price source' 145 $true;$pricesTab.Controls.Add($priceGrid)
        $null=New-Label $pricesTab 'Filter' 12 47 45
        $filter=New-Object Windows.Forms.TextBox;$filter.SetBounds(62,43,300,26);$pricesTab.Controls.Add($filter)
        $refresh=New-Button $pricesTab 'Copy compressed list' 550 41 222
        $savePrices=New-Button $pricesTab 'Save price overrides' 522 395 250
        $scanButton=New-Button $pricesTab 'Import Janice prices...' 12 395 210
        $openJanice=New-Button $pricesTab 'Open Janice' 235 395 130
        $openJanice.Add_Click({[Diagnostics.Process]::Start('https://janice.e-351.com/') | Out-Null})
        $priceMessage=New-Label $pricesTab '' 12 440 760 80;$priceMessage.ForeColor=$muted
        $fillPriceGrid={
            $priceGrid.Rows.Clear();$allNames=@($script:volumes.Keys)+@($script:overrides.Keys)
            foreach ($n in ($allNames | Sort-Object -Unique)) {
                $avg='';$used=Get-UnitPrice $n;if ($null -ne $used) {$avg=$used.ToString('N2')}
                $manual='';$source='';if ($script:overrides.ContainsKey($n)) {
                    $source=$script:overrides[$n].Source
                    if ($source -in @('Janice buy','Custom buy')) {$manual=([decimal]$script:overrides[$n].Price).ToString('N2')} else {$source='Legacy estimate (ignored)'}
                }
                $index=$priceGrid.Rows.Add($n,$avg,$manual,$source);$priceGrid.Rows[$index].Visible=($n.IndexOf($filter.Text,[StringComparison]::OrdinalIgnoreCase) -ge 0)
            }
            $priceMessage.Text='Copy compressed list, appraise it on Janice, then import its Item / Amount / Volume / Buy / Sell rows. Only BUY is used. Missing buy quotes are flagged. Old scan / CCP averages are not used.'
        }
        & $fillPriceGrid
        $filter.Add_TextChanged({$priceGrid.CurrentCell=$null;foreach ($r in $priceGrid.Rows) {$r.Visible=(([string]$r.Cells['Material'].Value).IndexOf($filter.Text,[StringComparison]::OrdinalIgnoreCase) -ge 0)}})
        $savePrices.Add_Click({
            try {
                $null=$priceGrid.EndEdit();$next=@{}
                foreach ($row in $priceGrid.Rows) {
                    $text=([string]$row.Cells['Custom'].Value).Trim();if (-not $text) {continue}
                    $v=[decimal]0
                    if (-not [decimal]::TryParse($text,[Globalization.NumberStyles]::Number,[Globalization.CultureInfo]::GetCultureInfo('en-US'),[ref]$v) -or $v -lt 0) {throw ('Invalid custom price for '+$row.Cells['Material'].Value)}
                    $n=[string]$row.Cells['Material'].Value;$source='Custom buy'
                    if ($script:overrides.ContainsKey($n) -and $script:overrides[$n].Price -eq $v -and $script:overrides[$n].Source -in @('Janice buy','Custom buy')) {$source=$script:overrides[$n].Source}
                    $next[$n]=@{Price=$v;Source=$source}
                }
                $script:overrides=$next
                # The optional seed file is a one-time import, not a permanent override.
                $seed=Join-Path $script:dataDirectory 'EVE-Mining-Price-Overrides.json'
                if (Test-Path -LiteralPath $seed) {Move-Item -LiteralPath $seed -Destination ($seed+'.imported') -Force}
                $buySeed=Join-Path $script:dataDirectory 'EVE-Mining-Buy-Seed.json';if (Test-Path -LiteralPath $buySeed) {Move-Item -LiteralPath $buySeed -Destination ($buySeed+'.imported') -Force}
                Save-State;Update-Rows;$priceMessage.Text='Custom prices saved. All session values are recalculated with the selected prices.'
            } catch {$priceMessage.Text=$_.Exception.Message}
        })
        $refresh.Add_Click({[Windows.Forms.Clipboard]::SetText((Get-CompressedPriceList));$priceMessage.Text='Compressed item list copied (one unit each). Paste into Janice, then import the Buy/Sell result table.'})
        $scanButton.Add_Click({
            $scan=New-Object Windows.Forms.Form;$scan.Text='Paste Janice price set';$scan.ClientSize=New-Object Drawing.Size(660,400);$scan.StartPosition='CenterParent'
            $help=New-Label $scan 'Columns: Item / Amount / Volume / Buy / Sell. Only Buy is imported. No yield is added.' 12 10 635 35;$help.ForeColor=[Drawing.Color]::Black
            $input=New-Object Windows.Forms.TextBox;$input.Multiline=$true;$input.ScrollBars='Both';$input.WordWrap=$false;$input.SetBounds(12,50,635,290);$scan.Controls.Add($input)
            $apply=New-Button $scan 'Import BUY prices' 407 355 240;$apply.DialogResult='OK';$scan.AcceptButton=$apply
            if ($scan.ShowDialog($d) -eq 'OK') {
                try {
                    $parsed=Read-JanicePrices $input.Text;if (-not $parsed.Count) {throw 'No valid Janice rows found. Include Item, Amount, Volume, Buy and Sell columns.'}
                    foreach ($n in $parsed.Keys) {$script:overrides[$n]=$parsed[$n]};Save-State;& $fillPriceGrid;Update-Rows
                    $priceMessage.Text=('Imported {0} BUY prices. Sell values ignored; mining quantities kept.' -f $parsed.Count)
                } catch {$priceMessage.Text=$_.Exception.Message}
            };$scan.Dispose()
        })
        $close=New-Button $d 'Close' 690 580 120;$close.DialogResult='OK';$d.CancelButton=$close
        $null=$d.ShowDialog($form);$d.Dispose()
        Complete-PriceRefresh;Sync-ProfileBoxes;Build-Rows;Update-Rows;Save-State
    } catch {$script:notice=$_.Exception.Message} finally {$timer.Start()}
}
$settings.Add_Click({Show-Settings})
$profileBox.Add_SelectedIndexChanged({
    if ($script:loading) {return}
    try {if (Test-Path -LiteralPath $script:folder) {Poll-Logs};Use-Profile ([string]$profileBox.SelectedItem);Sync-ProfileBoxes;Build-Rows;Update-Rows;Save-State} catch {$script:notice=$_.Exception.Message}
})
$modeBox.Add_SelectedIndexChanged({if ($script:loading) {return};$script:mode=[string]$modeBox.SelectedItem;$p=Get-Profile;if ($p) {$p.Mode=$script:mode};Update-Rows;Save-State})
$resetAll.Add_Click({try {Poll-Logs;foreach ($m in Get-Members) {Reset-Cargo $script:ships[$m.Character]};Update-Rows;Save-State} catch {$script:notice=$_.Exception.Message}})
$confirmMenu=New-Object Windows.Forms.ContextMenuStrip
$confirmAll=$confirmMenu.Items.Add('Confirm all displayed cargo values')
$confirmAll.Add_Click({
    try {Poll-Logs;foreach ($m in Get-Members) {if ($script:ships[$m.Character].Unknown) {throw 'Correct uncounted cargo with Set current cargo first.'}};foreach ($m in Get-Members) {$script:ships[$m.Character].Known=$true};Update-Rows;Save-State} catch {$script:notice=$_.Exception.Message}
})
$resetAll.ContextMenuStrip=$confirmMenu
$tooltip.SetToolTip($resetAll,'Left-click: empty all cargo counters. Right-click: confirm current cargo values without resetting.')
$compactButton.Add_Click({$script:compact=-not $script:compact;Build-Rows;Update-Rows;Save-State})
$topCheck.Add_CheckedChanged({$form.TopMost=$topCheck.Checked;Save-State})
$soundCheck.Add_CheckedChanged({$script:attackSound=$soundCheck.Checked;Save-State})
$sessionReset.Add_Click({
    try {if (Test-Path -LiteralPath $script:folder) {Poll-Logs};$script:session=@{StartedUtc=[datetime]::UtcNow;Mined=@{};Events=@();Pauses=@()};$script:headlineUpdated=[datetime]::MinValue;$script:notice='New income session started. Cargo totals were kept.';Update-Rows;Save-State} catch {$script:notice=$_.Exception.Message}
})
$pauseButton.Add_Click({
    try {
        if (Test-Path -LiteralPath $script:folder) {Poll-Logs}
        $pauseNow=-not (Test-SessionPaused);Set-SessionPause $pauseNow
        $script:headlineUpdated=[datetime]::MinValue
        $script:notice=if ($pauseNow) {'Session paused. Cargo / attack alerts stay active.'} else {'Session resumed. Break time excluded from ISK/h.'}
        if (-not $pauseNow) {foreach ($entry in $script:activity.Values) {$entry.Since=[datetime]::UtcNow}}
        Update-Rows;Save-State
    } catch {$script:notice=$_.Exception.Message}
})
$timer=New-Object Windows.Forms.Timer;$timer.Interval=1000
$timer.Add_Tick({try {Poll-Logs;Complete-PriceRefresh;Update-Rows;Save-State} catch {$script:notice=$_.Exception.Message;Update-Rows}})
Sync-ProfileBoxes;Build-Rows;Update-Rows
if ($script:windowState) {
    $candidate=New-Object Drawing.Rectangle([int]$script:windowState.Left,[int]$script:windowState.Top,$form.Width,$form.Height)
    if (@([Windows.Forms.Screen]::AllScreens | Where-Object {$_.WorkingArea.IntersectsWith($candidate)}).Count) {$form.StartPosition='Manual';$form.Location=$candidate.Location}
}
$form.Add_Shown({try {Poll-Logs;Update-Rows} catch {$script:notice=$_.Exception.Message};$timer.Start();if (-not $script:profiles.Count) {Show-QuickSetup $form}})
$form.Add_FormClosing({$timer.Stop();try {Save-State} catch {};if ($script:webClient) {$script:webClient.CancelAsync();$script:webClient.Dispose()};$timer.Dispose();$tooltip.Dispose()})
if (-not $NoRun) {[Windows.Forms.Application]::Run($form)}
