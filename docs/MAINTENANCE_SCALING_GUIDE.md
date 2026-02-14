# Shadow App Backend - Maintenance & Scaling Guide

## For Dart Developers & DevOps Engineers

This guide covers long-term maintenance, scaling strategies, and performance optimization for the Shadow App Backend.

---

## Part 1: Maintenance

### Regular Tasks

#### Daily
- Monitor `data/logs/` directory size
- Check server CPU/memory (should be <5% CPU at idle, <100MB memory)
- Review error logs: `grep ERROR data/logs/shadow_app_*.log`

#### Weekly
- Run integrity check on SQLite database:
  ```bash
  dart bin/main.dart admin --admin-key <key>
  # Admin menu → System Stats → Database Integrity
  ```
- Backup `data/shadow_app.db` to external storage
  ```bash
  cp data/shadow_app.db /backup/shadow_app_$(date +%Y-%m-%d).db
  ```

#### Monthly
1. **Email log export** (automatic, but verify):
   - First day of month, previous month's logs emailed to admin
   - Check email inbox for `shadow_app_logs_previous_month.tar.gz`
2. **Analyze audit trail**:
   ```bash
   # Most active users
   grep "CREATE\|UPDATE\|DELETE" data/logs/shadow_app_2026-01-*.log | wc -l
   
   # Failed operations
   grep "FAILED" data/logs/shadow_app_2026-01-*.log
   ```
3. **Purge old logs** (auto-handled after 7 days, but confirm)
4. **Document changes**: Update changelog if any config/code changes were made

#### Quarterly
- Review and update security settings
- Check Dart ecosystem for security patches
  ```bash
  dart pub outdated
  dart pub upgrade --dry-run
  ```
- Analyze growth rate: documents, users, media storage
- Plan for scaling if approaching limits

### Backup Strategy

**Automated Backup** (recommended):
Set up a cron job to backup daily:

```bash
# Create backup script: backup.sh
#!/bin/bash
BACKUP_DIR="/backup/shadow_app"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
mkdir -p "$BACKUP_DIR"

# Backup database
cp /home/grace64/shadowAppTesting/dartBackendServer/data/shadow_app.db \
   "$BACKUP_DIR/shadow_app_$TIMESTAMP.db"

# Backup logs (last 7 days)
tar -czf "$BACKUP_DIR/logs_$TIMESTAMP.tar.gz" \
    /home/grace64/shadowAppTesting/dartBackendServer/data/logs/

# Keep only last 30 backups
ls -t "$BACKUP_DIR" | tail -n +31 | xargs -r rm

echo "Backup completed: $TIMESTAMP"
```

Add to crontab:
```bash
crontab -e
# Add line:
0 2 * * * /path/to/backup.sh  # Daily at 2 AM
```

**Restore from Backup**:
```bash
# Stop server
dart bin/main.dart server --stop

# Restore database
cp /backup/shadow_app/shadow_app_2026-01-10.db data/shadow_app.db

# Restart server
dart bin/main.dart server --port 8080
```

### Monitoring & Alerts

Set up basic monitoring with a health check endpoint:

In production, configure a monitoring service (e.g., Uptime Robot, Nagios):

```bash
# Check server health (every 5 minutes)
curl -s http://localhost:8080/health | jq .

# Expected response:
# {
#   "status": "ok",
#   "uptime": "72:30:15",
#   "database": "connected",
#   "logs_size_mb": 42.3
# }
```

Alert conditions:
- Response time > 2 seconds
- Error rate > 1%
- Database file > 5GB (for local SQLite)
- Logs directory > 2GB

---

## Part 2: Scaling

### Development → Production

#### Phase 1: Local Development (Now)
- **Database**: SQLite (single file)
- **Deployment**: Single machine
- **Concurrency**: SQLite WAL mode (up to ~50 concurrent writers)
- **Storage**: In-database media blobs
- **Bandwidth**: No significant limits

#### Phase 2: Small Production (10-100 concurrent users)

