from django.urls import path
from .views import (
    MemberNotificationListView,
    MarkNotificationReadView,
    MarkAllNotificationsReadView,
)

urlpatterns = [
    # GET  /api/notifications/
    path('', MemberNotificationListView.as_view(), name='notification-list'),

    # POST /api/notifications/read-all/
    path('read-all/', MarkAllNotificationsReadView.as_view(), name='notification-read-all'),

    # POST /api/notifications/<pk>/read/
    path('<int:pk>/read/', MarkNotificationReadView.as_view(), name='notification-read'),
]
