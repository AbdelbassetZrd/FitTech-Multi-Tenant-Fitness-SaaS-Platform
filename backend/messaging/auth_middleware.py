"""
JWT WebSocket Authentication Middleware for Django Channels.

Reads the JWT access token from the `?token=` query-string parameter and
resolves the matching user model (Member, Coach, or CustomUser/Admin).
Sets `scope['user']` so that ChatConsumer can call `self.user.is_authenticated`.
"""

from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser


@database_sync_to_async
def get_user_from_token(token: str):
    """
    Decode a JWT access token and return the corresponding user instance.

    Member and Coach are plain Django models (not AbstractBaseUser), so we
    explicitly set `is_authenticated = True` on the instance before returning it
    so that Channels / the consumer can check that attribute normally.
    """
    from rest_framework_simplejwt.tokens import AccessToken
    from rest_framework_simplejwt.exceptions import TokenError
    from users.models import Member, Coach, CustomUser

    try:
        access = AccessToken(token)
        user_id = access.get("user_id")
        role = access.get("role")

        if not user_id:
            return AnonymousUser()

        if role == "member":
            user = Member.objects.get(id=user_id)
            # Member is a plain model — mark it authenticated for Channels
            user.is_authenticated = True
            return user

        if role == "coach":
            user = Coach.objects.get(id=user_id)
            user.is_authenticated = True
            return user

        # Default: admin token → CustomUser inherits AbstractUser so
        # is_authenticated is already a property that returns True.
        return CustomUser.objects.get(id=user_id)

    except (TokenError, Exception):
        return AnonymousUser()


class JWTAuthMiddleware:
    """
    ASGI middleware that authenticates WebSocket connections via a JWT access
    token passed as `?token=<access_token>` in the WebSocket URL.

    Usage in asgi.py::

        application = ProtocolTypeRouter({
            "http": django_asgi_app,
            "websocket": JWTAuthMiddleware(URLRouter(websocket_urlpatterns)),
        })
    """

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope.get("type") == "websocket":
            query_string = scope.get("query_string", b"").decode("utf-8")
            params = parse_qs(query_string)
            token_list = params.get("token", [])

            scope["user"] = (
                await get_user_from_token(token_list[0])
                if token_list
                else AnonymousUser()
            )

        return await self.app(scope, receive, send)