**Changes**:
1. **Database Migration**: SQLite → PostgreSQL
   ```
   Migration steps (outline):
   - Deploy PostgreSQL server
   - Export SQLite to CSV
   - Import into PostgreSQL
   - Update connection string in config
   - Test all CRUD operations
   ```

2. **Deployment**: Single dedicated machine
   ```
   Spec: 2 CPU, 4GB RAM, 50GB SSD
   OS: Ubuntu 20.04 LTS
   ```

3. **Concurrency**: No limits with PostgreSQL

4. **Media Storage**: Move blobs to S3/compatible service
   ```
   Why: SQLite/PostgreSQL bloats; external storage scales
   Update media_handler.dart:
   - Upload → store in S3, save S3 URL in DB
   - Download → stream from S3
   ```

5. **Admin Console**: Can now connect remotely
   ```
   dart bin/main.dart admin --admin-key <key> \
     --server-url http://prod-server:8080
   ```

#### Phase 3: Medium Production (100-1000 concurrent users)

**Add**:
1. **Load Balancer**: Nginx or HAProxy
   ```nginx
   upstream shadow_backends {
     server backend1:8080;
     server backend2:8080;
     server backend3:8080;
   }
   
   server {
     listen 80;
     location / {
       proxy_pass http://shadow_backends;
       proxy_set_header Authorization $http_authorization;
     }
   }
   ```

2. **Multiple Server Instances**:
   ```bash
   # On separate machines
   Machine 1: dart bin/main.dart server --port 8080 --db postgres://db1:5432...
   Machine 2: dart bin/main.dart server --port 8080 --db postgres://db1:5432...
   Machine 3: dart bin/main.dart server --port 8080 --db postgres://db1:5432...
   ```

3. **Read Replicas**: PostgreSQL streaming replication
   - Primary: accepts writes
   - Replica 1-2: handles reads (halves database load)

4. **Caching**: Add Redis/Memcached for session tokens
   - Reduces database queries
   - Improves login speed

5. **Log Aggregation**: Centralize logs (ELK, Splunk, Datadog)
   - Instead of local files, stream logs to central service
   - Easier analysis and retention

#### Phase 4: Large Production (1000+ concurrent users)

**Add**:
1. **CDN**: CloudFront/Cloudflare for media delivery
2. **Database Sharding**: Partition documents by collection or user
3. **Message Queue**: Redis/RabbitMQ for async log processing
4. **Microservices** (optional): Split auth, CRUD, media into separate services
5. **Monitoring**: Prometheus + Grafana for metrics and dashboards

### Database Migration: SQLite → PostgreSQL

**Step-by-step**:

1. **Export SQLite**:
   ```bash
   sqlite3 data/shadow_app.db << EOF
   .headers on
   .mode csv
   .output users.csv
   SELECT * FROM users;
   .output NULL
   .output collections.csv
   SELECT * FROM collections;
   .output NULL
   .output documents.csv
   SELECT * FROM documents;
   .output NULL
   .output media_blobs.csv
   SELECT id, document_id, file_name, mime_type, original_size, compressed_size, compression_algo, created_at FROM media_blobs;
   .output NULL
   .output audit_log.csv
   SELECT * FROM audit_log;
   EOF
   ```

2. **Set up PostgreSQL**:
   ```bash
   # On PostgreSQL server
   createdb shadow_app
   psql -d shadow_app -c "CREATE USER shadow_user WITH PASSWORD 'strong_password';"
   ```

3. **Update config.yaml**:
   ```yaml
   database:
     type: postgresql
     host: postgres.example.com
     port: 5432
     database: shadow_app
     user: shadow_user
     password: strong_password
   ```

4. **Update Dart code** (lib/database/db_manager.dart):
   ```dart
   // Instead of:
   final db = sqlite3.open('data/shadow_app.db');
   
   // Use:
   final connection = await PgConnection.open(
     Endpoint(
       host: config.database.host,
       port: config.database.port,
       database: config.database.database,
       username: config.database.user,
       password: config.database.password,
     ),
   );
   ```

