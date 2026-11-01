function Read-IncomingAttack([string]$Line) {
    $plain=[Net.WebUtility]::HtmlDecode(($Line -replace '<[^>]*>',''))
    if ($plain -notmatch '^\[\s*(?<Time>\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s*\]\s*\(combat\)\s*(?<Body>.+)$') {return $null}
    $stamp=[datetime]::ParseExact($Matches.Time,'yyyy.MM.dd HH:mm:ss',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal)
    $body=$Matches.Body;$attacker=''
    if ($body -match '^[\d,.]+\s+from\s+(.+?)(?:\s+-\s+.*)?$') {$attacker=$Matches[1]}
    elseif ($body -match '^(.+?) misses you completely(?:\s.*)?$') {$attacker=$Matches[1]}
    if (-not $attacker) {return $null}
    return @{Time=$stamp;Attacker=$attacker;Body=$body}
}
function Play-AttackTone { [System.Media.SystemSounds]::Exclamation.Play() }
function Register-IncomingAttack([string]$Name,$Attack,[datetime]$Now=[datetime]::UtcNow) {
    # Do not alert for old backlog after a restart, or future/misdated log lines.
    $age=($Now-$Attack.Time).TotalSeconds
    if ($age -lt -5 -or $age -gt 15) {return}
    $script:combat[$Name]=@{Time=$Attack.Time;Attacker=$Attack.Attacker}
    if ($script:attackSound -and ($Now-$script:lastAttackTone).TotalSeconds -ge 30) {
        Play-AttackTone;$script:lastAttackTone=$Now
    }
}
function Get-AttackMessage([string]$Name,[datetime]$Now=[datetime]::UtcNow) {
    if ($script:combat.ContainsKey($Name) -and ($Now-$script:combat[$Name].Time).TotalSeconds -le 45) {return 'UNDER ATTACK: '+$Name+' - '+$script:combat[$Name].Attacker}
    return ''
}
