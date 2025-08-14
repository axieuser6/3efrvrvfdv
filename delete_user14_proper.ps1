# Delete user14@mocksender.shop using proper credentials
Write-Host "Deleting user14@mocksender.shop from AxieStudio using proper API key..."

$AXIESTUDIO_APP_URL = "https://axiestudio-axiestudio-ttefi.ondigitalocean.app"
$API_KEY = "sk-Sikhas4RX3o5P_MqILi5hUyUdNWhA07n0w3Vuy5AYNM"
$TARGET_EMAIL = "user14@mocksender.shop"

try {
    # Step 1: Find the user by email using the existing API key
    Write-Host "Step 1: Finding user $TARGET_EMAIL..."
    
    $usersResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/users/?x-api-key=$API_KEY" -Method GET
    
    Write-Host "Total users found: $($usersResponse.Count)"
    
    $targetUser = $usersResponse | Where-Object { $_.username -eq $TARGET_EMAIL }
    
    if (-not $targetUser) {
        Write-Host "User $TARGET_EMAIL not found in AxieStudio"
        Write-Host "Available users:"
        $usersResponse | ForEach-Object { 
            if ($_.username) {
                Write-Host "   - $($_.username) (ID: $($_.id))" 
            }
        }
        exit 1
    }
    
    Write-Host "Found user: $($targetUser.username) (ID: $($targetUser.id))"
    
    # Step 2: Delete the user
    Write-Host "Step 2: Deleting user $TARGET_EMAIL..."
    
    $deleteResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/users/$($targetUser.id)?x-api-key=$API_KEY" -Method DELETE -Headers @{"x-api-key" = $API_KEY}
    
    Write-Host "User $TARGET_EMAIL deleted successfully!"
    Write-Host "Deletion completed!"
    
    # Step 3: Verify deletion
    Write-Host "Step 3: Verifying deletion..."
    
    $verifyResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/users/?x-api-key=$API_KEY" -Method GET
    $stillExists = $verifyResponse | Where-Object { $_.username -eq $TARGET_EMAIL }
    
    if ($stillExists) {
        Write-Host "ERROR: User still exists after deletion!"
    } else {
        Write-Host "SUCCESS: User successfully removed from AxieStudio!"
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Full error details:"
    Write-Host $_.Exception
}

Write-Host ""
Write-Host "Check your admin panel: https://axiestudio-axiestudio-ttefi.ondigitalocean.app/admin"
