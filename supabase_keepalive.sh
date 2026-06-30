#!/bin/bash
# Supabase保活脚本 - 每天执行一次轻量查询防止免费层暂停
# 通过GitHub Pages间接ping（因为沙箱DNS屏蔽supabase.co）
# 实际保活由日历任务完成（每3天浏览器查询）

SUPABASE_URL="https://vovzgflfdwngfuqnxjc.supabase.co"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvdnpnZmxmZHduZ2Z1cW54amMiLCJyb2xlIjoic2VydmljZV9yb2xlIiwiaWF0IjoxNzgxNTk4NDk2LCJleHAiOjIwOTcxNzQ0OTZ9.qH4r9A2bK5cD5eT8fY1uI3oP6sN4mJ7kL0qR2wX5zBc"

# 尝试直接API调用（如果DNS允许）
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "apikey: ${SERVICE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_KEY}" \
  "${SUPABASE_URL}/rest/v1/stores?select=id&limit=1" 2>/dev/null)

if [ "$RESPONSE" = "200" ]; then
  echo "$(date): Supabase alive, ping OK"
elif [ "$RESPONSE" = "000" ]; then
  echo "$(date): Supabase DNS blocked from sandbox, calendar task will handle keep-alive"
else
  echo "$(date): Supabase returned HTTP $RESPONSE, may need restore"
fi
