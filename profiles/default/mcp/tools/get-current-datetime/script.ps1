function Invoke-GetCurrentDateTime {
    param(
        [hashtable]$Arguments
    )
    
    $format = $Arguments['format']
    $timezone = $Arguments['timezone']
    $utc = $Arguments['utc'] -eq $true
    
    $now = if ($utc) { [DateTime]::UtcNow } else { [DateTime]::Now }
    
    # Handle timezone conversion
    if ($timezone -and -not $utc) {
        try {
            $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById($timezone)
            $now = [System.TimeZoneInfo]::ConvertTime($now, $tz)
        }
        catch {
            throw "Invalid timezone: $timezone"
        }
    }
    
    # Format output
    $formatted = if ($format) {
        $now.ToString($format, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    else {
        $now.ToString('o')  # ISO 8601
    }
    
    return @{
        datetime = $formatted
        timestamp = [DateTimeOffset]::new($now).ToUnixTimeSeconds()
        iso8601 = $now.ToString('o')
        timezone = if ($utc) { 'UTC' } else { [System.TimeZoneInfo]::Local.Id }
    }
}
