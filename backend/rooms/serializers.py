from rest_framework import serializers
from courses.models import Salle


class RoomSerializer(serializers.ModelSerializer):
    class Meta:
        model = Salle
        fields = ['id', 'name', 'capacity']


class RoomAvailabilitySerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    capacity = serializers.IntegerField()
    is_available = serializers.BooleanField()
    reason = serializers.CharField(allow_null=True, required=False)