5. **Import data**:
   ```bash
   psql -d shadow_app -c "\COPY users FROM users.csv CSV HEADER;"
   psql -d shadow_app -c "\COPY collections FROM collections.csv CSV HEADER;"
   # ... etc
   ```

6. **Test**: Run all unit/integration tests; verify CRUD operations work

7. **Deploy**: Update server connection string, restart

### Performance Tuning

#### Database Indexing

Add indexes to frequently queried columns:

```sql
-- For SQLite or PostgreSQL

-- Users: queries by email
CREATE INDEX idx_users_email ON users(email);

-- Documents: queries by collection_id
CREATE INDEX idx_documents_collection ON documents(collection_id);

-- Audit log: queries by timestamp range
CREATE INDEX idx_audit_timestamp ON audit_log(timestamp);

-- Check query performance
EXPLAIN QUERY PLAN SELECT * FROM documents WHERE collection_id = ?;
```

#### Connection Pooling

For PostgreSQL, use a connection pool to avoid exhausting connections:

```dart
// Add connection pool library
// https://pub.dev/packages/postgres

final pool = PgPool(
  endpoint,
  settings: PoolSettings(
    max: 20,  // Max 20 concurrent connections
    testOnBorrow: true,
  ),
);

// Use from pool
final connection = await pool.connect();
try {
  final result = await connection.execute('SELECT * FROM users');
} finally {
  await connection.close();
}
```

#### Query Optimization

Profile slow queries in audit logs:

```bash
# Find queries taking > 1 second
grep "SLOW_QUERY" data/logs/shadow_app_*.log
```

Then add indexes or refactor queries.

### Storage Strategy

#### Media Storage Options

**Option 1: In-Database (Current)**
- Pros: Simple, single point of backup
- Cons: Database grows quickly, slower reads
- Use when: < 100GB total media

**Option 2: File System**
- Pros: Fast I/O, scalable
- Cons: Harder to backup, sync between servers
- Use when: 100GB - 1TB media, single server

**Option 3: S3/Object Storage (Recommended for scale)**
- Pros: Infinite scale, managed backups, CDN integration
- Cons: Network latency, costs
- Use when: > 1TB media or multi-server setup

**Migration to S3**:

1. Add S3 config:
   ```yaml
   media:
     storage: s3
     bucket: shadow-app-media
     region: us-east-1
     access_key: AKIA...
     secret_key: ...
   ```

2. Update media_handler.dart:
   ```dart
   // Instead of storing blob in DB:
   final s3 = S3Client(...);
   final key = 'media/${fileId}.jpg';
   await s3.putObject(bucket: 'shadow-app-media', key: key, body: compressedBytes);
   
   // Store S3 reference in DB:
   mediaBlob.s3_url = 's3://shadow-app-media/media/$fileId.jpg';
   ```

3. Test upload/download with S3 endpoint

### Monitoring & Alerting

Set up Prometheus metrics:

```dart
// In lib/server.dart
import 'package:prometheus_client/prometheus_client.dart';

final httpRequestsTotal = Counter(
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'path', 'status'],
);

final authFailures = Counter(
  name: 'auth_failures_total',
  help: 'Total failed authentications',
);

// In request handlers:
httpRequestsTotal.labels([request.method, path, response.statusCode]).inc();
if (!authenticatedSuccessfully) authFailures.inc();
```

Export metrics endpoint:
```
GET /metrics → Prometheus-format metrics
```

Configure Grafana dashboards:
- Request rate (req/s)
- Error rate (%)
- Average response time (ms)
- Database connection pool usage (%)
- Media storage size (GB)

### Disaster Recovery Plan

Three tiers of disaster scenarios:

#### 1. Database Corruption
- **Detect**: Queries return errors, check logs for "database corrupt"
- **Recover**: Restore from latest backup
  ```bash
  # Stop server
  # Restore: cp /backup/shadow_app_latest.db data/shadow_app.db
  # Start server
  ```
- **Prevention**: Enable SQLite PRAGMA integrity_check weekly

