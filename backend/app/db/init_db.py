"""Database initialization."""
from app.db.session import engine, Base
from app.db import models


def init_db():
    """
    Initialize database by creating all tables.
    
    This drops existing tables and recreates them to ensure schema matches models.
    For production, use proper migrations instead.
    """
    # Import all models to ensure they're registered with Base
    # (already imported above, but being explicit)
    
    # Drop all existing tables (for development - allows schema changes)
    Base.metadata.drop_all(bind=engine)
    
    # Create all tables with new schema
    Base.metadata.create_all(bind=engine)
    
    print("✓ Database initialized successfully")
