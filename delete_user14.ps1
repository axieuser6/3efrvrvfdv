# Delete user14@mocksender.shop from AxieStudio
Write-Host "Deleting user14@mocksender.shop from AxieStudio..."

$AXIESTUDIO_APP_URL = "https://axiestudio-axiestudio-ttefi.ondigitalocean.app"
$USERNAME = "stefan@axiestudio.se"
$PASSWORD = "STEfanjohn!12"
$TARGET_EMAIL = "user14@mocksender.shop"

try {
    # Step 1: Login to get access token
    Write-Host "Step 1: Authenticating with AxieStudio..."

    $loginBody = "username=$USERNAME&password=$PASSWORD"

    $loginResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/login" -Method POST -ContentType "application/x-www-form-urlencoded" -Body $loginBody
    $access_token = $loginResponse.access_token

    Write-Host "Login successful, got access token: $($access_token.Substring(0, 20))..."

    # Step 2: Create API key
    Write-Host "Step 2: Creating API key..."

    $apiKeyHeaders = @{
        "Authorization" = "Bearer $access_token"
        "Content-Type" = "application/json"
    }

    $apiKeyBody = @{
        name = "Delete User API Key $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    } | ConvertTo-Json

    $apiKeyResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/api_key/" -Method POST -Headers $apiKeyHeaders -Body $apiKeyBody
    $api_key = $apiKeyResponse.api_key
    
    Write-Host "API key created: $($api_key.Substring(0, 20))..."

    # Step 3: Find the user by email
    Write-Host "Step 3: Finding user $TARGET_EMAIL..."
    
    $usersResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/users/?x-api-key=$api_key" -Method GET
    
    $targetUser = $usersResponse | Where-Object { $_.username -eq $TARGET_EMAIL }
    
    if (-not $targetUser) {
        Write-Host "User $TARGET_EMAIL not found in AxieStudio"
        Write-Host "Available users:"
        $usersResponse | ForEach-Object { Write-Host "   - $($_.username) (ID: $($_.id))" }
        exit 1
    }

    Write-Host "Found user: $($targetUser.username) (ID: $($targetUser.id))"

    # Step 4: Delete the user
    Write-Host "Step 4: Deleting user $TARGET_EMAIL..."
    
    $deleteResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/users/$($targetUser.id)?x-api-key=$api_key" -Method DELETE -Headers @{"x-api-key" = $api_key}

    Write-Host "User $TARGET_EMAIL deleted successfully!"
    Write-Host "Deletion completed!"

    # Step 5: Verify deletion
    Write-Host "Step 5: Verifying deletion..."
    
    $verifyResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/users/?x-api-key=$api_key" -Method GET
    $stillExists = $verifyResponse | Where-Object { $_.username -eq $TARGET_EMAIL }
    
    if ($stillExists) {
        Write-Host "User still exists after deletion!"
    } else {
        Write-Host "User successfully removed from AxieStudio!"
    }

} catch {
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Full error details:"
    Write-Host $_.Exception
}

Write-Host ""
Write-Host "Check your admin panel: https://axiestudio-axiestudio-ttefi.ondigitalocean.app/admin"
