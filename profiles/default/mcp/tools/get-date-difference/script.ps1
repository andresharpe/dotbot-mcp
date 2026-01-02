function Invoke-GetDateDifference {
    param(
        [hashtable]$Arguments
    )
    
    $startString = $Arguments['start_date']
    $endString = $Arguments['end_date']
    $startFormat = $Arguments['start_format']
    $endFormat = $Arguments['end_format']
    $unit = $Arguments['unit']
    
    $startDate = Get-DateFromString -DateString $startString -Format $startFormat
    $endDate = Get-DateFromString -DateString $endString -Format $endFormat
    
    $timeSpan = $endDate - $startDate
    
    $result = switch ($unit) {
        'seconds' { $timeSpan.TotalSeconds }
        'minutes' { $timeSpan.TotalMinutes }
        'hours' { $timeSpan.TotalHours }
        'days' { $timeSpan.TotalDays }
        'weeks' { $timeSpan.TotalDays / 7 }
        default { $timeSpan.TotalDays }
    }
    
    return @{
        difference = $result
        unit = if ($unit) { $unit } else { 'days' }
        total_seconds = $timeSpan.TotalSeconds
        total_days = $timeSpan.TotalDays
        duration = @{
            days = $timeSpan.Days
            hours = $timeSpan.Hours
            minutes = $timeSpan.Minutes
            seconds = $timeSpan.Seconds
        }
    }
}
