# Shadow App Backend - Remote CLI Client

A command-line tool for accessing your Shadow App Backend Server remotely from any machine.

## Quick Start

### 1. Prerequisites

- **Dart SDK** 3.0 or higher ([Install Dart](https://dart.dev/get-dart))
- **Network access** to your backend server
- **Server URL** (e.g., `http://192.168.1.100:8080`)
- **Credentials** (email/password or admin key)

### 2. Setup

Clone or download the CLI client:

```bash
cd cli_client
pub get
```

Make the client executable (on Linux/macOS):

```bash
chmod +x bin/client.dart
```

### 3. Check Server Health

```bash
dart bin/client.dart --server http://192.168.1.100:8080 --health
```

### 4. Login

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email user@example.com \
  --password mypassword \
  --login
```

**Note:** The token will be used for subsequent commands in the same session. For persistent authentication, save the token:

```bash
TOKEN=$(dart bin/client.dart ... --login 2>&1 | grep "token:")
# Use $TOKEN in subsequent requests
```

## Commands

### User Management

**List all users:**

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email user@example.com \
  --password pass \
  --login \
  --list-users
```

### Collection Management

**List all collections:**

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email user@example.com \
  --password pass \
  --login \
  --list-collections
```

**Create a new collection:**

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email user@example.com \
  --password pass \
  --login \
  --create-collection "my_collection"
```

### Document Operations

**List documents in a collection:**

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email user@example.com \
  --password pass \
  --login \
  --list-documents "collection_id_here"
```

**Create a document:**

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email user@example.com \
  --password pass \
  --login \
  --create-document "collection_id" \
  --data '{"title":"Hello","content":"World"}'
```

Or from a file:

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email user@example.com \
  --password pass \
  --login \
  --create-document "collection_id" \
  --data @data.json
```

**Read a document:**

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email user@example.com \
  --password pass \
  --login \
  --read-document "collection_id" \
  --document-id "doc_id"
```

**Update a document:**

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email user@example.com \
  --password pass \
  --login \
  --update-document "collection_id" \
  --document-id "doc_id" \
  --data '{"title":"Updated"}'
```

**Delete a document:**

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email user@example.com \
  --password pass \
  --login \
  --delete-document "collection_id" \
  --document-id "doc_id"
```

### Logging & Monitoring

**View audit logs:**

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email user@example.com \
  --password pass \
  --login \
  --view-logs 50
```

### Advanced SQL Queries (Admin)

Use `--sql` to run SQL query blocks (up to 5 statements). This includes read and destructive/write SQL for admin users.

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email admin@example.com \
  --password pass \
  --login \
  --sql "SELECT id, owner_id FROM documents LIMIT 10"
```

With bind parameters:

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email admin@example.com \
  --password pass \
  --login \
  --sql "SELECT id, owner_id FROM documents WHERE owner_id = ? LIMIT 10" \
  --sql-params '["user123"]'
```

JSON attribute example:

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email admin@example.com \
  --password pass \
  --login \
  --sql "SELECT json_extract(data, '\$.status') AS status, COUNT(*) AS total FROM documents GROUP BY status"
```

Destructive/write query example:

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email admin@example.com \
  --password pass \
  --login \
  --sql "UPDATE users SET role='admin' WHERE email='ops@example.com'"
```

Multi-statement example (max 5):

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email admin@example.com \
  --password pass \
  --login \
  --sql "DELETE FROM documents WHERE owner_id='legacy_user'; SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 5"
```

Row cap override for current client run/session:

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email admin@example.com \
  --password pass \
  --login \
  --sql "SELECT * FROM documents" \
  --sql-cap 1000

dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email admin@example.com \
  --password pass \
  --login \
  --sql "SELECT * FROM documents" \
  --sql-cap-off
```

Safety rules:

- Maximum 5 statements per request.
- SQL is admin-only.
- Result rows are capped by default; use `--sql-cap` or `--sql-cap-off` per current run.

## Admin Operations

For admin-only operations, use the `--admin-key` flag instead of logging in:

```bash
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --admin-key secret_admin_key \
  --list-users
```

## Script Examples

### Bash Script: Backup All Documents

```bash
#!/bin/bash

SERVER="http://192.168.1.100:8080"
EMAIL="admin@example.com"
PASSWORD="admin_password"

# List all collections
COLLECTIONS=$(dart bin/client.dart --server $SERVER --email $EMAIL --password $PASSWORD --login --list-collections 2>&1)

echo "Backing up all documents..."

# For each collection, list and backup documents
# (This is a simplified example - expand as needed)
```

### Bash Script: Bulk Import Documents

```bash
#!/bin/bash

SERVER="http://192.168.1.100:8080"
EMAIL="user@example.com"
PASSWORD="password"
COLLECTION_ID="col_123"

# Import all JSON files from a directory
for file in documents/*.json; do
  echo "Importing $file..."
  dart bin/client.dart \
    --server $SERVER \
    --email $EMAIL \
    --password $PASSWORD \
    --login \
    --create-document $COLLECTION_ID \
    --data @$file
done
```

### Python Script: Remote Backup

```python
#!/usr/bin/env python3

import subprocess
import json
import sys

def run_client(args):
    """Run the Dart CLI client and return output"""
    cmd = ['dart', 'bin/client.dart'] + args
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout + result.stderr

def backup_collections(server, email, password):
    """Backup all collections and documents"""

    # List collections
    output = run_client([
        '--server', server,
        '--email', email,
        '--password', password,
        '--login',
        '--list-collections'
    ])

    print("Collections output:")
    print(output)
    # Parse and backup each collection...

if __name__ == '__main__':
    backup_collections('http://192.168.1.100:8080', 'user@ex.com', 'pass')
```

## API Reference

### Options

| Option                | Short | Description             | Example                                                        |
| --------------------- | ----- | ----------------------- | -------------------------------------------------------------- |
| `--server`            | `-s`  | Server URL (required)   | `http://localhost:8080`                                        |
| `--email`             | `-e`  | Email for login         | `user@example.com`                                             |
| `--password`          | `-p`  | Password for login      | `mypass`                                                       |
| `--admin-key`         | `-a`  | Admin key for admin ops | `secret_key`                                                   |
| `--login`             | -     | Authenticate            | `--login`                                                      |
| `--health`            | -     | Check server status     | `--health`                                                     |
| `--list-users`        | -     | List all users          | `--list-users`                                                 |
| `--list-collections`  | -     | List all collections    | `--list-collections`                                           |
| `--list-documents`    | `-l`  | List docs in collection | `--list-documents col_id`                                      |
| `--create-collection` | -     | Create collection       | `--create-collection "name"`                                   |
| `--create-document`   | -     | Create document         | `--create-document col_id --data '{...}'`                      |
| `--read-document`     | -     | Read document           | `--read-document col_id --document-id doc_id`                  |
| `--update-document`   | -     | Update document         | `--update-document col_id --document-id doc_id --data '{...}'` |
| `--delete-document`   | -     | Delete document         | `--delete-document col_id --document-id doc_id`                |
| `--document-id`       | `-d`  | Document ID for ops     | `--document-id doc_123`                                        |
| `--data`              | -     | JSON data or file       | `'{"key":"value"}'` or `@file.json`                            |
| `--view-logs`         | -     | View audit logs         | `--view-logs 50`                                               |
| `--help`              | `-h`  | Show help               | `--help`                                                       |

## Network Access & Security

### Exposing Your Server

To access the server from another machine on your network:

1. **Ensure server is listening on all interfaces:**

   ```bash
   # On the server machine
   dart bin/main.dart server --host 0.0.0.0 --port 8080
   ```

2. **Find your server's IP address:**

   Linux/macOS:

   ```bash
   ifconfig | grep "inet "
   ```

   Windows:

   ```bash
   ipconfig
   ```

3. **Use that IP in the client:**
   ```bash
   dart cli_client/bin/client.dart --server http://192.168.1.100:8080 [commands...]
   ```

### Firewall Rules

Allow port 8080 (or your chosen port) through your firewall:

**Linux (UFW):**

```bash
sudo ufw allow 8080/tcp
```

**macOS (Built-in Firewall):**
System Preferences → Security & Privacy → Firewall → Firewall Options → Add Port 8080

**Windows (Windows Defender Firewall):**
Settings → Privacy & Security → Windows Defender Firewall → Allow an app → Add port 8080

### Security Best Practices

⚠️ **Important:**

1. **Use HTTPS in production:**
   - The example uses `http://` which is unencrypted
   - For production, use HTTPS and SSL certificates
   - See [OPERATOR_MANUAL.md](../docs/OPERATOR_MANUAL.md) for production setup

2. **Protect credentials:**
   - Never commit credentials to version control
   - Use environment variables: `dart bin/client.dart --server $SERVER_URL --email $EMAIL --password $PASSWORD`
   - Consider using a proxy or SSH tunnel for additional security

3. **Admin key rotation:**
   - Change admin keys regularly
   - Never share admin keys over unencrypted channels
   - Use different keys for different environments (dev/staging/prod)

## Troubleshooting

### Connection Refused

```
❌ Connection error: Connection refused
```

**Solution:** Ensure the server is running and accessible:

```bash
# Start server (on server machine)
dart bin/main.dart server --host 0.0.0.0 --port 8080

# Test connection
dart cli_client/bin/client.dart --server http://<SERVER_IP>:8080 --health
```

### Server Not Responding

```
❌ Request timeout: Server did not respond within 10 seconds
```

**Solution:**

- Check network connectivity: `ping <SERVER_IP>`
- Verify firewall rules allow port 8080
- Check server logs for errors

### Authentication Failed

```
❌ Login failed: Invalid credentials
```

**Solution:**

- Verify email and password are correct
- Check that the user exists: `--list-users`
- Ensure server is running: `--health`

### JSON Parse Error

```
❌ Error parsing JSON: Unexpected character
```

**Solution:**

- Use proper JSON formatting: `'{"key":"value"}'`
- Escape quotes properly in shell: `'{"key":"with \"quotes\""}'`
- Or use a file: `--data @file.json`

## Development

### Building from Source

```bash
cd cli_client
pub get
dart bin/client.dart --help
```

### Running Tests

```bash
cd cli_client
pub run test
```

### Contributing

- Report bugs on the project's issue tracker
- Submit pull requests for improvements
- Follow Dart code style guidelines

## See Also

- [Server Architecture](../docs/ARCHITECTURE.md)
- [Operator Manual](../docs/OPERATOR_MANUAL.md)
- [Flutter SDK Guide](../docs/FLUTTER_SDK_GUIDE.md)

## License

Same as Shadow App Backend Server
