from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, generics, permissions
from django.db.models import Q

from .serializers import RoomSerializer, RoomAvailabilitySerializer
from courses.models import Salle, Course


class RoomListView(APIView):
    """List public rooms."""

    def get(self, request):
        rooms = Salle.objects.all().order_by('name')
        return Response(RoomSerializer(rooms, many=True).data)


class RoomAvailabilityView(APIView):
    """Return availability of rooms for a given day/time.

    Query params: ?day=MON&time=08:00:00
    """

    def get(self, request):
        day = request.query_params.get('day')
        time = request.query_params.get('time')
        if not day or not time:
            return Response({'error': 'Please provide day and time query params'}, status=status.HTTP_400_BAD_REQUEST)

        rooms = Salle.objects.all()
        out = []
        for r in rooms:
            conflict = Course.objects.filter(salle=r, day=day, time=time).first()
            if conflict:
                out.append({
                    'id': r.id,
                    'name': r.name,
                    'capacity': r.capacity,
                    'is_available': False,
                    'reason': f"Booked by course {conflict.name} (coach {getattr(conflict.coach, 'get_full_name', lambda: str(conflict.coach))()})",
                })
            else:
                out.append({
                    'id': r.id,
                    'name': r.name,
                    'capacity': r.capacity,
                    'is_available': True,
                })
        return Response(RoomAvailabilitySerializer(out, many=True).data)


# --- Admin endpoints (for frontend CRUD) ---------------------------------
class AdminRoomListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = RoomSerializer

    def get_queryset(self):
        return Salle.objects.all().order_by('name')


class AdminRoomDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = RoomSerializer
    lookup_url_kwarg = 'pk'

    def get_queryset(self):
        return Salle.objects.all()

