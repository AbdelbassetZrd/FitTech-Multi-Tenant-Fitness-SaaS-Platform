from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    # Matches standard UUIDs (hex + dashes) AND the special 'nutrition-bot' id
    re_path(r'ws/chat/(?P<room_name>[a-f0-9\-]+|nutrition-bot)/$', consumers.ChatConsumer.as_asgi()),
]
