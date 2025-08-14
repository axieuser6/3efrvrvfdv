# Check what the API is actually returning
Write-Host "Checking actual API response content..."

$AXIESTUDIO_APP_URL = "https://axiestudio-axiestudio-ttefi.ondigitalocean.app"
$DIRECT_API_KEY = "sk-Sikhas4RX3o5P_MqILi5hUyUdNWhA07n0w3Vuy5AYNM"

try {
    $url = "$AXIESTUDIO_APP_URL/api/v1/users/?x-api-key=$DIRECT_API_KEY"
    Write-Host "Testing URL: $url"
    
    # Use Invoke-WebRequest to get more details
    $webResponse = Invoke-WebRequest -Uri $url -Method GET -Headers @{"x-api-key" = $DIRECT_API_KEY}
    
    Write-Host "Status Code: $($webResponse.StatusCode)"
    Write-Host "Content Type: $($webResponse.Headers.'Content-Type')"
    Write-Host "Content Length: $($webResponse.Content.Length)"
    Write-Host ""
    Write-Host "Raw Content (first 500 chars):"
    Write-Host $webResponse.Content.Substring(0, [Math]::Min(500, $webResponse.Content.Length))
    Write-Host ""
    
    # Try to parse as JSON
    try {
        $jsonData = $webResponse.Content | ConvertFrom-Json
        Write-Host "Successfully parsed as JSON!"
        Write-Host "JSON type: $($jsonData.GetType().Name)"
        Write-Host "JSON count: $($jsonData.Count)"
        
        if ($jsonData.Count -gt 0) {
            Write-Host "First item properties:"
            $jsonData[0].PSObject.Properties | ForEach-Object {
                Write-Host "   $($_.Name): '$($_.Value)'"
            }
            
            # Look for our target user
            $targetUser = $jsonData | Where-Object { 
                $_.username -eq "user14@mocksender.shop" -or 
                $_.email -eq "user14@mocksender.shop" -or
                $_.name -eq "user14@mocksender.shop"
            }
            
            if ($targetUser) {
                Write-Host ""
                Write-Host "FOUND TARGET USER!"
                Write-Host "User ID: $($targetUser.id)"
                
                # Delete the user
                Write-Host "Deleting user..."
                $deleteUrl = "$AXIESTUDIO_APP_URL/api/v1/users/$($targetUser.id)?x-api-key=$DIRECT_API_KEY"
                $deleteResponse = Invoke-WebRequest -Uri $deleteUrl -Method DELETE -Headers @{"x-api-key" = $DIRECT_API_KEY}
                
                Write-Host "Delete response status: $($deleteResponse.StatusCode)"
                Write-Host "SUCCESS: User deleted!"
            } else {
                Write-Host "Target user not found in response"
            }
        }
        
    } catch {
        Write-Host "Failed to parse as JSON: $($_.Exception.Message)"
        Write-Host "This might be HTML or another format"
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Host "HTTP Status: $($_.Exception.Response.StatusCode)"
    }
}
