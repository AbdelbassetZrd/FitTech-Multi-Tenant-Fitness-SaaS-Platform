from django.contrib import admin
from .models import DirectMessage

@admin.register(DirectMessage)
class DirectMessageAdmin(admin.ModelAdmin):
    list_display = ('sender', 'recipient', 'is_read', 'created_at')
    search_fields = ('sender__email', 'recipient__email')
    list_filter = ('is_read', 'created_at')
