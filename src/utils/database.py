from functools import lru_cache
import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, URL
from sqlalchemy.engine import Engine
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
ENV_PATH = PROJECT_ROOT / ".env"

load_dotenv(dotenv_path=ENV_PATH)

@lru_cache(maxsize=1)
def get_engine() -> Engine:
    """Create and return a SQLAlchemy engine using environment variables."""

    required_env_vars = ["PGHOST", "PGUSER", "PGPASSWORD", "PGDATABASE"]
    missing_vars = [var for var in required_env_vars if not os.getenv(var)]
    if missing_vars:
        raise EnvironmentError(
            f"Missing required environment variables: {', '.join(missing_vars)}")

    db_url = URL.create(
        "postgresql+psycopg2",
        username=os.getenv("PGUSER"),
        password=os.getenv("PGPASSWORD"),
        host=os.getenv("PGHOST"),
        port=int(os.getenv("PGPORT", 5432)),
        database=os.getenv("PGDATABASE"))

    engine = create_engine(db_url, pool_pre_ping=True)
    
    return engine