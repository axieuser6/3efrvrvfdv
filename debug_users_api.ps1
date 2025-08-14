# Debug the users API response structure
Write-Host "Debugging AxieStudio Users API response..."

$AXIESTUDIO_APP_URL = "https://axiestudio-axiestudio-ttefi.ondigitalocean.app"
$USERNAME = "stefan@axiestudio.se"
$PASSWORD = "STEfanjohn!12"

try {
    # Step 1: Login
    Write-Host "Step 1: Authenticating..."
    
    $loginBody = "username=$USERNAME&password=$PASSWORD"
    $loginResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/login" -Method POST -ContentType "application/x-www-form-urlencoded" -Body $loginBody
    $access_token = $loginResponse.access_token
    
    # Step 2: Create API key
    Write-Host "Step 2: Creating API key..."
    
    $apiKeyHeaders = @{
        "Authorization" = "Bearer $access_token"
        "Content-Type" = "application/json"
    }
    
    $apiKeyBody = @{
        name = "Debug API Key $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    } | ConvertTo-Json
    
    $apiKeyResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/api_key/" -Method POST -Headers $apiKeyHeaders -Body $apiKeyBody
    $api_key = $apiKeyResponse.api_key
    
    # Step 3: Get users and debug response
    Write-Host "Step 3: Getting users and debugging response..."
    
    $usersResponse = Invoke-RestMethod -Uri "$AXIESTUDIO_APP_URL/api/v1/users/?x-api-key=$api_key" -Method GET
    
    Write-Host "Raw response type: $($usersResponse.GetType().Name)"
    Write-Host "Response count: $($usersResponse.Count)"
    
    if ($usersResponse.Count -gt 0) {
        Write-Host "First user object:"
        $firstUser = $usersResponse[0]
        Write-Host "User object type: $($firstUser.GetType().Name)"
        
        # Show all properties of first user
        Write-Host "All properties of first user:"
        $firstUser.PSObject.Properties | ForEach-Object {
            Write-Host "   $($_.Name): '$($_.Value)'"
        }
        
        Write-Host ""
        Write-Host "Looking for user14@mocksender.shop in all users:"
        for ($i = 0; $i -lt $usersResponse.Count; $i++) {
            $user = $usersResponse[$i]
            Write-Host "User $i properties:"
            $user.PSObject.Properties | ForEach-Object {
                if ($_.Name -like "*user*" -or $_.Name -like "*email*" -or $_.Name -like "*name*") {
                    Write-Host "   $($_.Name): '$($_.Value)'"
                }
            }
            
            # Check if this user matches our target
            $user.PSObject.Properties | ForEach-Object {
                if ($_.Value -eq "user14@mocksender.shop") {
                    Write-Host "FOUND TARGET USER at index $i with property '$($_.Name)'"
                }
            }
            Write-Host ""
        }
    } else {
        Write-Host "No users returned from API"
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Host "HTTP Status: $($_.Exception.Response.StatusCode)"
    }
}
