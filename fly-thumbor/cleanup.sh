#!/bin/bash
# Cleanup old cached files from Thumbor storage
# Triggered by Monit when disk usage exceeds threshold

STORAGE_PATH="/tmp/thumbor/storage"
USAGE_BEFORE=$(df --output=pcent "$STORAGE_PATH" 2>/dev/null | tail -1 | tr -d '% ')

echo "[cleanup] Starting cleanup, disk usage: ${USAGE_BEFORE}%"

# Delete files older than 1 day
COUNT=$(find "$STORAGE_PATH" -type f -mtime +1 2>/dev/null | wc -l)
find "$STORAGE_PATH" -type f -mtime +1 -delete 2>/dev/null
echo "[cleanup] Deleted $COUNT files older than 1 day"

# If still over 80%, delete files older than 1 hour
USAGE=$(df --output=pcent "$STORAGE_PATH" 2>/dev/null | tail -1 | tr -d '% ')
if [ -n "$USAGE" ] && [ "$USAGE" -gt 80 ]; then
  COUNT=$(find "$STORAGE_PATH" -type f -mmin +60 2>/dev/null | wc -l)
  find "$STORAGE_PATH" -type f -mmin +60 -delete 2>/dev/null
  echo "[cleanup] Still above 80%, deleted $COUNT files older than 1 hour"
fi

# If still over 80%, delete all files
USAGE=$(df --output=pcent "$STORAGE_PATH" 2>/dev/null | tail -1 | tr -d '% ')
if [ -n "$USAGE" ] && [ "$USAGE" -gt 80 ]; then
  COUNT=$(find "$STORAGE_PATH" -type f 2>/dev/null | wc -l)
  find "$STORAGE_PATH" -type f -delete 2>/dev/null
  echo "[cleanup] Still above 80%, deleted all $COUNT files"
fi

USAGE_AFTER=$(df --output=pcent "$STORAGE_PATH" 2>/dev/null | tail -1 | tr -d '% ')
echo "[cleanup] Cleanup complete, disk usage: ${USAGE_AFTER}%"
