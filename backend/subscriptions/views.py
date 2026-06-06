from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.utils import timezone
from django.http import HttpResponse
from datetime import timedelta
from drf_spectacular.utils import extend_schema
from django.conf import settings
import json

from .models import SubscriptionPlan, Subscription, Payment, Invoice
from .serializers import (
    SubscriptionPlanSerializer,
    SubscriptionPlanAdminSerializer,
    SubscriptionSerializer,
    PaymentSerializer,
    InvoiceSerializer,
)
from .chargily_service import ChargilyService
from users.permissions import IsAdminToken
from users.views import _member_from_request
from users.models import Member
from rest_framework.exceptions import AuthenticationFailed


# ─── Subscription Plans ───────────────────────────────────────────────────────

class SubscriptionPlanListView(generics.ListAPIView):
    """Members browse all active plans."""
    serializer_class = SubscriptionPlanSerializer
    permission_classes = [AllowAny]
    queryset = SubscriptionPlan.objects.filter(is_active=True).order_by('-is_featured', 'price')


class SubscriptionPlanAdminListCreateView(generics.ListCreateAPIView):
    """Admin lists all plans (including inactive) and creates new ones."""
    permission_classes = [IsAuthenticated, IsAdminToken]
    queryset = SubscriptionPlan.objects.all()

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return SubscriptionPlanAdminSerializer
        return SubscriptionPlanSerializer

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class SubscriptionPlanAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Admin views, edits or deactivates a specific plan."""
    permission_classes = [IsAuthenticated, IsAdminToken]
    queryset = SubscriptionPlan.objects.all()

    def get_serializer_class(self):
        if self.request.method == 'GET':
            return SubscriptionPlanSerializer
        return SubscriptionPlanAdminSerializer

    def destroy(self, request, *args, **kwargs):
        plan = self.get_object()
        if plan.subscriptions.filter(status='active').exists():
            return Response(
                {'error': 'Cannot delete a plan with active subscriptions.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        plan.is_active = False
        plan.save()
        return Response(
            {'message': 'Plan deactivated successfully.'},
            status=status.HTTP_200_OK,
        )


# ─── Subscriptions ────────────────────────────────────────────────────────────

class SubscribeView(APIView):
    """Member subscribes to a plan."""
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(request=SubscriptionSerializer, responses={201: SubscriptionSerializer})
    def post(self, request):
        try:
            member = _member_from_request(request)
        except AuthenticationFailed as exc:
            return Response({'error': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        serializer = SubscriptionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        plan = serializer.validated_data['plan']
        today = timezone.now().date()

        # Block if already has active subscription
        if Subscription.objects.filter(user=member, status='active').exists():
            return Response(
                {'error': 'You already have an active subscription.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Calculate end date and sessions
        if plan.plan_type == 'per_session':
            end_date = None
            sessions_remaining = plan.session_count
        elif plan.plan_type == 'free_trial':
            end_date = today + timedelta(days=1)
            sessions_remaining = 1
        elif plan.plan_type == 'monthly':
            end_date = today + timedelta(days=plan.duration_days or 30)
            sessions_remaining = None
        else:  # annual
            end_date = today + timedelta(days=plan.duration_days or 365)
            sessions_remaining = None

        subscription = Subscription.objects.create(
            user=member,
            plan=plan,
            status='active',
            start_date=today,
            end_date=end_date,
            sessions_remaining=sessions_remaining,
        )

        return Response(
            SubscriptionSerializer(subscription).data,
            status=status.HTTP_201_CREATED,
        )


class MySubscriptionView(generics.RetrieveAPIView):
    """Member views their current active subscription."""
    serializer_class = SubscriptionSerializer
    authentication_classes = []
    permission_classes = [AllowAny]

    def get_object(self):
        try:
            member = _member_from_request(self.request)
        except AuthenticationFailed as exc:
            from rest_framework.exceptions import NotAuthenticated
            raise NotAuthenticated(str(exc))

        try:
            return Subscription.objects.filter(
                user=member,
                status='active',
            ).latest('created_at')
        except Subscription.DoesNotExist:
            from rest_framework.exceptions import NotFound
            raise NotFound('No active subscription found.')


class SubscriptionHistoryView(generics.ListAPIView):
    """Member views all their subscriptions (history)."""
    serializer_class = SubscriptionSerializer
    authentication_classes = []
    permission_classes = [AllowAny]

    def get_queryset(self):
        try:
            member = _member_from_request(self.request)
            return Subscription.objects.filter(user=member).order_by('-created_at')
        except AuthenticationFailed:
            return Subscription.objects.none()


class PauseSubscriptionView(APIView):
    """Member pauses their active subscription."""
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(responses={200: SubscriptionSerializer})
    def post(self, request):
        try:
            member = _member_from_request(request)
        except AuthenticationFailed as exc:
            return Response({'error': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            subscription = Subscription.objects.get(
                user=member, status='active'
            )
        except Subscription.DoesNotExist:
            return Response(
                {'error': 'No active subscription found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if not subscription.can_pause():
            return Response(
                {'error': 'You have used your maximum pause days (60 days/year).'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        pause_days = int(request.data.get('pause_days', 30))
        remaining_pause_days = 60 - subscription.total_pause_days_used

        if pause_days > remaining_pause_days:
            return Response(
                {'error': f'You only have {remaining_pause_days} pause days remaining.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if pause_days < 1:
            return Response(
                {'error': 'Pause days must be at least 1.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        today = timezone.now().date()
        subscription.status = 'paused'
        subscription.pause_start_date = today
        subscription.pause_end_date = today + timedelta(days=pause_days)
        subscription.total_pause_days_used += pause_days
        if subscription.end_date:
            subscription.end_date += timedelta(days=pause_days)
        subscription.save()

        return Response(SubscriptionSerializer(subscription).data)


class ResumeSubscriptionView(APIView):
    """Member resumes their paused subscription."""
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        try:
            subscription = Subscription.objects.get(
                user=request.user, status='paused'
            )
        except Subscription.DoesNotExist:
            return Response(
                {'error': 'No paused subscription found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        subscription.status = 'active'
        subscription.pause_start_date = None
        subscription.pause_end_date = None
        subscription.save()

        return Response(SubscriptionSerializer(subscription).data)


class CancelSubscriptionView(APIView):
    """Member cancels their active subscription."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            subscription = Subscription.objects.get(
                user=request.user, status='active'
            )
        except Subscription.DoesNotExist:
            return Response(
                {'error': 'No active subscription found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        subscription.status = 'cancelled'
        subscription.save()

        return Response(
            {'message': 'Subscription cancelled successfully.'},
            status=status.HTTP_200_OK,
        )


# ─── Payments ─────────────────────────────────────────────────────────────────

class PaymentCreateView(APIView):
    """Member makes a payment for their subscription."""
    permission_classes = [IsAuthenticated]

    @extend_schema(request=PaymentSerializer, responses={201: PaymentSerializer})
    def post(self, request):
        try:
            subscription = Subscription.objects.get(
                user=request.user, status='active'
            )
        except Subscription.DoesNotExist:
            return Response(
                {'error': 'No active subscription found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        serializer = PaymentSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        payment = serializer.save(
            subscription=subscription,
            amount=subscription.plan.price,
            status='completed',
            paid_at=timezone.now(),
        )

        # Auto-generate invoice number
        invoice_number = f'INV-{timezone.now().year}-{payment.id:04d}'
        Invoice.objects.create(
            payment=payment,
            invoice_number=invoice_number,
        )

        return Response(
            PaymentSerializer(payment).data,
            status=status.HTTP_201_CREATED,
        )


class PaymentHistoryView(generics.ListAPIView):
    """Member views all their payments."""
    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Payment.objects.filter(
            subscription__user=self.request.user
        ).order_by('-created_at')


class PaymentDetailView(generics.RetrieveAPIView):
    """Member views a specific payment."""
    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Payment.objects.filter(
            subscription__user=self.request.user
        )


# ─── Invoices ─────────────────────────────────────────────────────────────────

class InvoiceListView(generics.ListAPIView):
    """Member views all their invoices."""
    serializer_class = InvoiceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Invoice.objects.filter(
            payment__subscription__user=self.request.user
        ).order_by('-issued_at')


class InvoiceDetailView(generics.RetrieveAPIView):
    """Member views a specific invoice."""
    serializer_class = InvoiceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Invoice.objects.filter(
            payment__subscription__user=self.request.user
        )


# ─── Admin ────────────────────────────────────────────────────────────────────

class AdminSubscriptionListView(generics.ListAPIView):
    """Admin views all subscriptions across all members."""
    serializer_class = SubscriptionSerializer
    permission_classes = [IsAuthenticated, IsAdminToken]
    queryset = Subscription.objects.all().select_related('user', 'plan').order_by('-created_at')


class AdminPaymentListView(generics.ListAPIView):
    """Admin views all payments."""
    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated, IsAdminToken]
    queryset = Payment.objects.all().select_related(
        'subscription__user', 'subscription__plan'
    ).order_by('-created_at')


class AdminPaymentDetailView(generics.RetrieveUpdateAPIView):
    """Admin views or updates a specific payment (e.g. mark as refunded)."""
    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated, IsAdminToken]
    queryset = Payment.objects.all()


class AdminCreateSubscriptionView(APIView):
    """Admin manually creates a subscription for a member."""
    permission_classes = [IsAuthenticated, IsAdminToken]

    def post(self, request):
        user_id = request.data.get('user_id')
        plan_id = request.data.get('plan_id')

        if not user_id or not plan_id:
            return Response({'error': 'user_id and plan_id are required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            member = Member.objects.get(id=user_id)
        except Member.DoesNotExist:
            return Response({'error': 'Member not found.'}, status=status.HTTP_404_NOT_FOUND)

        try:
            plan = SubscriptionPlan.objects.get(pk=plan_id, is_active=True)
        except SubscriptionPlan.DoesNotExist:
            return Response({'error': 'Plan not found or inactive.'}, status=status.HTTP_404_NOT_FOUND)

        from django.utils import timezone
        from datetime import timedelta

        start_date = timezone.now().date()
        end_date = None
        sessions_remaining = None

        if plan.plan_type == 'per_session':
            sessions_remaining = plan.session_count
        elif plan.duration_days:
            end_date = start_date + timedelta(days=plan.duration_days)

        subscription = Subscription.objects.create(
            user=member,
            plan=plan,
            status='active',
            start_date=start_date,
            end_date=end_date,
            sessions_remaining=sessions_remaining,
        )

        Payment.objects.create(
            subscription=subscription,
            amount=plan.price,
            payment_method=request.data.get('payment_method', 'cash'),
            status='completed',
            paid_at=timezone.now(),
        )

        member.has_active_subscription = True
        member.save(update_fields=['has_active_subscription'])

        return Response(
            {'message': 'Subscription created.', 'subscription': SubscriptionSerializer(subscription).data},
            status=status.HTTP_201_CREATED,
        )


class AdminCancelSubscriptionView(APIView):
    """Admin cancels a specific subscription."""
    permission_classes = [IsAuthenticated, IsAdminToken]

    def post(self, request, pk):
        try:
            subscription = Subscription.objects.get(pk=pk)
        except Subscription.DoesNotExist:
            return Response({'error': 'Subscription not found.'}, status=status.HTTP_404_NOT_FOUND)

        subscription.status = 'cancelled'
        subscription.save()

        member = subscription.user
        if not Subscription.objects.filter(user=member, status='active').exists():
            member.has_active_subscription = False
            member.save(update_fields=['has_active_subscription'])

        return Response(
            {'message': 'Subscription cancelled.', 'subscription': SubscriptionSerializer(subscription).data},
            status=status.HTTP_200_OK,
        )


class AdminUpdateSubscriptionPlanView(APIView):
    """Admin changes the plan on an existing subscription."""
    permission_classes = [IsAuthenticated, IsAdminToken]

    def patch(self, request, pk):
        try:
            subscription = Subscription.objects.get(pk=pk)
        except Subscription.DoesNotExist:
            return Response({'error': 'Subscription not found.'}, status=status.HTTP_404_NOT_FOUND)

        plan_id = request.data.get('plan_id')
        if not plan_id:
            return Response({'error': 'plan_id is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            plan = SubscriptionPlan.objects.get(pk=plan_id, is_active=True)
        except SubscriptionPlan.DoesNotExist:
            return Response({'error': 'Plan not found or inactive.'}, status=status.HTTP_404_NOT_FOUND)

        subscription.plan = plan
        subscription.save(update_fields=['plan'])

        return Response(
            {'message': 'Plan updated.', 'subscription': SubscriptionSerializer(subscription).data},
            status=status.HTTP_200_OK,
        )


# ─── Chargily Payment Integration ─────────────────────────────────────────────

class InitiateChargilyPaymentView(APIView):
    """Initiate a Chargily payment checkout for subscription."""
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(
        request={'type': 'object', 'properties': {'plan_id': {'type': 'integer'}}},
        responses={201: {'type': 'object'}}
    )
    def post(self, request):
        """
        Initiate payment for a subscription plan via Chargily.
        
        Expected body:
        {
            "plan_id": 1
        }
        """
        try:
            member = _member_from_request(request)
        except AuthenticationFailed as exc:
            return Response({'error': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            plan_id = request.data.get('plan_id')
            if not plan_id:
                return Response(
                    {'error': 'plan_id is required'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Get the plan
            try:
                plan = SubscriptionPlan.objects.get(id=plan_id, is_active=True)
            except SubscriptionPlan.DoesNotExist:
                return Response(
                    {'error': 'Plan not found'},
                    status=status.HTTP_404_NOT_FOUND
                )

            # Check if member already has active paid subscription
            if member.has_active_subscription:
                return Response(
                    {'error': 'You already have an active subscription'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Get or create subscription
            today = timezone.now().date()
            
            if plan.plan_type == 'per_session':
                end_date = None
                sessions_remaining = plan.session_count
            elif plan.plan_type == 'free_trial':
                end_date = today + timedelta(days=plan.duration_days or 1)
                sessions_remaining = 1
            elif plan.plan_type == 'monthly':
                end_date = today + timedelta(days=plan.duration_days or 30)
                sessions_remaining = None
            else:  # annual
                end_date = today + timedelta(days=plan.duration_days or 365)
                sessions_remaining = None

            subscription = Subscription.objects.create(
                user=member,
                plan=plan,
                status='active',
                start_date=today,
                end_date=end_date,
                sessions_remaining=sessions_remaining,
            )

            # Create pending payment record
            payment = Payment.objects.create(
                subscription=subscription,
                amount=plan.price,
                payment_method='card',
                status='pending',
            )

            # Get callback URLs — must be valid https URLs for Chargily.
            # Flutter WebView detects 'payment-success'/'payment-failure' in the URL.
            backend_url = getattr(settings, 'BACKEND_URL', '').rstrip('/')
            success_url = f'{backend_url}/api/subscriptions/payment-success/?payment_id={payment.id}'
            failure_url = f'{backend_url}/api/subscriptions/payment-failure/?payment_id={payment.id}'

            # Initiate Chargily payment
            chargily_result = ChargilyService.create_payment(
                amount=plan.price,
                success_url=success_url,
                failure_url=failure_url,
                description=f'FitTech Gym - {plan.name} Subscription',
                metadata={
                    'subscription_id': subscription.id,
                    'payment_id': payment.id,
                    'member_id': str(member.id),
                }
            )

            if not chargily_result['success']:
                # Delete the subscription and payment if Chargily fails
                subscription.delete()
                return Response(
                    {'error': chargily_result['error']},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Store transaction ID
            payment.transaction_id = chargily_result['transaction_id']
            payment.save()

            return Response({
                'checkout_url': chargily_result['checkout_url'],
                'transaction_id': chargily_result['transaction_id'],
                'payment_id': payment.id,
                'subscription_id': subscription.id,
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response(
                {'error': f'Error initiating payment: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class VerifyChargilyPaymentView(APIView):
    """Verify a Chargily payment and activate subscription."""
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(
        request={'type': 'object', 'properties': {
            'transaction_id': {'type': 'string'},
            'payment_id': {'type': 'integer'}
        }},
        responses={200: {'type': 'object'}}
    )
    def post(self, request):
        """
        Verify payment from Chargily and activate subscription.
        
        Expected body:
        {
            "transaction_id": "chg_xxxx",
            "payment_id": 1
        }
        """
        try:
            member = _member_from_request(request)
        except AuthenticationFailed as exc:
            return Response({'error': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            transaction_id = request.data.get('transaction_id')
            payment_id = request.data.get('payment_id')

            if not transaction_id or not payment_id:
                return Response(
                    {'error': 'transaction_id and payment_id are required'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Get payment
            try:
                payment = Payment.objects.get(id=payment_id, subscription__user=member)
            except Payment.DoesNotExist:
                return Response(
                    {'error': 'Payment not found'},
                    status=status.HTTP_404_NOT_FOUND
                )

            # Verify with Chargily
            verify_result = ChargilyService.verify_payment(transaction_id)

            if not verify_result['success']:
                return Response(
                    {'error': 'Failed to verify payment with Chargily'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            payment_status = verify_result['status']

            if payment_status in ('completed', 'paid'):
                # Mark payment as completed
                payment.status = 'completed'
                payment.transaction_id = transaction_id
                payment.paid_at = timezone.now()
                payment.save()

                # Mark subscription as active (already created)
                subscription = payment.subscription
                subscription.status = 'active'
                subscription.save()

                # Update user to mark has subscription
                member.has_active_subscription = True
                member.save()

                # Create invoice
                invoice_number = f'INV-{timezone.now().year}-{payment.id:04d}'
                Invoice.objects.create(
                    payment=payment,
                    invoice_number=invoice_number,
                )

                return Response({
                    'status': 'success',
                    'message': 'Payment verified and subscription activated',
                    'subscription_id': subscription.id,
                    'payment_status': payment_status,
                }, status=status.HTTP_200_OK)

            elif payment_status == 'pending':
                return Response({
                    'status': 'pending',
                    'message': 'Payment is still pending',
                }, status=status.HTTP_202_ACCEPTED)

            else:
                # Payment failed
                payment.status = 'failed'
                payment.save()
                
                # Delete the subscription
                payment.subscription.delete()

                return Response({
                    'status': 'failed',
                    'message': f'Payment failed with status: {payment_status}',
                }, status=status.HTTP_400_BAD_REQUEST)

        except Exception as e:
            return Response(
                {'error': f'Error verifying payment: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class CheckSubscriptionStatusView(APIView):
    """Check user's current subscription status."""
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request):
        """Get current subscription and payment status."""
        try:
            member = _member_from_request(request)
        except AuthenticationFailed as exc:
            return Response({'error': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            subscription = Subscription.objects.filter(
                user=member,
                status='active'
            ).latest('created_at')

            return Response({
                'has_active_subscription': member.has_active_subscription,
                'subscription': SubscriptionSerializer(subscription).data,
            }, status=status.HTTP_200_OK)

        except Subscription.DoesNotExist:
            return Response({
                'has_active_subscription': member.has_active_subscription,
                'subscription': None,
            }, status=status.HTTP_200_OK)


class ChargilyWebhookView(APIView):
    """Handle Chargily webhook for payment updates."""
    permission_classes = [AllowAny]

    def post(self, request):
        """
        Process Chargily webhook notification.
        Chargily will POST here when payment status changes.
        """
        try:
            # Get signature from header name used by Chargily
            signature = request.headers.get('signature') or request.headers.get('X-Chargily-Signature', '')
            
            # Get raw body
            body = request.body.decode('utf-8')

            # Verify signature
            if not ChargilyService.verify_webhook_signature(body, signature):
                return Response(
                    {'error': 'Invalid signature'},
                    status=status.HTTP_401_UNAUTHORIZED
                )

            # Parse payload
            payload = json.loads(body)
            event_type = payload.get('type')
            data = payload.get('data', {})

            if event_type in ('checkout.success', 'checkout.paid'):
                transaction_id = data.get('id')
                invoice_id = data.get('invoice_id')

                # Find payment by invoice ID
                try:
                    # Parse invoice_id format: INV-{subscription_id}-{payment_id}
                    parts = invoice_id.split('-')
                    payment_id = int(parts[-1])
                    
                    payment = Payment.objects.get(id=payment_id)
                    
                    if payment.status != 'completed':
                        # Update payment
                        payment.status = 'completed'
                        payment.transaction_id = transaction_id
                        payment.paid_at = timezone.now()
                        payment.save()

                        # Activate subscription
                        subscription = payment.subscription
                        subscription.status = 'active'
                        subscription.save()

                        # Update user
                        member = Member.objects.get(email=subscription.user.email)
                        member.has_active_subscription = True
                        member.save()

                        # Create invoice if not exists
                        if not Invoice.objects.filter(payment=payment).exists():
                            invoice_number = f'INV-{timezone.now().year}-{payment.id:04d}'
                            Invoice.objects.create(
                                payment=payment,
                                invoice_number=invoice_number,
                            )

                except (Payment.DoesNotExist, IndexError, ValueError):
                    pass

            elif event_type in ('checkout.failed', 'checkout.canceled', 'checkout.expired'):
                transaction_id = data.get('id')
                invoice_id = data.get('invoice_id')

                try:
                    parts = invoice_id.split('-')
                    payment_id = int(parts[-1])
                    
                    payment = Payment.objects.get(id=payment_id)
                    payment.status = 'failed'
                    payment.transaction_id = transaction_id
                    payment.save()

                    # Delete subscription
                    payment.subscription.delete()

                except (Payment.DoesNotExist, IndexError, ValueError):
                    pass

            return Response({'status': 'ok'}, status=status.HTTP_200_OK)

        except Exception as e:
            print(f'Webhook error: {str(e)}')
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class PaymentSuccessRedirectView(APIView):
    """Redirect target after successful Chargily payment.
    The Flutter WebView detects 'payment-success' in the URL.
    """
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request):
        payment_id = request.GET.get('payment_id', '')
        html = (
            '<html><body>'
            '<h2>Payment successful!</h2>'
            f'<p>payment_id={payment_id}</p>'
            '</body></html>'
        )
        return HttpResponse(html, content_type='text/html')


class PaymentFailureRedirectView(APIView):
    """Redirect target after a failed Chargily payment.
    The Flutter WebView detects 'payment-failure' in the URL.
    """
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request):
        payment_id = request.GET.get('payment_id', '')
        html = (
            '<html><body>'
            '<h2>Payment failed.</h2>'
            f'<p>payment_id={payment_id}</p>'
            '</body></html>'
        )
        return HttpResponse(html, content_type='text/html')