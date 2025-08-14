# Test AxieStudio API - Create and Delete User
Write-Host "Testing AxieStudio API..."

$AXIESTUDIO_APP_URL = "https://axiestudio-axiestudio-ttefi.ondigitalocean.app"
$USERNAME = "stefan@axiestudio.se"
$PASSWORD = "STEfanjohn!12"
$TEST_EMAIL = "test-user-$(Get-Date -Format 'yyyyMMdd-HHmmss')@example.com"
$TEST_PASSWORD = "TestPassword123!"

Write-Host "Test user email: $TEST_EMAIL"

try {
    # Step 1: Login to get JWT token
    Write-Host "Step 1: Logging in..."
    
    $loginBody = "username=$USERNAME&password=$PASSWORD"
    
    $loginResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/login" -Method POST -ContentType "application/x-www-form-urlencoded" -Body $loginBody
    $access_token = $loginResponse.access_token
    
    Write-Host "Login successful, got token"
    
    # Step 2: Create API key
    Write-Host "Step 2: Creating API key..."
    
    $apiKeyHeaders = @{
        "Authorization" = "Bearer $access_token"
        "Content-Type" = "application/json"
    }
    
    $apiKeyBody = @{
        name = "Test API Key"
    } | ConvertTo-Json
    
    $apiKeyResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/api_key/" -Method POST -Headers $apiKeyHeaders -Body $apiKeyBody
    $api_key = $apiKeyResponse.api_key
    
    Write-Host "API key created"
    
    # Step 3: Create test user
    Write-Host "Step 3: Creating test user..."
    
    $userHeaders = @{
        "x-api-key" = $api_key
        "Content-Type" = "application/json"
    }
    
    $userData = @{
        username = $TEST_EMAIL
        password = $TEST_PASSWORD
        is_active = $true
        is_superuser = $false
    } | ConvertTo-Json
    
    $userResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/users/?x-api-key=$api_key" -Method POST -Headers $userHeaders -Body $userData
    
    Write-Host "User created successfully!"
    Write-Host "User ID: $($userResponse.id)"
    Write-Host "Email: $($userResponse.username)"
    
    # Wait for admin check
    Write-Host "Waiting 10 seconds for admin check..."
    Start-Sleep -Seconds 10
    
    # Step 4: Delete the test user
    Write-Host "Step 4: Deleting test user..."
    
    $deleteResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/users/$($userResponse.id)?x-api-key=$api_key" -Method DELETE -Headers @{"x-api-key" = $api_key}
    
    Write-Host "User deleted successfully!"
    Write-Host "API test completed!"
    
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}
