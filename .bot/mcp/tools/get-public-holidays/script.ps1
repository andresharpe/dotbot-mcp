function Invoke-GetPublicHolidays {
    param(
        [hashtable]$Arguments
    )
    
    # Extract arguments
    $latitude = $Arguments['latitude']
    $longitude = $Arguments['longitude']
    $date = $Arguments['date']
    
    # Validate coordinates
    if ($null -eq $latitude -or $null -eq $longitude) {
        throw "Both latitude and longitude are required"
    }
    
    if ($latitude -lt -90 -or $latitude -gt 90) {
        throw "Latitude must be between -90 and 90"
    }
    
    if ($longitude -lt -180 -or $longitude -gt 180) {
        throw "Longitude must be between -180 and 180"
    }
    
    # Parse date or use today
    $checkDate = if ($date) {
        try {
            [DateTime]::Parse($date)
        }
        catch {
            throw "Invalid date format. Use ISO 8601 format (e.g., '2024-12-25')"
        }
    }
    else {
        [DateTime]::Today
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
    
    # Call Google Geocoding API to get country code
    $geoUrl = "https://maps.googleapis.com/maps/api/geocode/json?latlng=${latitude},${longitude}&key=${apiKey}"
    
    try {
        $geoResponse = Invoke-RestMethod -Uri $geoUrl -Method Get
        
        if ($geoResponse.status -ne 'OK') {
            throw "Google Geocoding API error: $($geoResponse.status)"
        }
        
        # Extract country code from address components
        $countryCode = $null
        $countryName = $null
        
        foreach ($result in $geoResponse.results) {
            foreach ($component in $result.address_components) {
                if ($component.types -contains 'country') {
                    $countryCode = $component.short_name
                    $countryName = $component.long_name
                    break
                }
            }
            if ($countryCode) { break }
        }
        
        if (-not $countryCode) {
            throw "Could not determine country from coordinates"
        }
    }
    catch {
        throw "Failed to geocode location: $_"
    }
    
    # Call Nager.Date API to get public holidays for the year
    $year = $checkDate.Year
    $holidayUrl = "https://date.nager.at/api/v3/PublicHolidays/${year}/${countryCode}"
    
    try {
        $holidays = Invoke-RestMethod -Uri $holidayUrl -Method Get
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            # No holidays available for this country
            $holidays = @()
        }
        else {
            throw "Failed to fetch holidays: $_"
        }
    }
    
    # Check if the specified date is a holiday
    $dateStr = $checkDate.ToString('yyyy-MM-dd')
    $matchingHolidays = $holidays | Where-Object { $_.date -eq $dateStr }
    
    $isHoliday = $matchingHolidays.Count -gt 0
    
    return @{
        isHoliday = $isHoliday
        date = $dateStr
        country = $countryName
        countryCode = $countryCode
        holidays = if ($isHoliday) {
            $matchingHolidays | ForEach-Object {
                @{
                    name = $_.name
                    localName = $_.localName
                    global = $_.global
                    counties = $_.counties
                }
            }
        } else { @() }
        totalHolidaysThisYear = $holidays.Count
        coordinates = @{
            latitude = $latitude
            longitude = $longitude
        }
    }
}
