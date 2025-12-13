# Powershell-FIM

An advanced PowerShell-based File Integrity Monitor with version control, web dashboard, and authentication.

## Features

### Core Monitoring
- ✅ Collect a baseline of files using SHA512 hashing
- ✅ Continuously monitor file changes, additions, and deletions
- ✅ Real-time notifications for file integrity violations

### Version Control & Recovery
- ✅ Automatic version history tracking with timestamps
- ✅ Restore files to previous versions (like Git version control)
- ✅ Complete change log with all file modifications
- ✅ Version snapshots stored securely

### Web Dashboard
- ✅ Modern, responsive web interface
- ✅ Secure login with encrypted credentials
- ✅ Real-time change statistics and visualizations
- ✅ Filter and search through change history
- ✅ One-click file restoration to previous versions
- ✅ Auto-refresh every 10 seconds

### Security
- ✅ First-run credential setup
- ✅ Password hashing with salt
- ✅ Authentication required for dashboard access
- ✅ Secure token-based sessions

## Requirements
- Windows OS
- PowerShell 5.1 or higher
- Modern web browser (for dashboard)

## Installation

1. Clone or download this repository
2. Navigate to the folder in PowerShell

## Usage

### Enhanced Version (Recommended)

Run the enhanced version with dashboard support:

```powershell
.\FIM-Enhanced.ps1
```

#### First Run Setup
1. Choose option **A** to create a baseline
2. Set up your dashboard credentials (username and password)
3. Add files/folders you want to monitor
4. The system will create a baseline and start tracking

#### Options Available:
- **A) Collect new baseline** - Initialize monitoring for new files
- **B) Start monitoring** - Begin continuous file integrity monitoring
- **C) Launch Dashboard** - Open the web-based dashboard
- **D) Reset Credentials** - Reset dashboard login credentials

### Dashboard Access

1. Run `FIM-Enhanced.ps1` and select option **C**
2. The dashboard will automatically open in your browser at `http://localhost:8080`
3. Log in with your credentials
4. View all changes, statistics, and restore files as needed

### Dashboard Features:

- **Statistics Cards**: View counts of created, modified, deleted, and restored files
- **Change History Table**: Complete log of all file changes with timestamps
- **Filter Options**: Filter by change type (Created, Modified, Deleted, Restored)
- **Search**: Search for specific files by path
- **Restore Function**: Click "Restore" to revert a file to a previous version
- **Auto-Refresh**: Dashboard updates automatically every 10 seconds

### Legacy Version

The original simple version is still available:

```powershell
.\FIM.ps1
```

## File Structure

```
Powershell-FIM/
├── FIM.ps1                    # Original simple version
├── FIM-Enhanced.ps1           # Enhanced version with version control
├── Auth.ps1                   # Authentication module
├── Dashboard-Server.ps1       # Web server for dashboard
├── dashboard/
│   ├── login.html            # Login page
│   └── dashboard.html        # Main dashboard interface
└── README.md
```

## Data Storage

All FIM data is stored in: `%USERPROFILE%\FIM\`

- `Baseline.txt` - File hashes baseline
- `changes.log` - Complete change history with timestamps
- `credentials.enc` - Encrypted dashboard credentials
- `Versions/` - Directory containing file version backups

## Version Control

The enhanced version automatically creates backups of files when changes are detected:
- Each modification creates a timestamped version
- Versions are stored with unique IDs for precise restoration
- You can restore any file to any previous version from the dashboard
- Restoration events are also logged in the change history

## Security Notes

- Credentials are hashed with SHA256 and salted
- File integrity uses SHA512 hashing
- Dashboard requires authentication for all operations
- All file versions are stored securely in the FIM folder

## Troubleshooting

**Dashboard won't open:**
- Ensure port 8080 is not in use
- Check Windows Firewall settings
- Run PowerShell as Administrator if needed

**Authentication fails:**
- Use option D to reset credentials
- Ensure you remember your username and password
- Run option A again to set up new credentials

**Changes not detected:**
- Ensure monitoring (option B) is running
- Check that files are in the FIM folder
- Verify baseline was created successfully

## License

See LICENSE file for details.
