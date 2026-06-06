from django.contrib import admin
from .models import Workout, WorkoutExercise

class WorkoutExerciseInline(admin.TabularInline):
    model = WorkoutExercise
    extra = 1

@admin.register(Workout)
class WorkoutAdmin(admin.ModelAdmin):
    list_display = ('id', 'member', 'day', 'start_time', 'end_time', 'calories_burned')
    list_filter = ('day', 'member')
    inlines = [WorkoutExerciseInline]
    search_fields = ('member__first_name', 'member__last_name', 'member__email')

@admin.register(WorkoutExercise)
class WorkoutExerciseAdmin(admin.ModelAdmin):
    list_display = ('exercise_name', 'workout', 'reps', 'sets', 'weight')
    list_filter = ('exercise_name',)
