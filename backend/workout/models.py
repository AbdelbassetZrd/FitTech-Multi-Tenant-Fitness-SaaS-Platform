import uuid
from django.db import models
from users.models import Member

def generate_workout_id():
    return str(uuid.uuid4())

class Workout(models.Model):
    id = models.CharField(
        max_length=36, primary_key=True,
        default=generate_workout_id, editable=False
    )
    member = models.ForeignKey(
        Member, on_delete=models.CASCADE, related_name='workouts'
    )
    day = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField()
    calories_burned = models.DecimalField(
        max_digits=7, decimal_places=2, 
        default=0.0,
        help_text="Total calories burned sent by frontend"
    )

    class Meta:
        db_table = 'workouts'
        ordering = ['-day', '-start_time']

    def __str__(self):
        return f"{self.member.get_full_name()} - {self.day}"

class WorkoutExercise(models.Model):
    workout = models.ForeignKey(
        Workout, on_delete=models.CASCADE, related_name='exercises'
    )
    exercise_name = models.CharField(max_length=200)
    reps = models.PositiveIntegerField(default=0)
    sets = models.PositiveIntegerField(default=0)
    weight = models.DecimalField(max_digits=6, decimal_places=2, default=0.0)
    notes = models.TextField(blank=True)

    class Meta:
        db_table = 'workout_exercises'

    def __str__(self):
        return f"{self.exercise_name} in workout {self.workout.id}"
