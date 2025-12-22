# Enhanced File Integrity Monitor with Version Control and Dashboard
# Import Authentication Module
. "$PSScriptRoot\Auth.ps1"

Write-Host ""
Write-Host "=== File Integrity Monitor with Version Control ===" -ForegroundColor Cyan
Write-Host "What would you like to do?"
Write-Host "A) Collect new baseline (monitor files in original location)"
Write-Host "B) Start monitoring files with saved baseline"
Write-Host "C) Launch Dashboard"
Write-Host "D) Reset Credentials"

$response = Read-Host
Write-Host ""

Function CalcHash($filepath) {
    $filehash = Get-FileHash -Path $filepath -Algorithm SHA512
    return $filehash
}

Function EraseBaseline() {
    $BasePath = "$env:USERPROFILE\FIM"
    $baselinefile = Join-Path $BasePath "Baseline.txt"
    if (Test-Path -Path $baselinefile) {
        Remove-Item -Path $baselinefile -Force
        Write-Host "Old Baseline erased"
    }
}

Function Initialize-VersionControl {
    param([string]$BasePath)
    
    $VersionsPath = Join-Path $BasePath "Versions"
    $ChangesLogPath = Join-Path $BasePath "changes.log"
    
    if (!(Test-Path $VersionsPath)) {
        New-Item -ItemType Directory -Path $VersionsPath | Out-Null
    }
    
    if (!(Test-Path $ChangesLogPath)) {
        $header = @{
            InitializedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Version = "1.0"
        }
        $header | ConvertTo-Json | Out-File -FilePath $ChangesLogPath -Force
    }
}

Function Log-Change {
    param(
        [string]$FilePath,
        [string]$ChangeType,  # Created, Modified, Deleted
        [string]$Hash,
        [string]$BasePath
    )
    
    $ChangesLogPath = Join-Path $BasePath "changes.log"
    
    $changeEntry = @{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        FilePath = $FilePath
        ChangeType = $ChangeType
        Hash = $Hash
        VersionId = [System.Guid]::NewGuid().ToString()
    }
    
    # Append to changes log
    $changeEntry | ConvertTo-Json -Compress | Out-File -FilePath $ChangesLogPath -Append
    
    # Create version backup if file still exists
    if ($ChangeType -ne "Deleted" -and (Test-Path $FilePath)) {
        $VersionsPath = Join-Path $BasePath "Versions"
        $fileName = [System.IO.Path]::GetFileName($FilePath)
        $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $versionFileName = "$($changeEntry.VersionId)_$timestamp`_$fileName"
        $versionFilePath = Join-Path $VersionsPath $versionFileName
        
        Copy-Item -Path $FilePath -Destination $versionFilePath -Force
    }
    
    return $changeEntry
}

Function Get-ChangeHistory {
    param([string]$BasePath)
    
    $ChangesLogPath = Join-Path $BasePath "changes.log"
    
    if (!(Test-Path $ChangesLogPath)) {
        return @()
    }
    
    $changes = @()
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
    
    return $changes
}

Function Restore-FileVersion {
    param(
        [string]$VersionId,
        [string]$BasePath
    )
    
    $ChangesLogPath = Join-Path $BasePath "changes.log"
    $VersionsPath = Join-Path $BasePath "Versions"
    
    # Find the change entry
    $changes = Get-ChangeHistory -BasePath $BasePath
    $targetChange = $changes | Where-Object { $_.VersionId -eq $VersionId }
    
    if (!$targetChange) {
        Write-Host "Version not found!" -ForegroundColor Red
        return $false
    }
    
    # Find the version file
    $versionFile = Get-ChildItem -Path $VersionsPath -Filter "$VersionId*" | Select-Object -First 1
    
    if (!$versionFile) {
        Write-Host "Version file not found!" -ForegroundColor Red
        return $false
    }
    
    # Restore the file
    try {
        Copy-Item -Path $versionFile.FullName -Destination $targetChange.FilePath -Force
        Write-Host "File restored successfully: $($targetChange.FilePath)" -ForegroundColor Green
        
        # Log the restoration
        Log-Change -FilePath $targetChange.FilePath -ChangeType "Restored" -Hash (CalcHash $targetChange.FilePath).Hash -BasePath $BasePath
        return $true
    } catch {
        Write-Host "Failed to restore file: $_" -ForegroundColor Red
        return $false
    }
}

