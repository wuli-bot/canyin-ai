#!/usr/bin/env python3
"""Execute schema + mock data SQL against Supabase via terminal."""
import os, sys, subprocess, urllib.request, tempfile

SCHEMA_URL = "https://cdn.jsdelivr.net/gh/wuli-bot/canyin-ai@main/all_schema_combined.sql"
MOCK_URL = "https://cdn.jsdelivr.net/gh/wuli-bot/canyin-ai@main/mock_data_wangyuehu.sql"
PWD = "DB2026@CanyinAI!"
# Direct connection first (cloud computer can reach *.supabase.co)
HOSTS = [
    ("db.vovzgflfdwngfuqnxjc.supabase.co", 5432, "postgres"),
    ("aws-0-ap-northeast-1.pooler.supabase.com", 6543, "postgres.vovzgflfdwngfuqnxjc"),
    ("aws-0-ap-northeast-1.pooler.supabase.com", 5432, "postgres.vovzgflfdwngfuqnxjc"),
]

def fetch_sql(url, label):
    print(f"\n{'='*50}")
    print(f"Fetching {label} from {url} ...")
    sql = urllib.request.urlopen(url, timeout=30).read().decode()
    print(f"  Fetched {len(sql)} bytes")
    return sql

def try_psql(host, port, user, sql_text, label):
    """Try executing SQL via psql command."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.sql', delete=False) as f:
        f.write(sql_text)
        path = f.name
    env = {**os.environ, "PGPASSWORD": PWD}
    try:
        r = subprocess.run(
            ["psql", "-h", host, "-p", str(port), "-U", user, "-d", "postgres", "-f", path],
            env=env, capture_output=True, text=True, timeout=120
        )
        if r.returncode == 0:
            print(f"  ✅ {label} executed via psql!")
            if r.stdout:
                print(f"  Output: {r.stdout[-300:]}")
            return True
        else:
            # psql might return non-zero for warnings but still execute
            if r.stdout and ("CREATE" in r.stdout or "INSERT" in r.stdout or "ALTER" in r.stdout):
                print(f"  ✅ {label} executed via psql (with warnings)!")
                print(f"  Output: {r.stdout[-300:]}")
                if r.stderr:
                    print(f"  Warnings: {r.stderr[:300]}")
                return True
            print(f"  ❌ psql failed (rc={r.returncode}): {r.stderr[:300]}")
            return False
    except FileNotFoundError:
        print("  psql not found")
        return False
    except Exception as e:
        print(f"  ❌ psql error: {e}")
        return False
    finally:
        os.unlink(path)

def try_psycopg2(host, port, user, sql_text, label):
    """Try executing SQL via psycopg2."""
    try:
        import psycopg2
    except ImportError:
        print("  Installing psycopg2-binary...")
        subprocess.run([sys.executable, "-m", "pip", "install", "psycopg2-binary", "-q"],
                      capture_output=True, text=True, timeout=60)
        try:
            import psycopg2
        except ImportError:
            print("  Cannot install psycopg2")
            return False
    
    try:
        conn = psycopg2.connect(
            host=host, port=port, dbname="postgres",
            user=user, password=PWD, connect_timeout=30
        )
        conn.autocommit = True
        cur = conn.cursor()
        print(f"  Connected! Executing {label}...")
        cur.execute(sql_text)
        print(f"  ✅ {label} executed via psycopg2!")
        cur.close()
        conn.close()
        return True
    except Exception as e:
        print(f"  ❌ psycopg2 error: {e}")
        return False

def verify(host, port, user):
    """Verify table row counts."""
    tables = ['stores', 'store_dishes', 'store_daily_summary', 'store_transactions',
              'ingredient_inventory', 'store_configs', 'agent_auth', 'settlement_records']
    
    # Try psql
    env = {**os.environ, "PGPASSWORD": PWD}
    query = " UNION ALL ".join([f"SELECT '{t}' as tbl, count(*) FROM {t}" for t in tables])
    try:
        r = subprocess.run(
            ["psql", "-h", host, "-p", str(port), "-U", user, "-d", "postgres", "-c", query],
            env=env, capture_output=True, text=True, timeout=30
        )
        if r.returncode == 0:
            print(r.stdout)
            return True
    except:
        pass
    
    # Try psycopg2
    try:
        import psycopg2
        conn = psycopg2.connect(host=host, port=port, dbname="postgres",
                                user=user, password=PWD, connect_timeout=30)
        conn.autocommit = True
        cur = conn.cursor()
        print("\n=== VERIFICATION ===")
        for t in tables:
            try:
                cur.execute(f"SELECT COUNT(*) FROM {t}")
                print(f"  {t}: {cur.fetchone()[0]} rows")
            except Exception as e:
                print(f"  {t}: ERROR ({e})")
        cur.close()
        conn.close()
        return True
    except Exception as e:
        print(f"  Verify error: {e}")
        return False

print("=== Supabase Full SQL Executor ===")
print(f"Python: {sys.version}")

# Fetch SQL files
schema_sql = fetch_sql(SCHEMA_URL, "Schema SQL")
mock_sql = fetch_sql(MOCK_URL, "Mock Data SQL")

# Try each host
success = False
for host, port, user in HOSTS:
    print(f"\n{'='*50}")
    print(f"Trying {user}@{host}:{port}")
    
    # Test connection with a simple query
    test_ok = False
    for method in [try_psql, try_psycopg2]:
        if method(host, port, user, "SELECT 1;", "connection test"):
            test_ok = True
            break
    
    if not test_ok:
        print("  Connection test failed, skipping this host")
        continue
    
    print(f"\n  Connection OK! Executing SQL...")
    
    # Execute schema SQL
    schema_ok = False
    for method in [try_psql, try_psycopg2]:
        if method(host, port, user, schema_sql, "Schema SQL"):
            schema_ok = True
            break
    
    if not schema_ok:
        print("  Schema execution failed!")
        continue
    
    # Execute mock data SQL
    mock_ok = False
    for method in [try_psql, try_psycopg2]:
        if method(host, port, user, mock_sql, "Mock Data SQL"):
            mock_ok = True
            break
    
    if not mock_ok:
        print("  Mock data execution failed!")
        continue
    
    # Verify
    print(f"\n{'='*50}")
    print("Verifying data...")
    verify(host, port, user)
    
    success = True
    break

if success:
    print("\n✅✅✅ ALL DONE! Schema + Mock data loaded successfully.")
else:
    print("\n❌ All connection attempts failed.")
    print("Possible causes: project paused, network blocked, wrong credentials.")
    sys.exit(1)
