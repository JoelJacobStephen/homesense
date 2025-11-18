from fastapi import APIRouter
from app.api.routes import health, calibration, centroids, infer, events, insights, suggest

api_router = APIRouter()

# Include health check route
api_router.include_router(health.router, tags=["health"])

# Include calibration routes
api_router.include_router(calibration.router, prefix="/calibration", tags=["calibration"])

# Include centroids routes
api_router.include_router(centroids.router, prefix="/centroids", tags=["centroids"])

# Include inference routes
api_router.include_router(infer.router, prefix="/infer", tags=["inference"])

# Include suggestions routes
api_router.include_router(suggest.router, prefix="/suggest", tags=["suggestions"])

# Include events routes
api_router.include_router(events.router, prefix="/events", tags=["events"])

# Include insights routes
api_router.include_router(insights.router, prefix="/insights", tags=["insights"])
