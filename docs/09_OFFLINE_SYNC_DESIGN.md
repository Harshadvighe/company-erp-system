# Offline Sync Design

## Overview

The Flutter mobile application is designed to be offline-capable using a local SQLite database (via the `drift` package).

## Sync Architecture

1. **Local Database First:** All reads and writes happen against the local SQLite database.
2. **Sync Queue:** Any write operations (Create, Update, Delete) performed while offline are recorded in a local `SyncQueue` table.
3. **Background Sync:** A background service monitors network connectivity. When the device is online, it processes the `SyncQueue`, sending changes to the NestJS backend.
4. **Server as Source of Truth:** The backend validates and processes the changes.
5. **Pull Down:** The mobile app periodically pulls down new or updated records from the server based on a `lastSyncedAt` timestamp.

## Sync Queue Schema

```sql
CREATE TABLE sync_queue (
  id TEXT PRIMARY KEY,
  entityType TEXT NOT NULL, -- e.g., 'Customer', 'Lead'
  entityId TEXT NOT NULL,
  operation TEXT NOT NULL, -- 'CREATE', 'UPDATE', 'DELETE'
  payload TEXT, -- JSON representation of the data
  status TEXT NOT NULL, -- 'PENDING', 'SYNCING', 'SYNCED', 'FAILED', 'CONFLICT'
  retryCount INTEGER DEFAULT 0,
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## Conflict Resolution

- We do not use silent conflict resolution.
- If the server detects a version mismatch or conflict (e.g., the record was updated on the server after the mobile app went offline), the status is marked as `CONFLICT`.
- The user is presented with a conflict resolution UI to choose which version to keep.
