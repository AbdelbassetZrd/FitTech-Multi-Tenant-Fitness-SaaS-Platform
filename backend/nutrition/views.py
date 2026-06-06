from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import PermissionDenied, ValidationError
from django.shortcuts import get_object_or_404
from django.utils.decorators import method_decorator
from django.views.decorators.cache import cache_page
from django.conf import settings
import logging

from users.models import Member, CustomUser
from subscriptions.models import Subscription
from .models import NutritionProfile, NutritionChat, NutritionMessage
from .serializers import (
    NutritionProfileSerializer,
    NutritionChatDetailSerializer,
    NutritionChatListSerializer,
    NutritionMessageSerializer,
    NutritionChatMessageSerializer,
)
from .services import NutritionChatbotService

logger = logging.getLogger(__name__)


class IsActiveMember(IsAuthenticated):
    """Permission class to check if user is an authenticated member"""
    
    def has_permission(self, request, view):
        if not super().has_permission(request, view):
            return False
        
        # Check if user has associated member profile
        try:
            Member.objects.get(email=request.user.email)
            return True
        except Member.DoesNotExist:
            return False


class IsPaidMember(IsActiveMember):
    """Permission class to check if member has active subscription.
    
    Subscription.user is a FK to CustomUser (admins table). Members are stored
    in a separate 'members' table. We look up the subscription by finding a
    CustomUser with a matching email, since subscriptions are tied to CustomUser.
    """
    
    def has_permission(self, request, view):
        if not super().has_permission(request, view):
            return False
        
        try:
            member = Member.objects.get(email=request.user.email)
        except Member.DoesNotExist:
            raise PermissionDenied("No member profile found.")
        
        # Subscription.user FK points to CustomUser (admins table).
        # Try to find a matching CustomUser by email to look up their subscription.
        try:
            custom_user = CustomUser.objects.get(email=member.email)
            active_sub = Subscription.objects.filter(
                user=custom_user,
                status='active'
            ).first()
        except CustomUser.DoesNotExist:
            # No CustomUser with this email — member has no subscription in this system
            active_sub = None
        
        if not active_sub:
            raise PermissionDenied("Nutrition chatbot access requires an active subscription.")
        
        return True


