Write-Host "Running migration to fix signup trigger..."

$migrationSql = Get-Content "supabase\migrations\20250813172500_fix_signup_trigger.sql" -Raw

$headers = @{
    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90aHNubm9uY25lcmpvZ3Z3amdjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MjE1NjU0NywiZXhwIjoyMDY3NzMyNTQ3fQ.A2RJXKqCt69OWsS761vj1xYRu9nJ-v14O5-XrcMLvHA"
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90aHNubm9uY25lcmpvZ3Z3amdjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MjE1NjU0NywiZXhwIjoyMDY3NzMyNTQ3fQ.A2RJXKqCt69OWsS761vj1xYRu9nJ-v14O5-XrcMLvHA"
    "Content-Type" = "application/json"
}

$body = @{
    sql = $migrationSql
} | ConvertTo-Json

try {
    Write-Host "Executing migration SQL..."
    $response = Invoke-WebRequest -Uri "https://othsnnoncnerjogvwjgc.supabase.co/rest/v1/rpc/exec_sql" -Method POST -Headers $headers -Body $body
    Write-Host "Migration executed successfully!"
    Write-Host "Response:" $response.Content
} catch {
    Write-Host "Error executing migration:" $_.Exception.Message
}
