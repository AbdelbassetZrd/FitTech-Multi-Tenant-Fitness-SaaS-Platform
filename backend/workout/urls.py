from django.urls import path
from .views import (
    WorkoutListView, 
    WorkoutCreateView, 
    WorkoutDetailView,
    WorkoutProgressionView
)

urlpatterns = [
    path('list/', WorkoutListView.as_view(), name='workout-list'),
    path('log/', WorkoutCreateView.as_view(), name='workout-log'),
    path('progression/', WorkoutProgressionView.as_view(), name='workout-progression'),
    path('<str:pk>/', WorkoutDetailView.as_view(), name='workout-detail'),
]
