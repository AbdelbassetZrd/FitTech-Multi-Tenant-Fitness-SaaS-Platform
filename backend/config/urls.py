from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
    SpectacularRedocView,
)

urlpatterns = [
    path('admin/', admin.site.urls),

    path('api/auth/', include('users.urls')),

    path('api/subscriptions/', include('subscriptions.urls')),
    path('api/courses/', include('courses.urls')),
    path('api/rooms/', include('rooms.urls')),
    path('api/notifications/', include('notifications.urls')),
    # path('api/activity/', include('activity.urls')),
    # path('api/equipment/', include('equipment.urls')),
    path('api/shop/', include('shop.urls')),
    path('api/messaging/', include('messaging.urls')),
    path('api/workouts/', include('workout.urls')),
    path('api/nutrition/', include('nutrition.urls')),
    path('api/access/', include('access_control.urls')),

    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),

] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)