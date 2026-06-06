"""
ASGI config for the FitTech project.

Supports both standard HTTP requests (Django) and WebSocket connections
(Django Channels) with JWT-based authentication for WebSocket clients.

The WebSocket URL `/ws/chat/<contact_id>/` expects a `?token=<JWT>` query
parameter that is decoded by JWTAuthMiddleware before reaching the consumer.
"""

import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

# Initialise Django apps *before* importing anything that touches models/settings.
django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter          # noqa: E402
from messaging.routing import websocket_urlpatterns                 # noqa: E402
from messaging.auth_middleware import JWTAuthMiddleware             # noqa: E402

application = ProtocolTypeRouter(
    {
        # Standard HTTP — handled by Django as usual
        "http": django_asgi_app,
        # WebSocket — authenticated via JWT query param, then routed to consumers
        "websocket": JWTAuthMiddleware(
            URLRouter(websocket_urlpatterns)
        ),
    }
)