class NutritionProfileViewSet(viewsets.ModelViewSet):
    """API endpoints for nutrition profiles"""
    serializer_class = NutritionProfileSerializer
    permission_classes = [IsPaidMember]
    http_method_names = ['get', 'post', 'put', 'patch']

    def get_queryset(self):
        member = Member.objects.get(email=self.request.user.email)
        return NutritionProfile.objects.filter(member=member)

    def get_object(self):
        member = Member.objects.get(email=self.request.user.email)
        profile, created = NutritionProfile.objects.get_or_create(member=member)
        return profile

    @action(detail=False, methods=['get'])
    def me(self, request):
        """Get current user's nutrition profile"""
        profile = self.get_object()
        serializer = self.get_serializer(profile)
        return Response(serializer.data)

    @action(detail=False, methods=['post', 'put', 'patch'])
    def update_profile(self, request):
        """Update current user's nutrition profile"""
        profile = self.get_object()
        serializer = self.get_serializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class NutritionChatViewSet(viewsets.ModelViewSet):
    """API endpoints for nutrition chats"""
    permission_classes = [IsPaidMember]
    http_method_names = ['get', 'post', 'head', 'options']

    def get_queryset(self):
        member = Member.objects.get(email=self.request.user.email)
        return NutritionChat.objects.filter(member=member)

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return NutritionChatDetailSerializer
        elif self.action == 'list':
            return NutritionChatListSerializer
        return NutritionChatDetailSerializer

    def list(self, request, *args, **kwargs):
        """List all chats for the current user"""
        member = Member.objects.get(email=request.user.email)
        chats = NutritionChat.objects.filter(member=member).prefetch_related('messages')
        
        serializer = NutritionChatListSerializer(chats, many=True)
        return Response({
            'count': chats.count(),
            'results': serializer.data
        })

    def retrieve(self, request, pk=None):
        """Get a specific chat with all messages"""
        member = Member.objects.get(email=request.user.email)
        chat = get_object_or_404(NutritionChat, id=pk, member=member)
        
        serializer = NutritionChatDetailSerializer(chat)
        return Response(serializer.data)

    def create(self, request):
        """Create a new nutrition chat conversation"""
        member = Member.objects.get(email=request.user.email)
        
        chat = NutritionChat.objects.create(
            member=member,
            title=request.data.get('title', 'New Nutrition Chat')
        )
        
        serializer = NutritionChatDetailSerializer(chat)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def send_message(self, request, pk=None):
        """
        Send a message to the nutrition chatbot
        POST: {
            "content": "Your nutrition question here"
        }
        """
        member = Member.objects.get(email=request.user.email)
        chat = get_object_or_404(NutritionChat, id=pk, member=member)
        
        # Validate input
        serializer = NutritionChatMessageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user_message = serializer.validated_data['content']
        
        # Save user message
        NutritionMessage.objects.create(
            chat=chat,
            role='user',
            content=user_message
        )
        
        # Get conversation history (excluding current message)
        history = NutritionMessage.objects.filter(chat=chat).values('role', 'content')[:-1]
        conversation_history = list(history)
        
        # Get user's nutrition profile
        try:
            profile = NutritionProfile.objects.get(member=member)
            user_profile = {
                'age': profile.age,
                'fitness_goal': member.fitness_goal,
                'dietary_preference': profile.dietary_preference,
                'allergies': profile.allergies,
                'medical_conditions': profile.medical_conditions,
                'nutrition_goals': profile.nutrition_goals,
            }
        except NutritionProfile.DoesNotExist:
            user_profile = {
                'fitness_goal': member.fitness_goal,
            }
        
        # Get AI response
        chatbot_service = NutritionChatbotService()
        ai_response = chatbot_service.get_nutrition_advice(
            user_message,
            conversation_history,
            user_profile
        )
        
        if not ai_response.get('success'):
            logger.error(f"AI service error: {ai_response.get('error')}")
            return Response(
                {
                    'error': ai_response.get('message', 'Unable to get response'),
                    'details': ai_response.get('error')
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        # Save assistant message
        assistant_message = NutritionMessage.objects.create(
            chat=chat,
            role='assistant',
            content=ai_response['message'],
            tokens_used=ai_response.get('tokens_used', 0)
        )
        
        # Update chat title if it's the first message
        if chat.title == 'New Nutrition Chat' and chat.messages.count() == 3:  # user + assistant + first pair
            # Extract first few words from user message as title
            title = user_message[:50] + ('...' if len(user_message) > 50 else '')
            chat.title = title
            chat.save()
        
        # Return conversation
        response_data = {
            'chat_id': chat.id,
            'user_message': {
                'id': NutritionMessage.objects.filter(chat=chat, role='user').last().id,
                'role': 'user',
                'content': user_message,
                'created_at': NutritionMessage.objects.filter(chat=chat, role='user').last().created_at,
            },
            'assistant_message': {
                'id': assistant_message.id,
                'role': 'assistant',
                'content': assistant_message.content,
                'created_at': assistant_message.created_at,
            },
            'model': ai_response.get('model'),
        }
        
        return Response(response_data, status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'])
    def quick_chat(self, request):
        """
        Quick chat endpoint - creates a chat and sends message in one request
        POST: {
            "content": "Your nutrition question here",
            "title": "Optional chat title"
        }
        """
        member = Member.objects.get(email=request.user.email)
        
        # Validate input
        serializer = NutritionChatMessageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user_message = serializer.validated_data['content']
        
        # Create new chat
        chat = NutritionChat.objects.create(
            member=member,
            title=request.data.get('title', user_message[:50] + ('...' if len(user_message) > 50 else ''))
        )
        
        # Save user message
        NutritionMessage.objects.create(
            chat=chat,
            role='user',
            content=user_message
        )
        
        # Get user's nutrition profile
        try:
            profile = NutritionProfile.objects.get(member=member)
            user_profile = {
                'age': profile.age,
                'fitness_goal': member.fitness_goal,
                'dietary_preference': profile.dietary_preference,
                'allergies': profile.allergies,
                'medical_conditions': profile.medical_conditions,
                'nutrition_goals': profile.nutrition_goals,
            }
        except NutritionProfile.DoesNotExist:
            user_profile = {
                'fitness_goal': member.fitness_goal,
            }
        
        # Get AI response
        chatbot_service = NutritionChatbotService()
        ai_response = chatbot_service.get_nutrition_advice(
            user_message,
            [],
            user_profile
        )
        
        if not ai_response.get('success'):
            logger.error(f"AI service error: {ai_response.get('error')}")
            return Response(
                {
                    'error': ai_response.get('message', 'Unable to get response'),
                    'details': ai_response.get('error')
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        # Save assistant message
        assistant_message = NutritionMessage.objects.create(
            chat=chat,
            role='assistant',
            content=ai_response['message'],
            tokens_used=ai_response.get('tokens_used', 0)
        )
        
        # Return full chat
        response_data = {
            'chat_id': chat.id,
            'chat_title': chat.title,
            'messages': [
                {
                    'id': NutritionMessage.objects.filter(chat=chat, role='user').last().id,
                    'role': 'user',
                    'content': user_message,
                },
                {
                    'id': assistant_message.id,
                    'role': 'assistant',
                    'content': assistant_message.content,
                }
            ],
            'model': ai_response.get('model'),
        }
        
        return Response(response_data, status=status.HTTP_201_CREATED)
