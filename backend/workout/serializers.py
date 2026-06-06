from rest_framework import serializers
from .models import Workout, WorkoutExercise
from users.models import Member

class WorkoutExerciseSerializer(serializers.ModelSerializer):
    class Meta:
        model = WorkoutExercise
        fields = ['id', 'exercise_name', 'reps', 'sets', 'weight', 'notes']

class WorkoutSerializer(serializers.ModelSerializer):
    exercises = WorkoutExerciseSerializer(many=True)

    class Meta:
        model = Workout
        fields = ['id', 'member', 'day', 'start_time', 'end_time', 'calories_burned', 'exercises']
        read_only_fields = ['id', 'member']

    def create(self, validated_data):
        exercises_data = validated_data.pop('exercises')
        member = self.context.get('member')
        if member is None:
            request = self.context.get('request')
            if request is None:
                raise serializers.ValidationError('Missing request context.')
            member = Member.objects.get(email=request.user.email)
        
        workout = Workout.objects.create(member=member, **validated_data)
        for exercise_data in exercises_data:
            WorkoutExercise.objects.create(workout=workout, **exercise_data)
        return workout

    def update(self, instance, validated_data):
        exercises_data = validated_data.pop('exercises', [])
        instance.day = validated_data.get('day', instance.day)
        instance.start_time = validated_data.get('start_time', instance.start_time)
        instance.end_time = validated_data.get('end_time', instance.end_time)
        instance.calories_burned = validated_data.get('calories_burned', instance.calories_burned)
        instance.save()

        # Simple approach for exercises: clear and recreat (or you can do more complex logic)
        if exercises_data:
            instance.exercises.all().delete()
            for exercise_data in exercises_data:
                WorkoutExercise.objects.create(workout=instance, **exercise_data)
        
        return instance

class ProgressionMetricSerializer(serializers.Serializer):
    calories = serializers.DecimalField(max_digits=10, decimal_places=2)
    duration_minutes = serializers.FloatField()


class ProgressionCurvePointSerializer(serializers.Serializer):
    label = serializers.CharField()
    calories = serializers.DecimalField(max_digits=10, decimal_places=2)
    duration_minutes = serializers.FloatField()

class WorkoutProgressionSerializer(serializers.Serializer):
    day = ProgressionMetricSerializer()
    week = ProgressionMetricSerializer()
    month = ProgressionMetricSerializer()
    day_curve = ProgressionCurvePointSerializer(many=True)
    week_curve = ProgressionCurvePointSerializer(many=True)
    month_curve = ProgressionCurvePointSerializer(many=True)