#### 2. Server Hardware Failure
- **Detect**: ELB/load balancer health checks fail, automated monitoring alerts
- **Recover**: 
  - If single server: restore from backup on new machine
  - If multi-server: traffic automatically fails over; restore affected server
- **Prevention**: Multi-server setup, automated failover with Kubernetes/Docker

#### 3. Complete Data Loss
- **Detection**: Backup file corrupted or missing
- **Recover**: Contact backups from 3rd-party backup service (AWS S3, Google Cloud, etc.)
- **Prevention**: Off-site backups, 3-2-1 rule (3 copies, 2 media types, 1 offsite)

### Security Hardening for Production

1. **Enable HTTPS**:
   ```yaml
   server:
     ssl: true
     cert_path: /etc/ssl/certs/shadow_app.crt
     key_path: /etc/ssl/private/shadow_app.key
   ```

2. **Database Encryption**:
   - PostgreSQL: Enable SSL connections
   - Backups: Encrypt with OpenSSL
     ```bash
     openssl enc -aes-256-cbc -in shadow_app.db -out shadow_app.db.enc
     ```

3. **Admin Key Rotation**:
   - Monthly generate new admin key
   - Revoke old key
   - Update all admin clients

4. **Rate Limiting**:
   ```dart
   // Add middleware to rate-limit by IP
   // 100 requests per minute per IP
   ```

5. **Log Sanitization**:
   - Don't log passwords or sensitive tokens
   - Review [logging/logger.dart](../lib/logging/logger.dart) for PII handling

---

## Part 3: Common Issues & Troubleshooting

### **Issue: Slow Queries**

**Symptom**: API responses take > 2 seconds

**Debug**:
```bash
# Enable query logging
# In config.yaml: database.log_queries: true

# Check which queries are slow
grep "DURATION:" data/logs/shadow_app_*.log | sort -t: -k3 -nr | head -10
```

**Solution**:
- Add indexes (see Index section above)
- Reduce data per response (pagination)
- Cache frequently accessed data

### **Issue: Database Locks**

**Symptom**: Intermittent "database is locked" errors with SQLite

**Debug**:
```bash
# Too many concurrent writers
ps aux | grep "shadow_app" | grep -v grep | wc -l
```

**Solution**:
- Enable WAL mode in config:
  ```yaml
  database:
    enable_wal: true
  ```
- Migrate to PostgreSQL if issue persists

### **Issue: High Memory Usage**

**Symptom**: Server consuming > 500MB RAM

**Debug**:
```bash
# Check process memory
ps aux | grep "dart bin/main.dart" | grep -v grep

# Check what's in memory (Dart VM dart :8181)
dart vm_service_observatory_uri
```

**Solution**:
- Increase Dart heap limit: `dart --old-gen-heap-size=1024 bin/main.dart`
- Reduce in-memory log buffer size
- Profile code with Observatory (see Dart docs)

### **Issue: Lost Admin Key**

**Solution**:
```bash
# Generate new key (requires DB admin password)
dart bin/main.dart admin --reset-key
# Will prompt for password to existing DB admin user
```

---

## Appendix: Useful Commands

```bash
# Check server uptime and health
curl http://localhost:8080/health

# Restart server cleanly
kill -SIGTERM $(pgrep -f "dart bin/main.dart server")
sleep 2
dart bin/main.dart server --port 8080 &

# Monitor real-time resource usage
watch -n 1 'ps aux | grep "dart bin/main.dart" | grep -v grep'

# Backup database
tar -czf backup_$(date +%Y%m%d_%H%M%S).tar.gz data/

# Check disk usage
du -sh data/
du -sh data/logs/
du -sh data/shadow_app.db

# Rotate logs manually
dart bin/main.dart log-rotate

# Test email configuration
dart bin/main.dart test-email --to admin@example.com

# Run database integrity check
sqlite3 data/shadow_app.db "PRAGMA integrity_check;"
```

---

**Questions?** Refer back to [ARCHITECTURE.md](ARCHITECTURE.md) for system design or [OPERATOR_MANUAL.md](OPERATOR_MANUAL.md) for daily operations.
