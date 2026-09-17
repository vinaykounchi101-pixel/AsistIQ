import logging
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger

from backend.db.session import SessionLocal
from backend.services.sweep_service import SweepService

logger = logging.getLogger(__name__)

scheduler = AsyncIOScheduler()


def run_periodic_sweep_job():
    """
    Scheduled job executed every 5 minutes by the in-process background runner.
    """
    db = SessionLocal()
    try:
        SweepService.execute_sweep(db, triggered_by="system_scheduler")
    except Exception as e:
        logger.error(f"Error occurred during periodic background sweep: {type(e).__name__} - {str(e)}")
    finally:
        db.close()


def start_scheduler(interval_minutes: int = 5):
    """
    Initializes and starts the in-process background scheduler.
    """
    if not scheduler.running:
        scheduler.add_job(
            run_periodic_sweep_job,
            trigger=IntervalTrigger(minutes=interval_minutes),
            id="sla_risk_sweep",
            name="Periodic SLA & Risk Sweep",
            replace_existing=True
        )
        scheduler.start()
        logger.info(f"Background scheduler started with {interval_minutes}-minute sweep interval.")


def shutdown_scheduler():
    """
    Gracefully stops the in-process background scheduler.
    """
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("Background scheduler shut down successfully.")
