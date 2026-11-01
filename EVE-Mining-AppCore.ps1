function New-ShipState([decimal]$Capacity=10000,[string]$ShipClass='Custom') {
    return @{Volume=[decimal]0;Units=[decimal]0;IceBlocks=[decimal]0;Capacity=$Capacity;ShipClass=$ShipClass;Known=$false;Last='-';CriticalUntil=[datetime]::MinValue;Unknown='';Contents=@{};UnassignedVolume=[decimal]0}
}
function ConvertTo-Map($Object) {
    $map=@{}; if ($null -ne $Object) {foreach ($p in $Object.PSObject.Properties) {$map[$p.Name]=$p.Value}}; return $map
}
function Get-Profile { return @($script:profiles | Where-Object {$_.Name -eq $script:activeProfile})[0] }
function Get-Members { $p=Get-Profile; if ($p) {return @($p.Members | Where-Object {$_.Enabled})} }
function Save-State {
    $state=@{Version=5;AppVersion='1.0';DefaultPricesApplied=$script:defaultPricesApplied;AttackSound=$script:attackSound;Folder=$script:folder;Mode=$script:mode;Profiles=@($script:profiles);ActiveProfile=$script:activeProfile;Ships=$script:ships;Files=$script:files;Session=$script:session;PriceOverrides=$script:overrides;Window=@{Compact=$script:compact;TopMost=$form.TopMost;Left=$form.Left;Top=$form.Top}}
    $temp=$script:statePath+'.tmp'
    $state | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $script:statePath -Force
}
function Read-LogText([string]$Path) {
    $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    $reader=New-Object IO.StreamReader($stream)
    try {return $reader.ReadToEnd()} finally {$reader.Dispose()}
}
function Get-LatestLogs {
    if (-not (Test-Path -LiteralPath $script:folder -PathType Container)) {throw 'Select your EVE Gamelogs folder in Fleet settings.'}
    return @(Get-ChildItem -LiteralPath $script:folder -Filter '*.txt' | Where-Object {$_.Name -match '^\d{8}_\d{6}_\d+\.txt$'} | Group-Object {($_.BaseName -split '_')[-1]} | ForEach-Object {$_.Group | Sort-Object Name -Descending | Select-Object -First 1})
}
function Find-Pilots {
    $found=@(); foreach ($file in Get-LatestLogs) {
        $text=Read-LogText $file.FullName
        if ($text -match '(?m)^\s*Listener:\s*(.+?)\r?$') {$found+=$Matches[1].Trim()}
    }; return @($found | Sort-Object -Unique)
}
function Set-WatchBaseline([string[]]$Characters) {
    if (-not (Test-Path -LiteralPath $script:folder)) {return}
    foreach ($file in Get-LatestLogs) {
        $text=Read-LogText $file.FullName
        if ($text -match '(?m)^\s*Listener:\s*(.+?)\r?$') {
            $name=$Matches[1].Trim()
            if ($name -in $Characters) {$script:files[$file.FullName]=@{Count=($text -split "`n").Length-1;Name=$name}}
        }
    }
}
function Use-Profile([string]$Name,[string[]]$PreviousCharacters=$null) {
    $old=@(Get-Members | ForEach-Object {$_.Character})
    if ($null -ne $PreviousCharacters) {$old=@($PreviousCharacters)}
    $profile=@($script:profiles | Where-Object {$_.Name -eq $Name})[0]
    if (-not $profile) {throw 'Fleet profile not found.'}
    $script:activeProfile=$Name; $script:mode=$profile.Mode
    $new=@()
    foreach ($m in @($profile.Members | Where-Object {$_.Enabled})) {
        $n=$m.Character
        if (-not $script:ships.ContainsKey($n)) {$script:ships[$n]=New-ShipState $m.Capacity $m.ShipClass}
        $s=$script:ships[$n]
        if ($n -notin $old -or $s.Capacity -ne $m.Capacity -or $s.ShipClass -ne $m.ShipClass) {$s.Known=$false}
        if ($n -notin $old) {$new+=$n}; $script:activity[$n]=@{Times=@();Since=[datetime]::UtcNow;Learned=0}
        $s.Capacity=[decimal]$m.Capacity; $s.ShipClass=$m.ShipClass
    }
    Set-WatchBaseline $new
}
function Add-SessionYield([string]$Name,$Event) {
    Update-SessionAutoPause $Event.Time
    if (Test-SessionPaused) {
        $open=@($script:session.Pauses | Where-Object {$null -eq $_.End})
        if ($open.Count -and $Event.Time -ge $open[0].Start) {
            Set-SessionPause $false $Event.Time
            $script:headlineUpdated=[datetime]::MinValue
            $script:notice='Session resumed automatically: mining yield received.'
            foreach ($entry in $script:activity.Values) {$entry.Since=$Event.Time}
        }
    }
    foreach ($pause in @($script:session.Pauses)) {
        if ($null -eq $pause) {continue}
        if ($Event.Time -ge $pause.Start -and ($null -eq $pause.End -or $Event.Time -lt $pause.End)) {return}
    }
    if (-not $script:session.Mined.ContainsKey($Name)) {$script:session.Mined[$Name]=@{}}
    $totals=$script:session.Mined[$Name]
    if (-not $totals.ContainsKey($Event.Material)) {$totals[$Event.Material]=[decimal]0}
    $totals[$Event.Material]+=$Event.Quantity
    $script:session.Events+=@(@{Name=$Name;Material=$Event.Material;Quantity=$Event.Quantity;Time=$Event.Time})
    if (-not $script:session.LastMiningUtc -or $Event.Time -gt $script:session.LastMiningUtc) {$script:session.LastMiningUtc=$Event.Time}
}
function Poll-Logs {
    $pendingYields=@()
    $active=@{}; foreach ($m in Get-Members) {$active[$m.Character]=$true}
    # Complete every read before mutating counters or file cursors. If one log
    # is briefly unavailable, the whole batch can be retried without lost income.
    $snapshots=@()
    foreach ($file in Get-LatestLogs) {
        $snapshots+=@{File=$file;Text=(Read-LogText $file.FullName)}
    }
    foreach ($snapshot in $snapshots) {
        $file=$snapshot.File;$text=$snapshot.Text; $lines=$text -split "`n"; $count=$lines.Length-1
        if ($text -notmatch '(?m)^\s*Listener:\s*(.+?)\r?$') {continue}
        $name=$Matches[1].Trim(); if (-not $active.ContainsKey($name)) {continue}
        $key=$file.FullName
        if (-not $script:files.ContainsKey($key)) {$script:files[$key]=@{Count=$count;Name=$name};$script:ships[$name].Known=$false;continue}
        $record=$script:files[$key]
        if ($count -lt $record.Count) {$record.Count=$count;$script:ships[$name].Known=$false;continue}
        for ($i=$record.Count;$i -lt $count;$i++) {
            $attack=Read-IncomingAttack $lines[$i];if ($attack) {Register-IncomingAttack $name $attack}
            $event=Read-MiningEvent $lines[$i]
            if ($event) {$null=Add-MiningEvent $script:ships[$name] $event $script:volumes;$pendingYields+=@{Name=$name;Event=$event};Add-MiningActivity $name $event} else { $compression=Read-CompressionEvent $lines[$i];if ($compression) {$null=Apply-Compression $script:ships[$name] $compression $script:volumes} }
        }
        $record.Count=$count
    }
    # Process all pilots chronologically so one file's backlog cannot create
    # an idle gap while another character was mining throughout that time.
    foreach ($pending in ($pendingYields | Sort-Object {$_.Event.Time})) {Add-SessionYield $pending.Name $pending.Event}
    Update-SessionAutoPause
    $cutoff=[datetime]::UtcNow.AddMinutes(-10)
    $script:session.Events=@($script:session.Events | Where-Object {$_.Time -gt $cutoff})
}
function Get-UnitPrice([string]$Material) {
    $target='Compressed '+$Material
    if ($Material.StartsWith('Compressed ')) {$target=$Material}
    # Explicit compressed BUY quotes take precedence over raw-item buy quotes.
    foreach ($key in @($target,$Material)) {
        if ($script:overrides.ContainsKey($key) -and $script:overrides[$key].Source -in @('Janice buy','Custom buy')) {return [decimal]$script:overrides[$key].Price}
    }
    return $null
}
function Get-Income([string]$Character='') {
    $value=[decimal]0; $missing=[decimal]0; $units=[decimal]0
    foreach ($n in $script:session.Mined.Keys) {
        if ($Character -and $n -ne $Character) {continue}
        foreach ($material in $script:session.Mined[$n].Keys) {
            $qty=[decimal]$script:session.Mined[$n][$material];$units+=$qty
            $price=Get-UnitPrice $material
            if ($null -eq $price) {$missing+=$qty} else {$value+=$price*$qty}
        }
    }
    $seconds=Get-SessionActiveSeconds
    return @{Value=$value;Missing=$missing;Units=$units;Rate=([double]$value*3600/$seconds);Seconds=$seconds}
}
function Test-SessionPaused {
    return @($script:session.Pauses | Where-Object {$null -ne $_ -and $null -eq $_.End}).Count -gt 0
}
function Get-SessionActiveSeconds([datetime]$Now=[datetime]::UtcNow) {
    $seconds=($Now-$script:session.StartedUtc).TotalSeconds
    foreach ($pause in @($script:session.Pauses)) {
        if ($null -eq $pause) {continue}
        $end=$Now;if ($null -ne $pause.End -and $pause.End -lt $end) {$end=$pause.End}
        $start=$pause.Start;if ($start -lt $script:session.StartedUtc) {$start=$script:session.StartedUtc}
        if ($end -gt $start) {$seconds-=($end-$start).TotalSeconds}
    }
    return [math]::Max([double]1,$seconds)
}
function Set-SessionPause([bool]$Paused,[datetime]$Now=[datetime]::UtcNow) {
    if (-not $script:session.ContainsKey('Pauses')) {$script:session.Pauses=@()}
    if ($Paused -and -not (Test-SessionPaused)) {$script:session.Pauses+=@{Start=$Now;End=$null}}
    elseif (-not $Paused) {foreach ($pause in $script:session.Pauses) {if ($null -eq $pause.End) {$pause.End=$Now}};$script:session.LastResumeUtc=$Now}
}
function Update-SessionAutoPause([datetime]$Now=[datetime]::UtcNow) {
    if (Test-SessionPaused) {return}
    $last=$script:session.StartedUtc
    if ($script:session.LastMiningUtc -and $script:session.LastMiningUtc -gt $last) {$last=$script:session.LastMiningUtc}
    if ($script:session.LastResumeUtc -and $script:session.LastResumeUtc -gt $last) {$last=$script:session.LastResumeUtc}
    if (($Now-$last).TotalSeconds -ge 300) {
        Set-SessionPause $true $last.AddSeconds(300)
        $script:headlineUpdated=[datetime]::MinValue
        $script:notice='Auto-paused: no mining yield for 5 minutes. Next yield resumes.'
    }
}
function Get-TrendValues {
    $buckets=New-Object 'double[]' 10; $now=[datetime]::UtcNow
    foreach ($event in $script:session.Events) {
        $age=($now-$event.Time).TotalMinutes
        if ($age -ge 0 -and $age -lt 10) {
            $price=Get-UnitPrice $event.Material
            if ($null -ne $price) {$index=9-[int][math]::Floor($age);$buckets[$index]+=[double]($event.Quantity*$price)*60}
        }
    }; return ,$buckets
}
function Start-PriceRefresh {
    if ($script:priceTask) {return}
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    $script:webClient=New-Object Net.WebClient
    $script:webClient.Headers['User-Agent']='EVE-Mining-Monitor/3.0 (public market reference prices)'
    $script:priceTask=$script:webClient.DownloadStringTaskAsync([uri]'https://esi.evetech.net/latest/markets/prices/?datasource=tranquility')
    $script:priceRequestStarted=[datetime]::UtcNow; $script:notice='Downloading CCP market average prices...'
}
function Complete-PriceRefresh {
    if (-not $script:priceTask) {return}
    if (-not $script:priceTask.IsCompleted -and ([datetime]::UtcNow-$script:priceRequestStarted).TotalSeconds -gt 30) {$script:webClient.CancelAsync()}
    if (-not $script:priceTask.IsCompleted) {return}
    try {
        $payload=$script:priceTask.GetAwaiter().GetResult() | ConvertFrom-Json
        $prices=@{};foreach ($entry in $payload) {if ($entry.average_price -gt 0) {$prices[[string]$entry.type_id]=[decimal]$entry.average_price}}
        if ($prices.Count -eq 0) {throw 'No average prices returned.'}
        $script:market=@{}
        foreach ($item in $script:volumes.Values) {if ($prices.ContainsKey([string]$item.TypeId)) {$script:market[$item.Name]=$prices[[string]$item.TypeId]}}
        $script:priceDate=[datetime]::UtcNow
        @{UpdatedUtc=$script:priceDate;Prices=$script:market} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:pricePath -Encoding UTF8
        $script:notice='CCP average prices updated. Custom / scan prices kept.'
    } catch {$script:notice='Price update failed. Cached and custom prices are still available.'}
    finally {$script:webClient.Dispose();$script:webClient=$null;$script:priceTask=$null}
}
function Convert-ScanPrice([string]$Text) {
    $value=$Text.Trim()
    if ($value.Contains(',') -and $value.Contains('.')) {
        if ($value.LastIndexOf(',') -gt $value.LastIndexOf('.')) {$value=$value.Replace('.','').Replace(',','.')} else {$value=$value.Replace(',','')}
    } elseif ($value -match ',\d{2}$') {$value=$value.Replace(',','.')} else {$value=$value.Replace(',','');if ($value -match '^\d{1,3}(\.\d{3})+$') {$value=$value.Replace('.','')}}
    return [decimal]::Parse($value,[Globalization.CultureInfo]::InvariantCulture)
}
function Read-BeltScan([string]$Text) {
    $totals=@{}
    foreach ($line in ($Text -split "`n")) {
        if ($line -match '^\s*(?<Material>.+?)\s+(?<Quantity>[\d.,]+)\s+[\d.,]+\s*m[3\u00b3]\s+(?<Value>[\d.,]+)\s*ISK(?:\s+.*)?$') {
            $name=$Matches.Material.Trim();$quantity=[decimal]($Matches.Quantity -replace '[.,]','');$value=Convert-ScanPrice $Matches.Value
            if ($quantity -le 0) {continue}
            if (-not $totals.ContainsKey($name)) {$totals[$name]=@{Quantity=[decimal]0;Value=[decimal]0}}
            $totals[$name].Quantity+=$quantity;$totals[$name].Value+=$value
        }
    }
    $result=@{};foreach ($name in $totals.Keys) {$result[$name]=@{Price=[decimal]::Round(($totals[$name].Value/$totals[$name].Quantity),2);Source='Scan estimate'}}
    return $result
}
function Read-JanicePrices([string]$Text) {
    $totals=@{}
    foreach ($line in ($Text -split "`n")) {
        # Item | Amount | Volume | Buy | Sell. Buy/Sell values are totals for Amount.
        if ($line -match '^\s*(?<Item>.+?)\s+(?<Amount>[\d,.]+)\s+(?<Volume>[\d,.]+)(?:\s*m[3\u00b3])?\s+(?<Buy>[\d,.]+)(?:\s*ISK)?\s+(?<Sell>[\d,.]+)(?:\s*ISK)?\s*$') {
            $name=$Matches.Item.Trim();$qty=Convert-ScanPrice $Matches.Amount;$buy=Convert-ScanPrice $Matches.Buy
            if ($qty -le 0 -or $buy -lt 0) {continue}
            if (-not $totals.ContainsKey($name)) {$totals[$name]=@{Quantity=[decimal]0;Buy=[decimal]0}}
            $totals[$name].Quantity+=$qty;$totals[$name].Buy+=$buy
        }
    }
    $result=@{};foreach ($name in $totals.Keys) {$result[$name]=@{Price=($totals[$name].Buy/$totals[$name].Quantity);Source='Janice buy'}}
    return $result
}
function Get-CompressedPriceList {
    return @($script:volumes.Keys | Where-Object {$_.StartsWith('Compressed ') -and $script:volumes.ContainsKey($_.Substring(11))} | Sort-Object | ForEach-Object {$_+"`t1"}) -join "`r`n"
}
function Initialize-Monitor {
    $script:defaultPricesApplied='';$script:defaultPriceDate=''
    $script:combat=@{};$script:attackSound=$true;$script:lastAttackTone=[datetime]::MinValue;$script:cycleReferences=@{};
    $script:activity=@{};$script:monitorStarted=[datetime]::UtcNow;
    $script:profiles=@();$script:activeProfile='';$script:ships=@{};$script:files=@{};$script:overrides=@{};$script:market=@{}
    $script:mode='ICE';$script:compact=$true;$script:topMost=$false;$script:windowState=$null
    $script:session=@{StartedUtc=[datetime]::UtcNow;Mined=@{};Events=@();Pauses=@()};$script:notice='Open Fleet settings to add pilots and save a profile.'
    $script:priceDate=$null;$script:priceTask=$null;$script:webClient=$null
    $script:folder=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'EVE\logs\Gamelogs'
    if (Test-Path -LiteralPath $script:statePath) {
        $saved=Get-Content -LiteralPath $script:statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($saved.DefaultPricesApplied) {$script:defaultPricesApplied=[string]$saved.DefaultPricesApplied}
        if ($saved.Folder) {$script:folder=$saved.Folder};if ($null -ne $saved.AttackSound) {$script:attackSound=[bool]$saved.AttackSound}
        foreach ($p in $saved.Ships.PSObject.Properties) {
            $old=$p.Value;$s=New-ShipState ([decimal]$old.Capacity)
            $s.Known=[bool]$old.Known;$s.Last=[string]$old.Last
            if ($saved.Version -ge 2) {
                $s.Volume=[decimal]$old.Volume;$s.Units=[decimal]$old.Units;$s.IceBlocks=[decimal]$old.IceBlocks;$s.Unknown=[string]$old.Unknown
                if ($old.CriticalUntil) {$s.CriticalUntil=([datetime]$old.CriticalUntil).ToUniversalTime()}
            } else {$s.Volume=[decimal]$old.Blocks*1000;$s.Units=[decimal]$old.Blocks;$s.IceBlocks=[decimal]$old.Blocks}
            if ($old.ShipClass) {$s.ShipClass=[string]$old.ShipClass}
            if ($old.Contents) {$s.Contents=ConvertTo-Map $old.Contents;$s.UnassignedVolume=[decimal]$old.UnassignedVolume} else {$s.UnassignedVolume=$s.Volume}
            $script:ships[$p.Name]=$s
        }
        foreach ($p in $saved.Files.PSObject.Properties) {$script:files[$p.Name]=@{Count=[int]$p.Value.Count;Name=[string]$p.Value.Name}}
        if ($saved.Version -ge 3) {
            foreach ($p in $saved.Profiles) {
                $members=@();foreach ($m in $p.Members) {
                    $member=@{Character=[string]$m.Character;ShipClass=[string]$m.ShipClass;Capacity=[decimal]$m.Capacity;Enabled=[bool]$m.Enabled;CycleSeconds=0}
                    if ($null -ne $m.Lasers) {$member.Lasers=[int]$m.Lasers}
                    if ($null -ne $m.CycleSeconds) {$member.CycleSeconds=[double]$m.CycleSeconds}
                    $members+=$member
                }
                $script:profiles+=@{Name=[string]$p.Name;Mode=[string]$p.Mode;Members=$members}
            }
            $script:activeProfile=[string]$saved.ActiveProfile;$script:mode=[string]$saved.Mode
            foreach ($p in $saved.PriceOverrides.PSObject.Properties) {$script:overrides[$p.Name]=@{Price=[decimal]$p.Value.Price;Source=[string]$p.Value.Source}}
            if ($saved.Session.StartedUtc) {$script:session.StartedUtc=([datetime]$saved.Session.StartedUtc).ToUniversalTime()}
            $script:session.Pauses=@()
            foreach ($pause in $saved.Session.Pauses) {
                $end=$null;if ($null -ne $pause.End) {$end=([datetime]$pause.End).ToUniversalTime()}
                $script:session.Pauses+=@{Start=([datetime]$pause.Start).ToUniversalTime();End=$end}
            }
            foreach ($p in $saved.Session.Mined.PSObject.Properties) {$script:session.Mined[$p.Name]=ConvertTo-Map $p.Value}
            foreach ($e in $saved.Session.Events) {$script:session.Events+=@{Name=[string]$e.Name;Material=[string]$e.Material;Quantity=[decimal]$e.Quantity;Time=([datetime]$e.Time).ToUniversalTime()}}
            if ($saved.Session.LastMiningUtc) {$script:session.LastMiningUtc=([datetime]$saved.Session.LastMiningUtc).ToUniversalTime()}
            elseif ($script:session.Events.Count) {$script:session.LastMiningUtc=($script:session.Events | Sort-Object {$_.Time} | Select-Object -Last 1).Time}
            else {$script:session.LastMiningUtc=[datetime]::UtcNow}
            if ($saved.Session.LastResumeUtc) {$script:session.LastResumeUtc=([datetime]$saved.Session.LastResumeUtc).ToUniversalTime()}
            $script:windowState=$saved.Window
            if ($saved.Window) {$script:compact=[bool]$saved.Window.Compact;$script:topMost=[bool]$saved.Window.TopMost}
        } elseif ($script:ships.Count) {
            # Migrate the existing local fleet; clean installations contain no personal pilots.
            $members=@();foreach ($n in ($script:ships.Keys | Sort-Object)) {
                $s=$script:ships[$n];$class='Custom';if ($s.Capacity -eq 44269) {$class='Mackinaw'} elseif ($s.Capacity -eq 62500) {$class='Porpoise'}
                $s.ShipClass=$class;$members+=@{Character=$n;ShipClass=$class;Capacity=$s.Capacity;Enabled=$true}
            }
            $mode='ICE';if ($saved.Mode -in @('ICE','ORE')) {$mode=[string]$saved.Mode}
            $script:profiles=@(@{Name='My fleet';Mode=$mode;Members=$members});$script:activeProfile='My fleet';$script:mode=$mode
        }
        if ($saved.Version -lt 3 -and -not (Test-Path -LiteralPath ($script:statePath+'.v2-backup'))) {Copy-Item -LiteralPath $script:statePath -Destination ($script:statePath+'.v2-backup')}
    }
    $seed=Join-Path $script:dataDirectory 'EVE-Mining-Price-Overrides.json'
    if (Test-Path -LiteralPath $seed) {
        $hints=Get-Content -LiteralPath $seed -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $hints.Prices.PSObject.Properties) {if (-not $script:overrides.ContainsKey($p.Name)) {$script:overrides[$p.Name]=@{Price=[decimal]$p.Value;Source='Scan estimate'}}}
    }
    if (Test-Path -LiteralPath $script:pricePath) {
        try {$cache=Get-Content -LiteralPath $script:pricePath -Raw -Encoding UTF8 | ConvertFrom-Json;$script:market=ConvertTo-Map $cache.Prices;$script:priceDate=([datetime]$cache.UpdatedUtc).ToUniversalTime()} catch {}
    }
    $buySeed=Join-Path $script:dataDirectory 'EVE-Mining-Buy-Seed.json'
    if (Test-Path -LiteralPath $buySeed) {
        $seedData=Get-Content -LiteralPath $buySeed -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $seedData.Prices.PSObject.Properties) {if (-not $script:overrides.ContainsKey($p.Name)) {$script:overrides[$p.Name]=@{Price=[decimal]$p.Value;Source='Janice buy'}}}
    }
    $defaultFile=Join-Path $PSScriptRoot 'EVE-Mining-Default-Prices.json'
    if (Test-Path -LiteralPath $defaultFile) {
        $defaults=Get-Content -LiteralPath $defaultFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:defaultPriceDate=[string]$defaults.AsOfUtc
        if (-not $script:defaultPricesApplied) {
            foreach ($p in $defaults.Prices.PSObject.Properties) {
                if (-not $script:overrides.ContainsKey($p.Name) -or $script:overrides[$p.Name].Source -notin @('Janice buy','Custom buy')) {$script:overrides[$p.Name]=@{Price=[decimal]$p.Value.Price;Source=[string]$p.Value.Source}}
            }
            $script:defaultPricesApplied=[string]$defaults.Version
        }
    }
    if (Get-Profile) {$script:notice='Ready. Check start values after transfers made while the monitor was closed.'}
}
