"""
scripts/build_db.py
-------------------
Builds the Cascadia PostgreSQL database and materializes the Gold analytical 
cohort table from raw CMS DE-SynPUF claims.

Executes sequential ELT migrations:
  1. Creates target PostgreSQL database.
  2. Executes Silver layer DDL (schemas, tables, indexes).
  3. Ingests and cleans raw claims into Silver relational tables.
  4. Materializes the Gold analytical cohort table for downstream modeling.

Usage:
    python scripts/build_db.py
"""

import os
import subprocess
import sys
from pathlib import Path
from dotenv import dotenv_values


def run_sql_file(
    file_path: Path,
    db_name: str,
    env: dict,
    working_dir: Path,
    single_transaction: bool = False) -> None:
    
    """Execute a SQL script using psql with path anchoring and fail-fast flags."""

    if not file_path.exists():
        print(f"[ERROR] Script not found: {file_path}")
        sys.exit(1)

    cmd = ["psql", "-d", db_name, "-v", "ON_ERROR_STOP=1", "-f", str(file_path)]

    if single_transaction:
        cmd.append("--single-transaction")

    print(f"\n--- Executing: {file_path.name} (DB: {db_name}) ---")

    # cwd=working_dir ensures relative \copy paths resolve from the project root
    result = subprocess.run(cmd, env=env, cwd=working_dir)

    if result.returncode != 0:
        print(f"\n[FATAL] Script {file_path.name} failed with exit code {result.returncode}.")
        sys.exit(result.returncode)

    print(f"[SUCCESS] {file_path.name} completed.")


def main():
    # scripts/build_db.py -> parent is scripts/ -> parent.parent is project root
    project_root = Path(__file__).resolve().parents[1]
    sql_dir = project_root / "src" / "1-database"
    env_file = project_root / ".env"

    if not env_file.exists():
        print(f"[ERROR] .env file not found at {env_file}")
        sys.exit(1)

    # Read configuration
    config = dotenv_values(env_file)
    target_db = config.get("PGDATABASE")

    if not target_db:
        print("[ERROR] PGDATABASE is not defined in your .env file.")
        sys.exit(1)

    # Inject standard PG* variables into the subshell environment
    exec_env = os.environ.copy()
    pg_keys = ["PGHOST", "PGPORT", "PGUSER", "PGPASSWORD", "PGDATABASE"]
    for key in pg_keys:
        val = config.get(key)
        if val is not None:
            exec_env[key] = str(val)

    # Default administrative database for initial bootstrap
    maintenance_db = "postgres"

    # Execution order: (file_name, target_db, single_transaction_flag)
    pipeline = [
        ("00_init_db.sql", maintenance_db, False),
        ("01_schema_ddl.sql", target_db, True),
        ("02_data_ingestion.sql", target_db, True),
        ("03_readmission_cohort.sql", target_db, True)]

    for script_name, db, use_transaction in pipeline:
        script_path = sql_dir / script_name
        run_sql_file(
            file_path=script_path,
            db_name=db,
            env=exec_env,
            working_dir=project_root,
            single_transaction=use_transaction)

    print("\n" + "=" * 50)
    print("Database build pipeline completed successfully.")
    print("=" * 50)


if __name__ == "__main__":
    main()