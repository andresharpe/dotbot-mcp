function Invoke-FormatDate {
    param(
        [hashtable]$Arguments
    )
    
    $dateString = $Arguments['date']
    $inputFormat = $Arguments['input_format']
    $outputFormat = $Arguments['output_format']
    
    if (-not $outputFormat) {
        throw "output_format is required"
    }
    
    $date = Get-DateFromString -DateString $dateString -Format $inputFormat
    
    $formatted = $date.ToString($outputFormat, [System.Globalization.CultureInfo]::InvariantCulture)
    
    return @{
        formatted = $formatted
        iso8601 = $date.ToString('o')
    }
}
