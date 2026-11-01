function Get-FleetFreeSpace {
    $volume=[decimal]0;$blocks=[decimal]0;$unconfirmed=$false;$pilots=0;$details=@()
    foreach ($member in Get-Members) {
        if ($member.ShipClass -in @('Porpoise','Orca','Rorqual')) {continue}
        $ship=$script:ships[$member.Character]
        $free=[math]::Max([decimal]0,($ship.Capacity-$ship.Volume))
        $fit=[math]::Floor($free/1000)
        $volume+=$free;$blocks+=$fit;$pilots++
        if (-not $ship.Known -or $ship.Unknown) {$unconfirmed=$true}
        $details+=('{0}: {1:N0} blocks / {2:N2} m3 free' -f $member.Character,$fit,$free)
    }
    $text=if ($script:mode -eq 'ICE') {('Miners free: {0:N0} ice blocks' -f $blocks)} else {('Miners free: {0:N0} m3' -f $volume)}
    $second=if ($unconfirmed) {'Verify cargo values first'} else {('{0} mining ships | boosters excluded' -f $pilots)}
    return @{Text=($text+"`n"+$second);Volume=$volume;Blocks=$blocks;Unconfirmed=$unconfirmed;Pilots=$pilots;Note=(($details -join "`n")+"`nWhole ice blocks are summed per ship. Transfers/compression can change available space.")}
}