if ($response -ieq "A") {
    # Calculate hash and store in baseline.txt
    $BasePath = "$env:USERPROFILE\FIM"

    # Check if folder already exists
    if (!(Test-Path $BasePath)) {
        New-Item -ItemType Directory -Path $BasePath | Out-Null
        Write-Host "Created new user folder at: $BasePath"
    } else {
        Write-Host "Using existing folder: $BasePath"
    }
    
    # Initialize credentials on first run
    if (!(Test-Path (Join-Path $BasePath "credentials.enc"))) {
        Initialize-Credentials
    }
    
    # Initialize version control
    Initialize-VersionControl -BasePath $BasePath

    # Delete any baselines that already exist
    EraseBaseline

    # Get path to monitor
    $source = Read-Host "Enter the path of file/folder you want to monitor"

    $filesToMonitor = @()
    
    if (Test-Path $source -PathType Leaf) {
        $filesToMonitor += Get-Item $source
        Write-Host "Monitoring file: $source"
    } elseif (Test-Path $source -PathType Container) {
        $filesToMonitor = Get-ChildItem -Path $source -File -Recurse
        Write-Host "Monitoring folder: $source"
    } else {
        Write-Host "Invalid path! Exiting..." 
        exit
    }

    Write-Host "`n== Files to Monitor =="
    $filesToMonitor | Select-Object FullName

    # For each file, calculate the hash and write to baseline.txt
    foreach ($f in $filesToMonitor) {
        $hash = CalcHash $f.FullName
        "$($hash.path)|$($hash.Hash)" | Out-File -FilePath (Join-Path $BasePath "Baseline.txt") -Append
        
        # Log initial baseline creation
        Log-Change -FilePath $f.FullName -ChangeType "Baseline" -Hash $hash.Hash -BasePath $BasePath | Out-Null
    }
    
    Write-Host "`nBaseline created successfully!" -ForegroundColor Green
}
elseif ($response -ieq "B") {
    $HashDirectory = @{}

    # Define FIM folder
    $BasePath = "$env:USERPROFILE\FIM"
    $Baselinefile = Join-Path $BasePath "Baseline.txt"
    
    # Initialize version control
    Initialize-VersionControl -BasePath $BasePath
    
    # Load file|hash from baseline.txt and store them in a dictionary
    $FilePath = Get-Content -Path $Baselinefile -ErrorAction SilentlyContinue
    foreach($f in $FilePath) {
        $parts = $f.Split("|")
        $HashDirectory.Add($parts[0], $parts[1])
    }

    Write-Host "Starting continuous monitoring... Press Ctrl+C to stop..." -ForegroundColor Cyan
    Write-Host "Monitoring $($HashDirectory.Count) file(s)..." -ForegroundColor Yellow
    
    # Begin continuous monitoring files with saved baseline
    while($true) {
        Start-Sleep -Seconds 5

        # Monitor each file from the baseline (create array copy to avoid modification during enumeration)
        $filePathsToCheck = @($HashDirectory.Keys)
        foreach ($filePath in $filePathsToCheck) {
            if (Test-Path -Path $filePath) {
                $hash = CalcHash $filePath

                if ($HashDirectory[$filePath] -ne $hash.Hash) {
                    # Notify user of file modification
                    Write-Host "$($filePath) has changed!!!" -ForegroundColor DarkRed -BackgroundColor White
                    
                    # Create backup before updating hash
                    Log-Change -FilePath $filePath -ChangeType "Modified" -Hash $hash.Hash -BasePath $BasePath | Out-Null
                    $HashDirectory[$filePath] = $hash.Hash
                }
            }
            else {
                # File was deleted
                Write-Host "$($filePath) has been deleted!" -ForegroundColor DarkRed -BackgroundColor White
                Log-Change -FilePath $filePath -ChangeType "Deleted" -Hash $HashDirectory[$filePath] -BasePath $BasePath | Out-Null
            }
        }
    }
}
elseif ($response -ieq "C") {
    # Launch Dashboard
    Write-Host "Launching FIM Dashboard..." -ForegroundColor Cyan
    
    $BasePath = "$env:USERPROFILE\FIM"
    
    # Check if credentials exist
    if (!(Test-Path (Join-Path $BasePath "credentials.enc"))) {
        Write-Host "No credentials found. Please run option A first to set up credentials." -ForegroundColor Red
        exit
    }
    
    # Start the dashboard server
    & "$PSScriptRoot\Dashboard-Server.ps1"
}
elseif ($response -ieq "D") {
    # Reset Credentials
    Reset-Credentials
}
else {
    Write-Host "Invalid option selected!" -ForegroundColor Red
}
