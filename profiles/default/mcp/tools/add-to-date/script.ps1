function Invoke-AddToDate {
    param(
        [hashtable]$Arguments
    )
    
    $dateString = $Arguments['date']
    $inputFormat = $Arguments['input_format']
    $outputFormat = $Arguments['output_format']
    
    $date = Get-DateFromString -DateString $dateString -Format $inputFormat
    
    # Add time units
    if ($Arguments.ContainsKey('years')) { $date = $date.AddYears([int]$Arguments['years']) }
    if ($Arguments.ContainsKey('months')) { $date = $date.AddMonths([int]$Arguments['months']) }
    if ($Arguments.ContainsKey('days')) { $date = $date.AddDays([int]$Arguments['days']) }
    if ($Arguments.ContainsKey('hours')) { $date = $date.AddHours([int]$Arguments['hours']) }
    if ($Arguments.ContainsKey('minutes')) { $date = $date.AddMinutes([int]$Arguments['minutes']) }
    if ($Arguments.ContainsKey('seconds')) { $date = $date.AddSeconds([int]$Arguments['seconds']) }
    
    $formatted = if ($outputFormat) {
        $date.ToString($outputFormat, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    else {
        $date.ToString('o')
    }
    
    return @{
        result = $formatted
        iso8601 = $date.ToString('o')
        timestamp = [DateTimeOffset]::new($date).ToUnixTimeSeconds()
    }
}
