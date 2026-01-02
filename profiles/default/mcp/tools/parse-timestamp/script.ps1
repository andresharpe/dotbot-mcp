function Invoke-ParseTimestamp {
    param(
        [hashtable]$Arguments
    )
    
    $timestamp = [long]$Arguments['timestamp']
    $format = $Arguments['format']
    $isMilliseconds = $Arguments['is_milliseconds'] -eq $true
    
    $dateTime = if ($isMilliseconds) {
        [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).DateTime
    }
    else {
        [DateTimeOffset]::FromUnixTimeSeconds($timestamp).DateTime
    }
    
    $formatted = if ($format) {
        $dateTime.ToString($format, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    else {
        $dateTime.ToString('o')
    }
    
    return @{
        datetime = $formatted
        iso8601 = $dateTime.ToString('o')
        local = $dateTime.ToLocalTime().ToString('o')
        utc = $dateTime.ToUniversalTime().ToString('o')
    }
}
