# Authentication Module for FIM Dashboard

Function Initialize-Credentials {
    $BasePath = "$env:USERPROFILE\FIM"
    $CredsFile = Join-Path $BasePath "credentials.enc"
    
    if (Test-Path $CredsFile) {
        Write-Host "Credentials already exist." -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "`n=== First Time Setup - Create Dashboard Credentials ===" -ForegroundColor Cyan
    Write-Host "These credentials will be used to access the FIM Dashboard"
    
    $username = Read-Host "Enter username"
    while ([string]::IsNullOrWhiteSpace($username)) {
        Write-Host "Username cannot be empty!" -ForegroundColor Red
        $username = Read-Host "Enter username"
    }
    
    $password = Read-Host "Enter password" -AsSecureString
    $confirmPassword = Read-Host "Confirm password" -AsSecureString
    
    # Convert SecureString to plain text for comparison
    $pwd1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
    $pwd2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword))
    
    if ($pwd1 -ne $pwd2) {
        Write-Host "Passwords do not match!" -ForegroundColor Red
        return $false
    }
    
    if ($pwd1.Length -lt 6) {
        Write-Host "Password must be at least 6 characters long!" -ForegroundColor Red
        return $false
    }
    
    # Hash the password with salt
    $salt = [System.Guid]::NewGuid().ToString()
    $hashedPassword = Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($pwd1 + $salt))) -Algorithm SHA256
    
    # Store credentials
    $credsData = @{
        Username = $username
        PasswordHash = $hashedPassword.Hash
        Salt = $salt
        CreatedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $credsData | ConvertTo-Json | Out-File -FilePath $CredsFile -Force
    
    Write-Host "`nCredentials created successfully!" -ForegroundColor Green
    Write-Host "Username: $username" -ForegroundColor Green
    return $true
}

Function Verify-Credentials {
    param(
        [string]$Username,
        [string]$Password
    )
    
    $BasePath = "$env:USERPROFILE\FIM"
    $CredsFile = Join-Path $BasePath "credentials.enc"
    
    if (-not (Test-Path $CredsFile)) {
        return $false
    }
    
    $storedCreds = Get-Content -Path $CredsFile | ConvertFrom-Json
    
    if ($Username -ne $storedCreds.Username) {
        return $false
    }
    
    # Hash the provided password with stored salt
    $hashedPassword = Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($Password + $storedCreds.Salt))) -Algorithm SHA256
    
    return ($hashedPassword.Hash -eq $storedCreds.PasswordHash)
}

Function Reset-Credentials {
    $BasePath = "$env:USERPROFILE\FIM"
    $CredsFile = Join-Path $BasePath "credentials.enc"
    
    if (Test-Path $CredsFile) {
        Remove-Item -Path $CredsFile -Force
        Write-Host "Credentials reset. Please run setup again." -ForegroundColor Yellow
    }
}

Function Get-AuthToken {
    param(
        [string]$Username
    )
    
    $token = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$Username|$(Get-Date)|$([System.Guid]::NewGuid())"))
    return $token
}
