# Delete user14@mocksender.shop using FULL authentication flow
Write-Host "Deleting user14@mocksender.shop from AxieStudio using FULL auth flow..."

$AXIESTUDIO_APP_URL = "https://axiestudio-axiestudio-ttefi.ondigitalocean.app"
$USERNAME = "stefan@axiestudio.se"
$PASSWORD = "STEfanjohn!12"
$TARGET_EMAIL = "user14@mocksender.shop"

try {
    # Step 1: Login to get JWT token
    Write-Host "Step 1: Login to AxieStudio to get JWT token..."
    
    $loginBody = "username=$USERNAME&password=$PASSWORD"
    $loginResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/login" -Method POST -ContentType "application/x-www-form-urlencoded" -Body $loginBody
    
    if (-not $loginResponse.access_token) {
        throw "Failed to get access token from login"
    }
    
    $access_token = $loginResponse.access_token
    Write-Host "Login successful! Got JWT token: $($access_token.Substring(0, 20))..."
    
    # Step 2: Create API key using JWT token
    Write-Host "Step 2: Creating API key using JWT token..."
    
    $apiKeyHeaders = @{
        "Authorization" = "Bearer $access_token"
        "Content-Type" = "application/json"
    }
    
    $apiKeyBody = @{
        name = "Delete User API Key $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    } | ConvertTo-Json
    
    $apiKeyResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/api_key/" -Method POST -Headers $apiKeyHeaders -Body $apiKeyBody
    
    if (-not $apiKeyResponse.api_key) {
        throw "Failed to create API key"
    }
    
    $api_key = $apiKeyResponse.api_key
    Write-Host "API key created successfully: $($api_key.Substring(0, 20))..."
    
    # Step 3: Find user by email
    Write-Host "Step 3: Finding user $TARGET_EMAIL..."
    
    $usersResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/users/?x-api-key=$api_key" -Method GET
    
    Write-Host "Total users found: $($usersResponse.Count)"
    
    # Debug: Show all users
    Write-Host "All users in system:"
    $usersResponse | ForEach-Object { 
        if ($_.username) {
            Write-Host "   - Username: '$($_.username)' (ID: $($_.id))" 
        } else {
            Write-Host "   - No username (ID: $($_.id))"
        }
    }
    
    $targetUser = $usersResponse | Where-Object { $_.username -eq $TARGET_EMAIL }
    
    if (-not $targetUser) {
        Write-Host "ERROR: User $TARGET_EMAIL not found in AxieStudio"
        exit 1
    }
    
    Write-Host "SUCCESS: Found target user: $($targetUser.username) (ID: $($targetUser.id))"
    
    # Step 4: Delete the user
    Write-Host "Step 4: Deleting user $TARGET_EMAIL..."
    
    $deleteResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/users/$($targetUser.id)?x-api-key=$api_key" -Method DELETE -Headers @{"x-api-key" = $api_key}
    
    Write-Host "SUCCESS: User $TARGET_EMAIL deleted!"
    
    # Step 5: Verify deletion
    Write-Host "Step 5: Verifying deletion..."
    
    $verifyResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/users/?x-api-key=$api_key" -Method GET
    $stillExists = $verifyResponse | Where-Object { $_.username -eq $TARGET_EMAIL }
    
    if ($stillExists) {
        Write-Host "ERROR: User still exists after deletion!"
    } else {
        Write-Host "SUCCESS: User completely removed from AxieStudio!"
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Host "HTTP Status: $($_.Exception.Response.StatusCode)"
    }
}

Write-Host ""
Write-Host "Check admin panel: https://axiestudio-axiestudio-ttefi.ondigitalocean.app/admin"
