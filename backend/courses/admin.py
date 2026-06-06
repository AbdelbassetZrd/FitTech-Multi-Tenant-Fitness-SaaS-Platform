from django.contrib import admin
from .models import Course, Session, Booking


@admin.register(Course)
class CourseAdmin(admin.ModelAdmin):
    list_display = ('name', 'coach', 'day', 'time', 'max_members', 'number_of_sessions', 'created_by', 'created_at')
    list_filter = ('day', 'coach')
    search_fields = ('name', 'coach__first_name', 'coach__last_name')
    autocomplete_fields = []
    readonly_fields = ('created_by', 'created_at', 'updated_at')


@admin.register(Session)
class SessionAdmin(admin.ModelAdmin):
    list_display = ('course', 'date', 'salle_fk', 'is_cancelled', 'confirmed_count', 'waiting_count')
    list_filter = ('is_cancelled', 'course', 'salle_fk')
    search_fields = ('course__name', 'salle_fk__name')
    date_hierarchy = 'date'

    def confirmed_count(self, obj):
        return obj.confirmed_count
    confirmed_count.short_description = 'Confirmed'

    def waiting_count(self, obj):
        return obj.waiting_count
    waiting_count.short_description = 'Waiting'


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = ('session', 'member', 'status', 'created_at')
    list_filter = ('status',)
    search_fields = ('member__first_name', 'member__last_name', 'session__course__name')
    ordering = ('session', 'created_at')