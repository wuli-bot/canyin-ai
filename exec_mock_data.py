#!/usr/bin/env python3
"""Execute mock_data_wangyuehu.sql against Supabase database via terminal."""
import os, sys, subprocess, urllib.request, tempfile

SQL_URL = "https://cdn.jsdelivr.net/gh/wuli-bot/canyin-ai@main/mock_data_wangyuehu.sql"
PWD = "DB2026@CanyinAI!"
HOSTS = [
    ("db.vovzgflfdwngfuqnxjc.supabase.co", 5432, "postgres"),
    ("aws-0-ap-northeast-1.pooler.supabase.com", 6543, "postgres.vovzgflfdwngfuqnxjc"),
    ("aws-0-ap-northeast-1.pooler.supabase.com", 5432, "postgres.vovzgflfdwngfuqnxjc"),
]

print("=== Supabase Mock Data Executor ===")
print(f"Fetching SQL from {SQL_URL} ...")
sql = urllib.request.urlopen(SQL_URL).read().decode()
print(f"Fetched {len(sql)} bytes of SQL")

with tempfile.NamedTemporaryFile(mode='w', suffix='.sql', delete=False) as f:
    f.write(sql)
    path = f.name
print(f"SQL written to {path}")

success = False
for host, port, user in HOSTS:
    print(f"\n--- Trying {user}@{host}:{port} ---")
    env = {**os.environ, "PGPASSWORD": PWD}
    
    # Try psql first
    try:
        r = subprocess.run(
            ["psql", "-h", host, "-p", str(port), "-U", user, "-d", "postgres", "-f", path],
            env=env, capture_output=True, text=True, timeout=120
        )
        if r.returncode == 0:
            print("SQL executed via psql!")
            print(r.stdout[-500:] if len(r.stdout) > 500 else r.stdout)
            # Verify
            v = subprocess.run(
                ["psql", "-h", host, "-p", str(port), "-U", user, "-d", "postgres", "-c",
                 "SELECT 'stores' as tbl, count(*) FROM stores UNION ALL "
                 "SELECT 'store_dishes', count(*) FROM store_dishes UNION ALL "
                 "SELECT 'store_daily_summary', count(*) FROM store_daily_summary UNION ALL "
                 "SELECT 'store_transactions', count(*) FROM store_transactions UNION ALL "
                 "SELECT 'ingredient_inventory', count(*) FROM ingredient_inventory UNION ALL "
                 "SELECT 'store_configs', count(*) FROM store_configs"],
                env=env, capture_output=True, text=True, timeout=30
            )
            print("\n=== VERIFICATION ===")
            print(v.stdout)
            success = True
            break
        else:
            print(f"psql failed (rc={r.returncode}): {r.stderr[:300]}")
    except FileNotFoundError:
        print("psql not found")
    except Exception as e:
        print(f"psql error: {e}")
    
    # Try psycopg2
    try:
        import psycopg2
    except ImportError:
        print("Installing psycopg2-binary...")
        subprocess.run([sys.executable, "-m", "pip", "install", "psycopg2-binary"],
                      capture_output=True, text=True, timeout=60)
        try:
            import psycopg2
        except ImportError:
            print("Cannot install psycopg2, skipping")
            continue
    
    try:
        conn = psycopg2.connect(
            host=host, port=port, dbname="postgres",
            user=user, password=PWD, connect_timeout=30
        )
        conn.autocommit = True
        cur = conn.cursor()
        print("Connected! Executing SQL...")
        cur.execute(sql)
        print("SQL executed via psycopg2!")
        
        print("\n=== VERIFICATION ===")
        for t in ['stores', 'store_dishes', 'store_daily_summary', 'store_transactions',
                  'ingredient_inventory', 'store_configs']:
            cur.execute(f"SELECT COUNT(*) FROM {t}")
            print(f"  {t}: {cur.fetchone()[0]} rows")
        
        cur.close()
        conn.close()
        success = True
        break
    except Exception as e:
        print(f"psycopg2 error: {e}")

os.unlink(path)
if success:
    print("\n✅ DONE! Mock data loaded successfully.")
else:
    print("\n❌ All connection attempts failed.")
    print("Possible causes: project paused, network blocked, wrong credentials.")
    sys.exit(1)
