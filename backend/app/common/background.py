"""Run work off the HTTP request thread (daemon threads)."""
import logging
import threading

logger = logging.getLogger(__name__)


def run_in_background(target, *args, **kwargs) -> None:
    """Execute target inside a Flask app context on a background thread."""
    try:
        from flask import current_app
        app = current_app._get_current_object()
    except RuntimeError:
        # Outside request context (e.g. tests) — run inline
        target(*args, **kwargs)
        return

    def _run():
        with app.app_context():
            try:
                target(*args, **kwargs)
            except Exception as e:
                logger.error(f'Background task failed: {e}')

    threading.Thread(target=_run, daemon=True).start()
