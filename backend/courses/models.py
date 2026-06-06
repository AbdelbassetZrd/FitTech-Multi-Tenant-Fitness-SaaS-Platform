from django.db import models
from django.conf import settings


class Salle(models.Model):
    name = models.CharField(max_length=100, unique=True, help_text="Name of the room / hall")
    capacity = models.PositiveIntegerField(help_text="Maximum functional capacity")

    class Meta:
        db_table = 'gym_salles'

    def __str__(self):
        return self.name

class Course(models.Model):
    DAYS_OF_WEEK = [
        ('MON', 'Monday'),
        ('TUE', 'Tuesday'),
        ('WED', 'Wednesday'),
        ('THU', 'Thursday'),
        ('FRI', 'Friday'),
        ('SAT', 'Saturday'),
        ('SUN', 'Sunday'),
    ]

    # Admin who created this course
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_courses',
        help_text="Admin who created this course"
    )

    name = models.CharField(max_length=255)
    coach = models.ForeignKey('users.Coach', on_delete=models.CASCADE, related_name='courses')
    time = models.TimeField(help_text="Class start time")
    # Assigned salle (room) for the recurring course
    salle = models.ForeignKey(Salle, on_delete=models.RESTRICT, null=True, blank=True, related_name='courses')
    day = models.CharField(max_length=3, choices=DAYS_OF_WEEK)
    max_members = models.PositiveIntegerField(help_text="Maximum number of confirmed members per session")
    number_of_sessions = models.PositiveIntegerField(help_text="Total number of sessions in this programme")
    session_price = models.DecimalField(max_digits=10, decimal_places=2, default=0.00, help_text="Price per session for this course")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'courses'
        ordering = ['day', 'time']

    def __str__(self):
        return f"{self.name} ({self.get_day_display()} at {self.time})"

class Session(models.Model):
    course = models.ForeignKey(Course, on_delete=models.CASCADE, related_name='sessions')
    date = models.DateField()
    salle_fk = models.ForeignKey(Salle, on_delete=models.RESTRICT, related_name='sessions', null=True, blank=True)
    duration_time = models.PositiveIntegerField(default=60, help_text="Duration of the session in minutes")
    is_cancelled = models.BooleanField(default=False)
    notes = models.TextField(blank=True, help_text="Optional admin notes for this session")

    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)

    class Meta:
        db_table = 'sessions'
        ordering = ['date']
        unique_together = ('course', 'date')

    def __str__(self):
        return f"{self.course.name} — {self.date}"

    @property
    def confirmed_count(self):
        return self.bookings.filter(status='confirmed').count()

    @property
    def waiting_count(self):
        return self.bookings.filter(status='waiting').count()

    @property
    def is_full(self):
        return self.confirmed_count >= self.course.max_members


class Booking(models.Model):
    STATUS_CHOICES = [
        ('confirmed', 'Confirmed'),
        ('waiting', 'Waiting List'),
    ]

    session = models.ForeignKey(Session, on_delete=models.CASCADE, related_name='bookings')
    member = models.ForeignKey('users.Member', on_delete=models.CASCADE, related_name='bookings')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES)
    # created_at is the FIFO key — earlier = higher priority
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'bookings'
        unique_together = ('session', 'member')
        ordering = ['created_at']

    def __str__(self):
        return f"{self.member} → {self.session} [{self.status}]"


class CoursePayment(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ]

    member = models.ForeignKey('users.Member', on_delete=models.CASCADE, related_name='course_payments')
    course = models.ForeignKey(Course, on_delete=models.CASCADE, related_name='payments')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    transaction_id = models.CharField(max_length=255, unique=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    paid_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'course_payments'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.member} → {self.course.name} [{self.status}]"


class AttendanceRecord(models.Model):
    session = models.ForeignKey(Session, on_delete=models.CASCADE, related_name='attendance_records')
    member = models.ForeignKey('users.Member', on_delete=models.CASCADE, related_name='attendance_records')
    is_present = models.BooleanField(default=False)
    marked_by = models.ForeignKey('users.Coach', on_delete=models.SET_NULL, null=True, related_name='marked_attendances')
    marked_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'attendance_records'
        unique_together = ('session', 'member')

    def __str__(self):
        return f"{self.member} attended {self.session}: {self.is_present}"


class AbsenceWarning(models.Model):
    member = models.ForeignKey('users.Member', on_delete=models.CASCADE, related_name='absence_warnings')
    session = models.ForeignKey(Session, on_delete=models.CASCADE, related_name='absence_warnings')
    issued_at = models.DateTimeField(auto_now_add=True)
    notified = models.BooleanField(default=False)

    class Meta:
        db_table = 'absence_warnings'
        ordering = ['-issued_at']

    def __str__(self):
        return f"Warning for {self.member} on {self.session}"