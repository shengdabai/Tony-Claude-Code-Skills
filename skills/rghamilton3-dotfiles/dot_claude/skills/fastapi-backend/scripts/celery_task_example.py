"""
Celery Task Configuration and Examples for FastAPI
Demonstrates background task patterns with Celery.
"""
from celery import Celery
from celery.schedules import crontab
from typing import Any
import logging

logger = logging.getLogger(__name__)

# Celery configuration
celery_app = Celery(
    "worker",
    broker="redis://localhost:6379/0",
    backend="redis://localhost:6379/0"
)

# Celery configuration
celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=30 * 60,  # 30 minutes
    task_soft_time_limit=25 * 60,  # 25 minutes
)


# Example: Simple async task
@celery_app.task(name="send_email")
def send_email_task(email: str, subject: str, body: str) -> dict[str, Any]:
    """
    Send an email asynchronously.

    Usage in FastAPI endpoint:
        from app.tasks import send_email_task

        @app.post("/send-email")
        async def send_email(email_data: EmailSchema):
            task = send_email_task.delay(
                email_data.email,
                email_data.subject,
                email_data.body
            )
            return {"task_id": task.id, "status": "sent to queue"}
    """
    try:
        # Your email sending logic here
        logger.info(f"Sending email to {email}: {subject}")
        # send_via_smtp(email, subject, body)
        return {"status": "success", "email": email}
    except Exception as e:
        logger.error(f"Failed to send email: {str(e)}")
        raise


# Example: Task with retry logic
@celery_app.task(
    name="process_payment",
    bind=True,
    max_retries=3,
    default_retry_delay=60
)
def process_payment_task(self, payment_id: int) -> dict[str, Any]:
    """
    Process payment with automatic retry on failure.

    Usage:
        result = process_payment_task.delay(payment_id=123)
    """
    try:
        logger.info(f"Processing payment {payment_id}")
        # Your payment processing logic
        return {"status": "completed", "payment_id": payment_id}
    except Exception as exc:
        logger.error(f"Payment processing failed: {str(exc)}")
        # Retry the task
        raise self.retry(exc=exc)


# Example: Task with callback
@celery_app.task(name="generate_report")
def generate_report_task(user_id: int) -> str:
    """Generate a report and return the file path."""
    logger.info(f"Generating report for user {user_id}")
    # Your report generation logic
    report_path = f"/reports/user_{user_id}_report.pdf"
    return report_path


@celery_app.task(name="notify_report_ready")
def notify_report_ready_task(report_path: str, user_id: int) -> None:
    """Notify user that their report is ready."""
    logger.info(f"Notifying user {user_id} about report: {report_path}")
    # Your notification logic


# Chain tasks together
"""
from celery import chain

# In your FastAPI endpoint:
@app.post("/generate-report")
async def generate_report(user_id: int):
    # Chain: generate report, then notify user
    workflow = chain(
        generate_report_task.s(user_id),
        notify_report_ready_task.s(user_id)
    )
    result = workflow.apply_async()
    return {"task_id": result.id}
"""


# Periodic tasks (requires celery beat)
@celery_app.on_after_configure.connect
def setup_periodic_tasks(sender, **kwargs):
    """Configure periodic tasks."""

    # Execute every 10 minutes
    sender.add_periodic_task(
        600.0,
        cleanup_old_sessions.s(),
        name='cleanup sessions every 10 minutes'
    )

    # Execute daily at midnight
    sender.add_periodic_task(
        crontab(hour=0, minute=0),
        send_daily_digest.s(),
        name='send daily digest at midnight'
    )


@celery_app.task(name="cleanup_old_sessions")
def cleanup_old_sessions() -> dict[str, int]:
    """Clean up expired sessions."""
    logger.info("Cleaning up old sessions")
    # Your cleanup logic
    deleted_count = 0
    return {"deleted": deleted_count}


@celery_app.task(name="send_daily_digest")
def send_daily_digest() -> dict[str, str]:
    """Send daily digest email to all users."""
    logger.info("Sending daily digest")
    # Your digest logic
    return {"status": "sent"}


# FastAPI integration example
"""
# In app/main.py
from fastapi import FastAPI, BackgroundTasks
from app.tasks import celery_app, send_email_task

app = FastAPI()

@app.post("/tasks/send-email")
async def trigger_send_email(email: str, subject: str, body: str):
    # Send task to Celery
    task = send_email_task.delay(email, subject, body)
    return {"task_id": task.id, "status": "queued"}

@app.get("/tasks/{task_id}")
async def get_task_status(task_id: str):
    # Check task status
    task_result = celery_app.AsyncResult(task_id)
    return {
        "task_id": task_id,
        "status": task_result.status,
        "result": task_result.result if task_result.ready() else None
    }
"""
