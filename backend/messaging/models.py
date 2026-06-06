from django.db import models
from django.contrib.contenttypes.fields import GenericForeignKey
from django.contrib.contenttypes.models import ContentType

class DirectMessage(models.Model):
    """A direct message between any two users (Member, Coach, or Admin)."""
    
    # Generic Sender
    sender_type = models.ForeignKey(ContentType, on_delete=models.CASCADE, related_name='sent_messages_as_type')
    sender_id = models.CharField(max_length=36) # Using CharField for UUID compatibility
    sender = GenericForeignKey('sender_type', 'sender_id')

    # Generic Recipient
    recipient_type = models.ForeignKey(ContentType, on_delete=models.CASCADE, related_name='received_messages_as_type')
    recipient_id = models.CharField(max_length=36)
    recipient = GenericForeignKey('recipient_type', 'recipient_id')

    content = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'direct_messages'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=["sender_type", "sender_id"]),
            models.Index(fields=["recipient_type", "recipient_id"]),
        ]

    def __str__(self):
        return f"Message from {self.sender_id} at {self.created_at}"
