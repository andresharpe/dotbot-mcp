function Invoke-GetTimezones {
    param(
        [hashtable]$Arguments
    )
    
    # Return only essential fields to keep response size manageable
    $timezones = [System.TimeZoneInfo]::GetSystemTimeZones() | ForEach-Object {
        @{
            id = $_.Id
            offset = $_.BaseUtcOffset.ToString()
        }
    }
    
    return @{
        timezones = $timezones
        count = $timezones.Count
    }
}
