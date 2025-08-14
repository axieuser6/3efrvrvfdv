# Test direct API key from credentials
Write-Host "Testing direct API key from credentials file..."

$AXIESTUDIO_APP_URL = "https://axiestudio-axiestudio-ttefi.ondigitalocean.app"
$DIRECT_API_KEY = "sk-Sikhas4RX3o5P_MqILi5hUyUdNWhA07n0w3Vuy5AYNM"

try {
    Write-Host "Testing with direct API key: $($DIRECT_API_KEY.Substring(0, 20))..."
    
    # Test different endpoints
    $endpoints = @(
        "/api/v1/users/",
        "/api/v1/users",
        "/api/users/",
        "/api/users"
    )
    
    foreach ($endpoint in $endpoints) {
        Write-Host ""
        Write-Host "Testing endpoint: $endpoint"
        
        try {
            $url = "$AXIESTUDIO_APP_URL$endpoint" + "?x-api-key=$DIRECT_API_KEY"
            Write-Host "Full URL: $url"
            
            $response = Invoke-RestMethod -Uri $url -Method GET -Headers @{"x-api-key" = $DIRECT_API_KEY}
            
            Write-Host "SUCCESS! Response type: $($response.GetType().Name)"
            Write-Host "Response count: $($response.Count)"
            
            if ($response.Count -gt 0) {
                Write-Host "First user properties:"
                $response[0].PSObject.Properties | ForEach-Object {
                    Write-Host "   $($_.Name): '$($_.Value)'"
                }
                
                # Look for our target user
                $targetUser = $response | Where-Object { 
                    $_.username -eq "user14@mocksender.shop" -or 
                    $_.email -eq "user14@mocksender.shop" -or
                    $_.name -eq "user14@mocksender.shop"
                }
                
                if ($targetUser) {
                    Write-Host "FOUND TARGET USER!"
                    Write-Host "Target user ID: $($targetUser.id)"
                    Write-Host "Target user details:"
                    $targetUser.PSObject.Properties | ForEach-Object {
                        Write-Host "   $($_.Name): '$($_.Value)'"
                    }
                    
                    # Try to delete
                    Write-Host ""
                    Write-Host "Attempting to delete user..."
                    $deleteUrl = "$AXIESTUDIO_APP_URL/api/v1/users/$($targetUser.id)?x-api-key=$DIRECT_API_KEY"
                    Write-Host "Delete URL: $deleteUrl"
                    
                    $deleteResponse = Invoke-RestMethod -Uri $deleteUrl -Method DELETE -Headers @{"x-api-key" = $DIRECT_API_KEY}
                    Write-Host "DELETE SUCCESS!"
                    
                    break
                }
            }
            
        } catch {
            Write-Host "Failed: $($_.Exception.Message)"
        }
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
}
