function Get-ExpectedLasers($Member) {
    if ($Member.ShipClass -in @('Porpoise','Orca','Rorqual')) {return 0}
    if ($Member.ContainsKey('Lasers')) {return [int]$Member.Lasers}
    switch ($Member.ShipClass) {
        {$_ -in @('Procurer','Retriever','Covetor','Skiff','Mackinaw','Hulk','Venture','Prospect')} {return 2}
        'Endurance' {return 1}
        default {return 0}
    }
}
function Add-MiningActivity([string]$Name,$Event) {
    if ($Event.Critical) {return}
    if (-not $script:activity.ContainsKey($Name)) {$script:activity[$Name]=@{Times=@();Since=[datetime]::UtcNow;Learned=0}}
    $a=$script:activity[$Name];$a.Times+=@($Event.Time)
    $a.Times=@($a.Times | Where-Object {$_ -gt [datetime]::UtcNow.AddMinutes(-20)})
}
function Get-Median([double[]]$Values) {
    if (-not $Values.Count) {return [double]0}
    $sorted=@($Values | Sort-Object);$middle=[int][math]::Floor($sorted.Count/2)
    if ($sorted.Count%2) {return [double]$sorted[$middle]}
    return ([double]$sorted[$middle-1]+[double]$sorted[$middle])/2
}
function Get-ObservedCycle($Member) {
    $n=$Member.Character;$lasers=Get-ExpectedLasers $Member
    if ($lasers -le 0 -or -not $script:activity.ContainsKey($n)) {return [double]0}
    $times=@($script:activity[$n].Times | Sort-Object | Select-Object -Last 12)
    if ($times.Count -lt [math]::Max(6,$lasers*3)) {return [double]0}
    $deltas=@();for ($i=$lasers;$i -lt $times.Count;$i++) {$seconds=($times[$i]-$times[$i-$lasers]).TotalSeconds;if ($seconds -ge 5 -and $seconds -le 600) {$deltas+=$seconds}}
    return Get-Median $deltas
}
function Get-CycleTiming($Member,[datetime]$Now=[datetime]::UtcNow) {
    $lasers=Get-ExpectedLasers $Member
    $baseline=[double]0;if ($Member.ContainsKey('CycleSeconds')) {$baseline=[double]$Member.CycleSeconds}
    $own=Get-ObservedCycle $Member
    $samples=@();$normalized=($baseline -gt 0)
    foreach ($peer in Get-Members) {
        if ($peer.ShipClass -ne $Member.ShipClass -or (Get-ExpectedLasers $peer) -ne $lasers -or $lasers -le 0) {continue}
        $observed=Get-ObservedCycle $peer
        if ($observed -le 0) {continue}
        if ($normalized) {
            if ($peer.ContainsKey('CycleSeconds') -and $peer.CycleSeconds -gt 0) {$samples+=($observed/[double]$peer.CycleSeconds)}
        } else {$samples+=$observed}
    }
    $reference=Get-Median $samples;$effective=$baseline;$source='Baseline'
    if ($own -gt 0) {$effective=$own;$source='Observed'}
    if ($samples.Count -ge 2 -and $reference -gt 0) {
        $cohort=$reference;if ($normalized) {$cohort*=$baseline}
        $individual=$null
        if ($script:activity.ContainsKey($Member.Character)) {$individual=$script:activity[$Member.Character]}
        # Two unequal laser periods produce a stable but non-constant two-event
        # cadence. Learn this character's offset from the fleet, rather than
        # repeatedly treating slower Abyssal modules as an inactive laser.
        $dualCycle=Get-UnequalLaserCadence $Member
        if ($individual -and $dualCycle -gt 0) {$individual.IndividualRatio=$dualCycle/$cohort}
        $expected=$cohort
        if ($individual -and $individual.ContainsKey('IndividualRatio')) {$expected*=$individual.IndividualRatio}
        if ($own -le 0 -or $own -gt $expected*1.4 -or $own -lt $expected*0.7) {$effective=$expected;$source='Fleet estimate'}
        elseif ($individual -and $individual.ContainsKey('IndividualRatio')) {$effective=$own;$source='Individual observed'}
        if ($individual -and -not $individual.ContainsKey('IndividualRatio') -and $own -gt $cohort*1.4 -and @($individual.Times).Count -lt 10) {$effective=$own;$source='Learning individual cadence'}
        $key=$Member.ShipClass+'/'+$lasers+'/'+$normalized
        if (-not $script:cycleReferences.ContainsKey($key)) {$script:cycleReferences[$key]=@{Value=$reference;Until=[datetime]::MinValue}}
        $ref=$script:cycleReferences[$key]
        if ([math]::Abs($reference/$ref.Value-1) -gt 0.20) {$ref.Until=$Now.AddSeconds([math]::Max([double]120,$cohort*3));$ref.Value=$reference}
        if ($ref.Until -gt $Now) {$source+=' (settling)'}
    } elseif ($baseline -gt 0 -and $own -gt $baseline*1.5) {$effective=$baseline;$source='Baseline (low event rate)'}
    return @{Seconds=$effective;Observed=$own;Baseline=$baseline;Source=$source;Settling=($source -like '*settling*')}
}
function Get-UnequalLaserCadence($Member) {
    if ((Get-ExpectedLasers $Member) -ne 2 -or -not $script:activity.ContainsKey($Member.Character)) {return [double]0}
    $times=@($script:activity[$Member.Character].Times | Sort-Object | Select-Object -Last 16)
    if ($times.Count -lt 10) {return [double]0}
    $deltas=@();for ($i=2;$i -lt $times.Count;$i++) {$deltas+=($times[$i]-$times[$i-2]).TotalSeconds}
    $median=Get-Median $deltas
    if ($median -lt 5) {return [double]0}
    $sorted=@($deltas|Sort-Object)
    $low=$sorted[[int][math]::Floor(($sorted.Count-1)*0.2)]
    $high=$sorted[[int][math]::Ceiling(($sorted.Count-1)*0.8)]
    if ($high-$low -lt 2 -or $low -lt $median*0.8 -or $high -gt $median*1.2) {return [double]0}
    return $median
}
function Get-CycleNote($Member) {
    if ((Get-ExpectedLasers $Member) -le 0) {return ''}
    $timing=Get-CycleTiming $Member
    if ($timing.Seconds -le 0) {return 'Cycle: learning from regular yields'}
    $note=('Cycle ~{0:N1}s equivalent ({1})' -f $timing.Seconds,$timing.Source)
    if ($timing.Baseline -gt 0) {$note+=(' | raw baseline {0:N1}s' -f $timing.Baseline)}
    if ($timing.Observed -gt 0 -and $timing.Baseline -gt 0) {
        $delta=100*(1-$timing.Observed/$timing.Baseline);$direction='faster';if ($delta -lt 0) {$direction='slower'}
        $note+=(' | observed {0:N0}% {1}' -f [math]::Abs($delta),$direction)
    }
    return $note
}
function Get-ActivityWarning($Member,[datetime]$Now=[datetime]::UtcNow) {
    if (Test-SessionPaused) {return ''}
    $lasers=Get-ExpectedLasers $Member;$n=$Member.Character
    if ($lasers -le 0) {return ''}
    $s=$script:ships[$n]
    if (-not $s.Known -or (Get-CargoColor $s $script:mode $Now) -eq 'Red') {return ''}
    if (-not $script:activity.ContainsKey($n)) {$script:activity[$n]=@{Times=@();Since=$script:monitorStarted;Learned=0}}
    $a=$script:activity[$n]
    $since=$a.Since;if ($s.ContainsKey('ActivitySince') -and $s.ActivitySince -gt $since) {$since=$s.ActivitySince}
    $timing=Get-CycleTiming $Member $Now;$cycle=$timing.Seconds
    $silence=[math]::Max([double]120,$cycle*3)
    $times=@($a.Times | Where-Object {$_ -le $Now});$last=$since;if ($times.Count) {$last=$times[-1]}
    $peersActive=$false
    foreach ($peer in Get-Members) {
        if ($peer.Character -eq $n -or (Get-ExpectedLasers $peer) -le 0 -or -not $script:activity.ContainsKey($peer.Character)) {continue}
        if (@($script:activity[$peer.Character].Times | Where-Object {$_ -gt $Now.AddSeconds(-$silence) -and $_ -le $Now}).Count) {$peersActive=$true;break}
    }
    if (($Now-$since).TotalSeconds -gt $silence -and ($Now-$last).TotalSeconds -gt $silence -and $peersActive) {return 'NO YIELD (fleet is mining)'}
    if ($cycle -le 0) {return ''}
    if ($timing.Settling) {return ''}
    # Recovery uses the latest two cycles instead of waiting for the longer
    # detection window to forget a previously stopped/missing laser.
    $recent=@($times | Where-Object {$_ -gt $Now.AddSeconds(-2.2*$cycle)} | Sort-Object)
    $required=[int][math]::Ceiling(2*$lasers)
    if ($recent.Count -ge $required -and ($Now-$recent[-1]).TotalSeconds -le 1.4*$cycle) {
        $tail=@($recent | Select-Object -Last $required)
        $regular=($tail[-1]-$tail[0]).TotalSeconds -ge 0.6*$cycle
        for ($i=$lasers;$i -lt $tail.Count;$i++) {
            if (($tail[$i]-$tail[$i-$lasers]).TotalSeconds -gt 1.4*$cycle) {$regular=$false}
        }
        if ($regular) {return ''}
    }
    $window=[math]::Min([double]600,[math]::Max([double]120,$cycle*4))
    if (($Now-$since).TotalSeconds -lt $window) {return ''}
    $count=@($times | Where-Object {$_ -gt $Now.AddSeconds(-$window)}).Count
    $expected=$window/$cycle*$lasers
    if ($count -gt 0 -and $count -lt $expected*0.70) {return ('IRREGULAR (check {0} lasers)' -f $lasers)}
    return ''
}
