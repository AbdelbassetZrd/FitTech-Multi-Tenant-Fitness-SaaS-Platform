from rest_framework import serializers
from .models import NutritionProfile, NutritionChat, NutritionMessage


class NutritionProfileSerializer(serializers.ModelSerializer):
    member_name = serializers.CharField(source='member.first_name', read_only=True)
    member_email = serializers.CharField(source='member.email', read_only=True)

    class Meta:
        model = NutritionProfile
        fields = [
            'id', 'member', 'member_name', 'member_email',
            'height_cm', 'weight_kg', 'age', 'activity_level',
            'dietary_preference', 'allergies', 'dislikes',
            'nutrition_goals', 'target_daily_calories', 'target_daily_protein_g',
            'medical_conditions', 'supplements_taken',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class NutritionMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = NutritionMessage
        fields = ['id', 'role', 'content', 'created_at']
        read_only_fields = ['id', 'created_at']


class NutritionChatListSerializer(serializers.ModelSerializer):
    latest_message = serializers.SerializerMethodField()

    class Meta:
        model = NutritionChat
        fields = ['id', 'title', 'created_at', 'updated_at', 'latest_message']
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_latest_message(self, obj):
        latest = obj.messages.last()
        if latest:
            return NutritionMessageSerializer(latest).data
        return None


class NutritionChatDetailSerializer(serializers.ModelSerializer):
    messages = NutritionMessageSerializer(many=True, read_only=True)
    member_name = serializers.CharField(source='member.first_name', read_only=True)

    class Meta:
        model = NutritionChat
        fields = ['id', 'member', 'member_name', 'title', 'messages', 'created_at', 'updated_at']
        read_only_fields = ['id', 'member', 'messages', 'created_at', 'updated_at']


class NutritionChatMessageSerializer(serializers.Serializer):
    """Serializer for sending messages to the nutrition chatbot"""
    content = serializers.CharField(required=True)
    chat_id = serializers.CharField(required=False, allow_blank=True)

    def validate_content(self, value):
        if not value.strip():
            raise serializers.ValidationError("Message cannot be empty")
        if len(value) > 5000:
            raise serializers.ValidationError("Message is too long (max 5000 characters)")
        return value.strip()
