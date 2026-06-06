from django.db import models


class Notification(models.Model):
    """
    In-app notification for a gym member.
    Created automatically when a waiting-list member is promoted
    to a confirmed booking after another member cancels.
    """

    TYPE_CHOICES = [
        ('booking_confirmed', 'Booking Confirmed from Waiting List'),
        ('session_cancelled', 'Session Cancelled'),
        ('absence_warning', 'Absence Warning'),
        ('account_suspended', 'Account Suspended'),
        ('new_message', 'New Message Received'),
        ('order_confirmed', 'Order Confirmed'),
        ('general', 'General'),
    ]

    member = models.ForeignKey(
        'users.Member',
        on_delete=models.CASCADE,
        related_name='notifications'
    )
    notification_type = models.CharField(max_length=50, choices=TYPE_CHOICES, default='general')
    title = models.CharField(max_length=255)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'notifications'
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.notification_type}] {self.member} — {self.title}"
