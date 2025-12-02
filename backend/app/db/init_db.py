"""Database initialization."""
from app.db.session import engine, Base
from app.db import models


def init_db(drop_existing: bool = False):
    """
    Initialize database by creating tables if they don't exist.
    
    Args:
        drop_existing: If True, drops all tables first (destructive, for development only)
    
    For production, use proper migrations instead.
    """
    # Import all models to ensure they're registered with Base
    # (already imported above, but being explicit)
    
    if drop_existing:
        # Drop all existing tables (destructive - use only for development/testing)
        Base.metadata.drop_all(bind=engine)
        print("⚠ Dropped all existing tables")
    
    # Create all tables (only creates if they don't exist)
    Base.metadata.create_all(bind=engine)
    
    print("✓ Database initialized successfully")
