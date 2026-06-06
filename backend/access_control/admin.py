from django.contrib import admin
from .models import NFCDevice, AccessLog


@admin.register(NFCDevice)
class NFCDeviceAdmin(admin.ModelAdmin):
    list_display = ("get_owner_name", "role", "uid", "device_type", "is_active", "created_at")
    list_filter = ("role", "device_type", "is_active", "created_at")
    search_fields = ("uid", "member__email", "coach__email", "admin_user__email")
    ordering = ("-created_at",)


@admin.register(AccessLog)
class AccessLogAdmin(admin.ModelAdmin):
    list_display = ("get_owner_name", "role", "device", "allowed", "timestamp", "reason")
    list_filter = ("role", "allowed", "timestamp", "device__device_type")
    search_fields = ("member__email", "coach__email", "admin_user__email", "reason")
    ordering = ("-timestamp",)
    readonly_fields = ("timestamp",)