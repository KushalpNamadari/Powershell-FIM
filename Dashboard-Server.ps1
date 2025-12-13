# Dashboard Server for FIM
# Import Authentication Module
. "$PSScriptRoot\Auth.ps1"

$BasePath = "$env:USERPROFILE\FIM"
$DashboardPath = "$PSScriptRoot\dashboard"

# Check if credentials exist
if (!(Test-Path (Join-Path $BasePath "credentials.enc"))) {
    Write-Host "No credentials found. Please run FIM-Enhanced.ps1 with option A first." -ForegroundColor Red
    exit
}

Write-Host "Starting FIM Dashboard Server..." -ForegroundColor Cyan

# Create HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8080/")

try {
    $listener.Start()
    Write-Host "Dashboard server started at http://localhost:8080" -ForegroundColor Green
    Write-Host "Opening dashboard in browser..." -ForegroundColor Cyan
    
    # Open browser
    Start-Process "http://localhost:8080/login.html"
    
    Write-Host "`nServer is running. Press Ctrl+C to stop." -ForegroundColor Yellow
    
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        # Enable CORS
        $response.Headers.Add("Access-Control-Allow-Origin", "*")
        $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Authorization")
        
        # Handle OPTIONS preflight
        if ($request.HttpMethod -eq "OPTIONS") {
            $response.StatusCode = 200
            $response.Close()
            continue
        }
        
        $url = $request.Url.LocalPath
        $method = $request.HttpMethod
        
        Write-Host "$method $url" -ForegroundColor Gray
        
        # Route handling
        if ($url -eq "/api/login" -and $method -eq "POST") {
            # Handle login
            $reader = New-Object System.IO.StreamReader($request.InputStream)
            $body = $reader.ReadToEnd()
            $reader.Close()
            
            try {
                $credentials = $body | ConvertFrom-Json
                $isValid = Verify-Credentials -Username $credentials.username -Password $credentials.password
                
                if ($isValid) {
                    $token = Get-AuthToken -Username $credentials.username
                    $responseData = @{
                        success = $true
                        token = $token
                        message = "Login successful"
                    } | ConvertTo-Json
                    
                    Write-Host "Login successful: $($credentials.username)" -ForegroundColor Green
                } else {
                    $responseData = @{
                        success = $false
                        message = "Invalid credentials"
                    } | ConvertTo-Json
                    
                    Write-Host "Login failed: Invalid credentials" -ForegroundColor Red
                }
                
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseData)
                $response.ContentType = "application/json"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            } catch {
                Write-Host "Error processing login: $_" -ForegroundColor Red
            }
        }
        elseif ($url -eq "/api/changes" -and $method -eq "GET") {
            # Get changes history
            try {
                $ChangesLogPath = Join-Path $BasePath "changes.log"
                
                $changes = @()
                if (Test-Path $ChangesLogPath) {
                    $lines = Get-Content -Path $ChangesLogPath
                    
                    foreach ($line in $lines) {
                        if ($line -match "^\{") {
                            try {
                                $change = $line | ConvertFrom-Json
                                if ($change.Timestamp) {
                                    $changes += $change
                                }
                            } catch {
                                # Skip invalid JSON lines
                            }
                        }
                    }
                }
                
                $responseData = @{
                    success = $true
                    changes = $changes
                } | ConvertTo-Json -Depth 10
                
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseData)
                $response.ContentType = "application/json"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            } catch {
                Write-Host "Error getting changes: $_" -ForegroundColor Red
            }
        }
        elseif ($url -eq "/api/restore" -and $method -eq "POST") {
            # Restore file version
            $reader = New-Object System.IO.StreamReader($request.InputStream)
            $body = $reader.ReadToEnd()
            $reader.Close()
            
            try {
                $data = $body | ConvertFrom-Json
                $versionId = $data.versionId
                
                # Find the version
                $ChangesLogPath = Join-Path $BasePath "changes.log"
                $VersionsPath = Join-Path $BasePath "Versions"
                
                $changes = @()
                $lines = Get-Content -Path $ChangesLogPath
                foreach ($line in $lines) {
                    if ($line -match "^\{") {
                        try {
                            $change = $line | ConvertFrom-Json
                            if ($change.VersionId -eq $versionId) {
                                $targetChange = $change
                                break
                            }
                        } catch {}
                    }
                }
                
                if ($targetChange) {
                    # Find version file
                    $versionFile = Get-ChildItem -Path $VersionsPath -Filter "$versionId*" | Select-Object -First 1
                    
                    if ($versionFile) {
                        Copy-Item -Path $versionFile.FullName -Destination $targetChange.FilePath -Force
                        
                        # Log the restoration
                        $changeEntry = @{
                            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                            FilePath = $targetChange.FilePath
                            ChangeType = "Restored"
                            Hash = (Get-FileHash -Path $targetChange.FilePath -Algorithm SHA512).Hash
                            VersionId = [System.Guid]::NewGuid().ToString()
                        }
                        
                        $changeEntry | ConvertTo-Json -Compress | Out-File -FilePath $ChangesLogPath -Append
                        
                        $responseData = @{
                            success = $true
                            message = "File restored successfully"
                        } | ConvertTo-Json
                        
                        Write-Host "File restored: $($targetChange.FilePath)" -ForegroundColor Green
                    } else {
                        $responseData = @{
                            success = $false
                            message = "Version file not found"
                        } | ConvertTo-Json
                    }
                } else {
                    $responseData = @{
                        success = $false
                        message = "Version not found"
                    } | ConvertTo-Json
                }
                
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseData)
                $response.ContentType = "application/json"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            } catch {
                Write-Host "Error restoring file: $_" -ForegroundColor Red
                $responseData = @{
                    success = $false
                    message = "Error: $_"
                } | ConvertTo-Json
                
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseData)
                $response.ContentType = "application/json"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
        }
        elseif ($url -match "\.(html|css|js)$") {
            # Serve static files
            $filePath = Join-Path $DashboardPath ($url.TrimStart('/'))
            
            if (Test-Path $filePath) {
                $content = Get-Content -Path $filePath -Raw -Encoding UTF8
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
                
                # Set content type
                if ($url -match "\.html$") { $response.ContentType = "text/html" }
                elseif ($url -match "\.css$") { $response.ContentType = "text/css" }
                elseif ($url -match "\.js$") { $response.ContentType = "application/javascript" }
                
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            } else {
                $response.StatusCode = 404
            }
        }
        else {
            # 404 for unknown routes
            $response.StatusCode = 404
        }
        
        $response.Close()
    }
} catch {
    Write-Host "Server error: $_" -ForegroundColor Red
} finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
    Write-Host "`nServer stopped." -ForegroundColor Yellow
}
