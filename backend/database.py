import os
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from dotenv import load_dotenv

load_dotenv()

DB_HOST = os.getenv("DB_HOST", "")
DB_PORT = os.getenv("DB_PORT", "")
DB_USER = os.getenv("DB_USER", "")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "bisheng_glimmer")

if DB_HOST and DB_USER:
    DATABASE_URL = f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}?charset=utf8mb4"
else:
    DATABASE_URL = "sqlite:///./bisheng_glimmer.db"
    print("[DB] Using SQLite (no MySQL configured)")

engine = create_engine(DATABASE_URL, pool_size=10, max_overflow=20, pool_recycle=3600)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def _migrate_schema():
    try:
        inspector = inspect(engine)
        if "braille_records" not in inspector.get_table_names():
            return
        columns = {c["name"] for c in inspector.get_columns("braille_records")}
        if "source_post_id" in columns:
            return
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE braille_records ADD COLUMN source_post_id VARCHAR(64) DEFAULT NULL"))
        print("[DB] Migration: added source_post_id column to braille_records")
    except Exception as e:
        print(f"[DB] Migration skipped: {e}")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    Base.metadata.create_all(bind=engine)
    _migrate_schema()
