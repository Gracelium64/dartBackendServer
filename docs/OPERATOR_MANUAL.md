# Shadow App Backend - Operator Manual

## Introduction

This manual is for operators who will run and monitor the Shadow App Backend server. The server handles authentication, database operations, and media storage for Flutter apps.

## Quick Start

### Prerequisites
- Linux/macOS with Dart SDK installed (3.0+)
*/
sudo apt-get update
sudo apt-get install -y apt-transport-https
wget -qO - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'
sudo apt-get update
sudo apt-get install dart
*/

- 100MB free disk space
- Ports 8080 (server) and 8081 (optional admin) available

### Installation & Setup

1. **Clone the repository** (if not already done):
   ```bash
   git clone <repo-url> dartBackendServer
   cd dartBackendServer
   ```

2. **Install dependencies**:
   ```bash
   dart pub get
   ```

3. **Create config file** (optional, uses defaults if missing):
   ```bash
   cp config.example.yaml config.yaml
   # Edit config.yaml with your settings (see Configuration section)
   ```

4. **Start the server**:
   ```bash
   dart bin/main.dart server --port 8080 --db-path data/shadow_app.db
   ```

   Output:
   ```
   ╔════════════════════════════════════════╗
   ║   Shadow App Backend Server v0.1.0    ║
   ║        🚀 Server Starting...           ║
   ╚════════════════════════════════════════╝

   [INFO] Database initialized at data/shadow_app.db
   [INFO] Listening on http://0.0.0.0:8080
   [INFO] Admin key: <random-generated-key> (use for admin console)
   ```

### Running Log Tail (Live Monitoring)

In a **second terminal**, monitor live database actions:

```bash
dart bin/main.dart log-tail
```

Output (ASCII table):
```
╔════════════════════════════════════════════════════════════════════════════════╗
║                      Shadow App Backend - Live Action Log                       ║
╚════════════════════════════════════════════════════════════════════════════════╝

Timestamp                 | User             | Action | Resource      | Status
──────────────────────────┼──────────────────┼────────┼───────────────┼────────
2026-02-14T10:30:05Z      | user@example.com | LOGIN  | user:user-123 | ✓
2026-02-14T10:30:15Z      | user@example.com | CREATE | doc:doc-456   | ✓
2026-02-14T10:30:22Z      | admin@example.com| READ   | doc:doc-456   | ✓
```

### Running Admin Console (Management)

In a **third terminal**, open the admin console for full database management:

```bash
dart bin/main.dart admin --admin-key <key-from-startup-output>
```

Welcome screen:
```
╔════════════════════════════════════════════════════════════════════════════════╗
║                     Shadow App Backend - Admin Console                          ║
╚════════════════════════════════════════════════════════════════════════════════╝

1. Manage Users
2. View Audit Log
3. Execute Raw CRUD
4. View System Stats
5. Configure Rules
6. Generate Reports
7. Exit

Enter your choice (1-7):
```

## Configuration

Create `config.yaml` in the project root:

```yaml
server:
  port: 8080
  host: 0.0.0.0
  enable_cors: true

database:
  path: data/shadow_app.db
  enable_wal: true          # Write-ahead logging for concurrency

logging:
  level: INFO               # DEBUG, INFO, WARN, ERROR
  file_path: data/logs
  retention_days: 7
  daily_rotation: true

auth:
  jwt_secret: your-secret-key-here
  jwt_expiry_hours: 24
  token_refresh_window_hours: 1

email:
  provider: gmail            # Currently only supports Gmail
  smtp_server: smtp.gmail.com
  smtp_port: 587

admin:
  auto_generate_key: true    # Generate random key on startup
```

## Daily Operations

### Start the Server

```bash
# Terminal 1: Start server
dart bin/main.dart server --port 8080 --db-path data/shadow_app.db

# Terminal 2: Monitor logs
dart bin/main.dart log-tail

# Terminal 3 (optional): Admin console
dart bin/main.dart admin --admin-key <key>
```

### Monitor Health

The log tail automatically shows:
- **✓ (green)**: Successful operations
- **✗ (red)**: Failed operations
- **⚠ (yellow)**: Warnings or throttled requests

If you see repeated failures, check data/logs/ for detailed error messages.

### Shutdown

