from django.urls import path
from .views import (
    RoomListView, RoomAvailabilityView,
    AdminRoomListCreateView, AdminRoomDetailView,
)

urlpatterns = [
    path('list/', RoomListView.as_view(), name='room-list'),
    path('availability/', RoomAvailabilityView.as_view(), name='room-availability'),

    # Admin CRUD for rooms (used by frontend)
    path('admin/rooms/', AdminRoomListCreateView.as_view(), name='admin-room-list-create'),
    path('admin/rooms/create/', AdminRoomListCreateView.as_view(), name='admin-room-create'),
    path('admin/rooms/<int:pk>/update/', AdminRoomDetailView.as_view(), name='admin-room-update'),
    path('admin/rooms/<int:pk>/delete/', AdminRoomDetailView.as_view(), name='admin-room-delete'),
]
