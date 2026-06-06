import os
import jwt
from django.conf import settings
from django.contrib.auth import get_user_model
from channels.db import database_sync_to_async
from channels.middleware import BaseMiddleware
from django.db import close_old_connections

from users.models import Member, Coach

User = get_user_model()

@database_sync_to_async
def get_user(token):
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=['HS256'])
        user_id = payload.get('user_id')
        role = payload.get('role', 'admin')

        if role == 'member':
            return Member.objects.get(id=user_id)
        elif role == 'coach':
            return Coach.objects.get(id=user_id)
        else:
            return User.objects.get(id=user_id)
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError, User.DoesNotExist, Member.DoesNotExist, Coach.DoesNotExist):
        return None

class JWTAuthMiddleware(BaseMiddleware):
    async def __call__(self, scope, receive, send):
        close_old_connections()
        
        # Get token from query string
        query_string = scope.get('query_string', b'').decode()
        token = None
        
        if 'token=' in query_string:
            token = query_string.split('token=')[1]
        
        if token:
            scope['user'] = await get_user(token)
        else:
            scope['user'] = None
            
        return await super().__call__(scope, receive, send)
