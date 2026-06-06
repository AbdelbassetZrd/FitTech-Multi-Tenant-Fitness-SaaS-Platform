from rest_framework import serializers
from .models import DirectMessage
from users.models import Member, Coach, CustomUser

class DirectMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.SerializerMethodField()
    recipient_name = serializers.SerializerMethodField()
    sender_id = serializers.CharField()
    recipient_id = serializers.CharField()

    class Meta:
        model = DirectMessage
        fields = ['id', 'sender_id', 'sender_name', 'recipient_id', 'recipient_name', 'content', 'is_read', 'created_at']
        read_only_fields = ['id', 'is_read', 'created_at']

    def get_sender_name(self, obj):
        return obj.sender.get_full_name() if obj.sender else "Unknown"

    def get_recipient_name(self, obj):
        return obj.recipient.get_full_name() if obj.recipient else "Unknown"


class SendMessageSerializer(serializers.Serializer):
    recipient_id = serializers.CharField()
    content = serializers.CharField()

    def create(self, validated_data):
        sender = validated_data['sender']
        recipient_id = validated_data['recipient_id']
        content = validated_data['content']
        
        recipient = None
        for model in [Member, Coach, CustomUser]:
            try:
                recipient = model.objects.get(id=recipient_id)
                break
            except model.DoesNotExist:
                continue
        
        if not recipient:
            raise serializers.ValidationError({"recipient_id": "Recipient not found."})
            
        return DirectMessage.objects.create(
            sender=sender,
            recipient=recipient,
            content=content
        )
