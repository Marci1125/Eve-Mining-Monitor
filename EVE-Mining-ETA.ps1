function Get-CargoEta($Member,[datetime]$Now=[datetime]::UtcNow) {
    $name=$Member.Character;$ship=$script:ships[$name]
    $result=@{Text='ETA learning';Note='Waiting for at least 30 seconds of recent mining yields.';Seconds=$null;Rate=0}
    if (-not $ship.Known -or $ship.Unknown) {$result.Text='ETA verify';$result.Note='Confirm or correct the cargo starting value first.';return $result}
    $free=[math]::Max([decimal]0,($ship.Capacity-$ship.Volume))
    $target=$free;if ($script:mode -eq 'ICE') {$target=[math]::Floor($free/1000)*1000}
    if ($target -le 0) {$result.Text='Full';$result.Note='No space for another standard ice block / no remaining ore capacity.';$result.Seconds=0;return $result}
    $start=$Now.AddMinutes(-5)
    if ($script:monitorStarted -gt $start) {$start=$script:monitorStarted}
    $events=@($script:session.Events | Where-Object {$_.Name -eq $name -and $_.Time -ge $start -and $_.Time -le $Now} | Sort-Object {$_.Time})
    if (-not $events.Count) {
        if ((Get-ExpectedLasers $Member) -le 0) {$result.Text='ETA --';$result.Note='No recent mining yield for this ship.'}
        elseif (($Now-$script:monitorStarted).TotalSeconds -gt 120) {$result.Text='ETA paused';$result.Note='No recent mining yields; waiting for mining to resume.'}
        return $result
    }
    $cycle=Get-CycleTiming $Member $Now
    $stale=[math]::Max([double]120,2.5*$cycle.Seconds)
    if (($Now-$events[-1].Time).TotalSeconds -gt $stale) {$result.Text='ETA paused';$result.Note='No recent yield; a full-hold prediction is not reliable while mining is paused.';return $result}
    $first=$events[0].Time;$elapsed=($events[-1].Time-$first).TotalSeconds
    if ($elapsed -lt 30) {return $result}
    $volume=[decimal]0
    foreach ($event in $events) {
        # The first timestamp is the observation boundary: its preceding mining
        # duration is unknown. Later regular and critical yields both count.
        if ($event.Time -le $first) {continue}
        if (-not $script:volumes.ContainsKey($event.Material)) {$result.Text='ETA unknown';$result.Note='A recent material has no known volume.';return $result}
        $volume+=[decimal]$event.Quantity*[decimal]$script:volumes[$event.Material].Volume
    }
    if ($volume -le 0) {return $result}
    $rate=[double]$volume/$elapsed;$seconds=[double]$target/$rate
    $result.Seconds=$seconds;$result.Rate=$rate
    if ($seconds -ge 3600) {$result.Text=('~{0}h {1:00}m' -f [math]::Floor($seconds/3600),[math]::Floor(($seconds%3600)/60))}
    else {$result.Text=('~{0}m {1:00}s' -f [math]::Floor($seconds/60),[math]::Floor($seconds%60))}
    $result.Note=('Estimated time until full: {0}. Recent rate {1:N0} m3/min, up to 5 minutes, including critical yield. Assumes mining continues without compression or transfers.' -f $result.Text,($rate*60))
    return $result
}
