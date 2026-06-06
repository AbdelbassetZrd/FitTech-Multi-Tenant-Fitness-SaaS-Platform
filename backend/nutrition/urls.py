from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import NutritionProfileViewSet, NutritionChatViewSet

router = DefaultRouter()
router.register(r'profiles', NutritionProfileViewSet, basename='nutrition-profile')
router.register(r'chats', NutritionChatViewSet, basename='nutrition-chat')

urlpatterns = [
    path('', include(router.urls)),
]
