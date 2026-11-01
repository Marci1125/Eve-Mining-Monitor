# Pure cargo functions shared by the UI and verification script.
function Read-MiningEvent([string]$Line) {
    $plain=[System.Net.WebUtility]::HtmlDecode(($Line -replace '<[^>]*>',''))
    if ($plain -notmatch '^\[\s*(?<Time>\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s*\]\s*\(mining\).*?You mined (?<Bonus>an additional )?(?<Quantity>[\d,]+) units? of (?<Material>.+?)\s*$') { return $null }
    $quantity=[decimal]::Parse(($Matches.Quantity -replace ',',''),[Globalization.CultureInfo]::InvariantCulture)
    $material=$Matches.Material.Trim(); $critical=[bool]$Matches.Bonus
    $stamp=[datetime]::ParseExact($Matches.Time,'yyyy.MM.dd HH:mm:ss',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal)
    return @{Quantity=$quantity;Material=$material;Critical=$critical;Time=$stamp}
}
function Add-MiningEvent($Ship,$Event,$Volumes) {
    if (-not $Volumes.ContainsKey($Event.Material)) { $Ship.Known=$false; $Ship.Unknown=$Event.Material; return $false }
    $item=$Volumes[$Event.Material]
    $Ship.Volume += [decimal]$Event.Quantity * [decimal]$item.Volume
    $Ship.Units += $Event.Quantity
    if (-not $Ship.ContainsKey('Contents')) {$Ship.Contents=@{}; $Ship.UnassignedVolume=$Ship.Volume-([decimal]$Event.Quantity*[decimal]$item.Volume)}
    if (-not $Ship.Contents.ContainsKey($Event.Material)) {$Ship.Contents[$Event.Material]=[decimal]0}
    $Ship.Contents[$Event.Material]+=$Event.Quantity
    if ($item.Mode -eq 'ICE' -and [decimal]$item.Volume -eq 1000) { $Ship.IceBlocks += $Event.Quantity }
    $Ship.Last=$Event.Time.ToString('HH:mm:ss')+' UTC - '+$Event.Material
    if ($Event.Critical) {
        $until=$Event.Time.AddSeconds(30)
        if ($until -gt $Ship.CriticalUntil) { $Ship.CriticalUntil=$until }
    }
    return $true
}
function Get-CargoColor($Ship,[string]$Mode,[datetime]$Now=[datetime]::UtcNow) {
    $full=($Ship.Volume -ge $Ship.Capacity*[decimal]0.95)
    if ($Mode -eq 'ICE' -and ($Ship.Capacity-$Ship.Volume) -lt 1000) { $full=$true }
    if ($full) { return 'Red' }
    if ($Ship.CriticalUntil -gt $Now) { return 'Yellow' }
    return 'Green'
}
function Reset-Cargo($Ship) {
    $Ship.Volume=[decimal]0; $Ship.Units=[decimal]0; $Ship.IceBlocks=[decimal]0
    $Ship.Known=$true; $Ship.Unknown=''; $Ship.CriticalUntil=[datetime]::MinValue
    $Ship.Contents=@{}; $Ship.UnassignedVolume=[decimal]0
    $Ship.ActivitySince=[datetime]::UtcNow
}
function Read-CompressionEvent([string]$Line) {
    $plain=[Net.WebUtility]::HtmlDecode(($Line -replace '<[^>]*>',''))
    if ($plain -notmatch '^\[\s*(?<Time>\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s*\]\s*\(notify\)\s*Successfully compressed (?<Raw>.+?) into (?<Quantity>[\d,]+) (?<Compressed>.+?)\.\s*$') {return $null}
    return @{Raw=$Matches.Raw;Compressed=$Matches.Compressed;Quantity=[decimal]($Matches.Quantity -replace ',','');Time=[datetime]::ParseExact($Matches.Time,'yyyy.MM.dd HH:mm:ss',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal)}
}
function Apply-Compression($Ship,$Event,$Volumes) {
    # Modern Compressed types are 1 raw unit : 1 compressed unit. Batch Compressed is excluded.
    if ($Event.Compressed -ne ('Compressed '+$Event.Raw) -or -not $Volumes.ContainsKey($Event.Raw) -or -not $Volumes.ContainsKey($Event.Compressed)) {
        $Ship.Known=$false;$Ship.Unknown='Unsupported compression: '+$Event.Raw;return $false
    }
    if (-not $Ship.ContainsKey('Contents')) {$Ship.Contents=@{};$Ship.UnassignedVolume=$Ship.Volume}
    $rawVolume=[decimal]$Volumes[$Event.Raw].Volume;$compressedVolume=[decimal]$Volumes[$Event.Compressed].Volume
    $knownQuantity=[decimal]0;if ($Ship.Contents.ContainsKey($Event.Raw)) {$knownQuantity=[decimal]$Ship.Contents[$Event.Raw]}
    $knownUsed=[math]::Min($knownQuantity,[decimal]$Event.Quantity)
    $unassignedNeeded=($Event.Quantity-$knownUsed)*$rawVolume
    if ($compressedVolume -ge $rawVolume -or $unassignedNeeded -gt $Ship.UnassignedVolume -or $Event.Quantity*$rawVolume -gt $Ship.Volume) {
        $Ship.Known=$false;$Ship.Unknown='Compression exceeds tracked cargo: '+$Event.Raw;return $false
    }
    $Ship.Contents[$Event.Raw]=$knownQuantity-$knownUsed
    $Ship.UnassignedVolume-=$unassignedNeeded
    if (-not $Ship.Contents.ContainsKey($Event.Compressed)) {$Ship.Contents[$Event.Compressed]=[decimal]0}
    $Ship.Contents[$Event.Compressed]+=$Event.Quantity
    $Ship.Volume-=$Event.Quantity*($rawVolume-$compressedVolume)
    if ($Volumes[$Event.Raw].Mode -eq 'ICE') {$Ship.IceBlocks=[math]::Max([decimal]0,($Ship.IceBlocks-$Event.Quantity))}
    $Ship.Last=('Compressed {0:N0} {1} ({2:N2} m3 freed)' -f $Event.Quantity,$Event.Raw,($Event.Quantity*($rawVolume-$compressedVolume)))
    return $true
}