In each terminal, press `Ctrl+C` to stop gracefully. The server will:
1. Stop accepting new requests
2. Wait for in-flight requests to complete (timeout: 30 seconds)
3. Flush logs to disk
4. Close database connection

```
[INFO] Received shutdown signal
[INFO] Closing database connection...
[INFO] All logs flushed
[INFO] Goodbye!
```

## Common Tasks

### Create a New Admin User

Via admin console:
```
Enter your choice: 1
[Admin Users Menu]
1. List Users
2. Add User
3. Delete User
4. Change Role

Enter choice: 2
Email: admin@mycompany.com
Password: <secure password>
Role (admin/user): admin

[SUCCESS] User created with ID: user-abc123
```

### View Audit Log

Via admin console:
```
Enter your choice: 2
[Audit Log Viewer]
Showing last 100 entries (newest first):

2026-02-14T10:30:05Z | user@example.com  | CREATE | document          | success
2026-02-14T10:30:15Z | admin@example.com | UPDATE | collection rules  | success
...
```

Or directly view log files:
```bash
tail -f data/logs/shadow_app_2026-02-14.log
```

### Run a Raw Database Query

Via admin console:
```
Enter your choice: 3
[Execute Raw CRUD]
1. Create Document
2. Read Document
3. Update Document
4. Delete Document
5. List Collection

Enter choice: 1
Collection ID: coll-xyz789
JSON Data: {"name": "Test", "value": 123}

[SUCCESS] Document created: doc-abc456
```

### Export Monthly Logs

Via admin console or automatic (first of month):
```
[System auto-emails previous month's logs to admin@mycompany.com]
```

Or manually:
```
Enter your choice: 6
[Generate Reports]
1. Export Month Logs
2. User Activity Report
3. Storage Usage Report

Enter choice: 1
Month (MM-YYYY): 01-2026
Exporting to archive...
[SUCCESS] Exported 1.2MB to data/exports/logs_01_2026.tar.gz
Email sent to admin@mycompany.com
```

## Troubleshooting

### **Server won't start: "Address already in use"**
- Another process is using port 8080
- Solution: Kill the old process or use `--port 8081`
  ```bash
  lsof -i :8080
  kill <PID>
  # Then retry
  dart bin/main.dart server --port 8080
  ```

### **Database locked errors in logs**
- Multiple writers competing
- Solution: Check admin console for long-running queries; enable WAL mode in config
  ```yaml
  database:
    enable_wal: true
  ```

### **High CPU usage**
- Log tail subscriber lagging
- Solution: Reduce log verbosity: set `logging.level: WARN` in config

### **Email not sending monthly logs**
- Gmail credentials expired or invalid
- Solution: Open admin console, reconfigure Gmail:
  ```
  Enter your choice: 5
  [Configure Rules]
  # Follow Gmail OAuth setup prompts
  ```

### **Lost admin key**
- If you lost the key printed on startup, regenerate:
  ```bash
  dart bin/main.dart admin --admin-key new
  ```
  (will prompt for current DB admin password to reset)

## Performance Tips

1. **Enable WAL mode** in config for concurrent reads
2. **Prune logs** monthly (auto-handled, but confirm in admin console)
3. **Monitor disk space**: SQLite + logs can grow; plan for ~1GB per million operations
4. **Set retention**: Adjust `logging.retention_days` if storage is tight
5. **Backup weekly**: Copy data/shadow_app.db to external storage

## Security Notes

1. **Admin Key**: Treat like a password; don't share in logs or terminal history
2. **JWT Secret**: Keep strong (config.yaml is not version-controlled)
3. **Database File**: Ensure data/shadow_app.db has restricted permissions (0600)
4. **Logs**: May contain sensitive data; archive to secure location

To restrict DB file:
```bash
chmod 600 data/shadow_app.db
```

## Support & Debugging

For detailed server logs:
```bash
# Increase verbosity
dart bin/main.dart server --port 8080 --log-level DEBUG
```

Check full error log:
```bash
tail -100 data/logs/shadow_app_$(date +%Y-%m-%d).log
```

---

**For Flutter SDK setup and usage, see [FLUTTER_SDK_GUIDE.md](FLUTTER_SDK_GUIDE.md)**

**For scaling and maintanence, see [MAINTENANCE_SCALING_GUIDE.md](MAINTENANCE_SCALING_GUIDE.md)**
