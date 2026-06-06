from django.db import models

from users.models import Member, Coach, CustomUser


class NFCDevice(models.Model):
    DEVICE_TYPES = [
        ('card', 'Physical Card'),
        ('phone', 'Phone NFC'),
    ]
    ROLE_CHOICES = [
        ('member', 'Member'),
        ('coach', 'Coach'),
        ('admin', 'Admin'),
    ]

    # Legacy FK kept for existing member rows; new rows use member/coach/admin_user.
    member = models.ForeignKey(
        Member, on_delete=models.CASCADE,
        null=True, blank=True, related_name='nfc_devices'
    )
    coach = models.ForeignKey(
        Coach, on_delete=models.CASCADE,
        null=True, blank=True, related_name='nfc_devices'
    )
    admin_user = models.ForeignKey(
        CustomUser, on_delete=models.CASCADE,
        null=True, blank=True, related_name='nfc_devices'
    )
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='member')
    uid = models.CharField(max_length=100, unique=True)
    device_type = models.CharField(max_length=10, choices=DEVICE_TYPES, default='card')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def get_owner(self):
        if self.role == 'coach':
            return self.coach
        if self.role == 'admin':
            return self.admin_user
        return self.member

    def get_owner_name(self):
        owner = self.get_owner()
        return owner.get_full_name() if owner else 'Unknown'

    def __str__(self):
        return f"{self.get_owner_name()} [{self.role}] - {self.uid}"


class AccessLog(models.Model):
    member = models.ForeignKey(
        Member, on_delete=models.CASCADE,
        null=True, blank=True, related_name='access_logs'
    )
    coach = models.ForeignKey(
        Coach, on_delete=models.CASCADE,
        null=True, blank=True, related_name='access_logs'
    )
    admin_user = models.ForeignKey(
        CustomUser, on_delete=models.CASCADE,
        null=True, blank=True, related_name='access_logs'
    )
    role = models.CharField(max_length=10, default='member')
    device = models.ForeignKey(NFCDevice, on_delete=models.CASCADE)
    timestamp = models.DateTimeField(auto_now_add=True)
    allowed = models.BooleanField()
    reason = models.CharField(max_length=255)

    def get_owner_name(self):
        return (
            (self.member and self.member.get_full_name()) or
            (self.coach and self.coach.get_full_name()) or
            (self.admin_user and self.admin_user.get_full_name()) or
            'Unknown'
        )

    def __str__(self):
        return f"{self.get_owner_name()} [{self.role}] - {self.timestamp} - {self.allowed}"