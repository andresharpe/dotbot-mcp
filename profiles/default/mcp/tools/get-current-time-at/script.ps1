function Invoke-GetCurrentTimeAt {
    param(
        [hashtable]$Arguments
    )
    
    # Extract arguments
    $location = $Arguments['location']
    $latitude = $Arguments['latitude']
    $longitude = $Arguments['longitude']
    $format = $Arguments['format']
    
    # Determine if we need to geocode a place name or use coordinates
    if ($location) {
        # Use place name - will geocode to get coordinates
        $useLocationName = $true
    }
    elseif ($null -ne $latitude -and $null -ne $longitude) {
        # Validate coordinates
        if ($latitude -lt -90 -or $latitude -gt 90) {
            throw "Latitude must be between -90 and 90"
        }
        
        if ($longitude -lt -180 -or $longitude -gt 180) {
            throw "Longitude must be between -180 and 180"
        }
        $useLocationName = $false
    }
    else {
        throw "Either 'location' (place name) or both 'latitude' and 'longitude' are required"
    }
    
    # Load API key from .env file
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $envFile = Join-Path $scriptDir "..\..\..\..\.env"
    $apiKey = $null
    
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^\s*GOOGLE_MAPS_API_KEY\s*=\s*(.+)$') {
                $apiKey = $matches[1].Trim()
            }
        }
    }
    
    if (-not $apiKey -or $apiKey -eq 'your_google_maps_api_key_here') {
        throw "Google Maps API key not configured. Please set GOOGLE_MAPS_API_KEY in .env file (see .env.example)"
    }
    
    # Geocode location to get coordinates
    if ($useLocationName) {
        # Geocode place name to coordinates
        $encodedLocation = [System.Web.HttpUtility]::UrlEncode($location)
        $geoUrl = "https://maps.googleapis.com/maps/api/geocode/json?address=${encodedLocation}&key=${apiKey}"
        
        try {
            $geoResponse = Invoke-RestMethod -Uri $geoUrl -Method Get
            
            if ($geoResponse.status -ne 'OK') {
                throw "Google Geocoding API error: $($geoResponse.status)"
            }
            
            # Extract coordinates from first result
            if ($geoResponse.results.Count -gt 0) {
                $latitude = $geoResponse.results[0].geometry.location.lat
                $longitude = $geoResponse.results[0].geometry.location.lng
                $formattedAddress = $geoResponse.results[0].formatted_address
            }
            else {
                throw "No results found for location: $location"
            }
        }
        catch {
            throw "Failed to geocode location: $_"
        }
    }
    else {
        $formattedAddress = "Coordinates: $latitude, $longitude"
    }
    
    # Call Google Timezone API to get timezone information
    $utcNow = [DateTime]::UtcNow
    $unixTimestamp = [DateTimeOffset]::new($utcNow).ToUnixTimeSeconds()
    $tzUrl = "https://maps.googleapis.com/maps/api/timezone/json?location=${latitude},${longitude}&timestamp=${unixTimestamp}&key=${apiKey}"
    
    try {
        $tzResponse = Invoke-RestMethod -Uri $tzUrl -Method Get
        
        if ($tzResponse.status -ne 'OK') {
            throw "Google Timezone API error: $($tzResponse.status)"
        }
        
        $timezoneId = $tzResponse.timeZoneId
        $timezoneName = $tzResponse.timeZoneName
        $rawOffset = $tzResponse.rawOffset
        $dstOffset = $tzResponse.dstOffset
        $totalOffsetSeconds = $rawOffset + $dstOffset
    }
    catch {
        throw "Failed to get timezone information: $_"
    }
    
    # Convert UTC time to local time using timezone offset
    $localTime = $utcNow.AddSeconds($totalOffsetSeconds)
    
    # Format the offset as +HH:MM or -HH:MM
    $offsetHours = [int]([Math]::Floor([Math]::Abs($totalOffsetSeconds) / 3600))
    $offsetMinutes = [int]([Math]::Floor(([Math]::Abs($totalOffsetSeconds) % 3600) / 60))
    $offsetSign = if ($totalOffsetSeconds -ge 0) { "+" } else { "-" }
    $timezoneOffset = "{0}{1:D2}:{2:D2}" -f $offsetSign, $offsetHours, $offsetMinutes
    
    # Format output
    $formatted = if ($format) {
        $localTime.ToString($format, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    else {
        # ISO 8601 with timezone offset
        $localTime.ToString('yyyy-MM-ddTHH:mm:ss') + $timezoneOffset
    }
    
    return @{
        location = if ($useLocationName) { $location } else { $formattedAddress }
        formattedAddress = $formattedAddress
        coordinates = @{
            latitude = $latitude
            longitude = $longitude
        }
        timezone = $timezoneId
        timezoneName = $timezoneName
        timezoneOffset = $timezoneOffset
        currentTime = $formatted
        utcTime = $utcNow.ToString('o')
        iso8601 = $localTime.ToString('yyyy-MM-ddTHH:mm:ss') + $timezoneOffset
    }
}
