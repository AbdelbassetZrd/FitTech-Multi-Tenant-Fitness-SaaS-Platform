from django.urls import path
from .views import (
    InboxView,
    SendMessageView,
    MarkAsReadView,
    TestChatView,
    ContactListView,
    NutritionBotHistoryView,
    BotChatView,
)

urlpatterns = [
    path('inbox/', InboxView.as_view(), name='message-inbox'),
    path('send/', SendMessageView.as_view(), name='message-send'),
    path('<int:pk>/read/', MarkAsReadView.as_view(), name='message-read'),
    path('test-chat/', TestChatView.as_view(), name='test-chat'),
    path('contacts/', ContactListView.as_view(), name='contact-list'),
    path('bot/', BotChatView.as_view(), name='bot-chat'),
    path('bot-history/', NutritionBotHistoryView.as_view(), name='bot-history'),
]
