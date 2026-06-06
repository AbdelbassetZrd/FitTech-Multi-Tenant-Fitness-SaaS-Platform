from django.db import transaction
from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from drf_spectacular.utils import extend_schema

from users.permissions import IsMemberToken, IsMemberOrCoach
from notifications.models import Notification
from .models import Product, Order, OrderItem
from .serializers import ProductSerializer, OrderSerializer, CheckoutSerializer


@extend_schema(tags=["Boutique"])
class ShopCatalogueView(generics.ListAPIView):
    """View the full store catalogue (available to all authenticated users)."""
    queryset = Product.objects.all().order_by('-created_at')
    serializer_class = ProductSerializer


@extend_schema(tags=["Boutique"])
class ShopOrderHistoryView(generics.ListAPIView):
    """View order history for the currently authenticated user."""
    serializer_class = OrderSerializer
    permission_classes = [IsMemberOrCoach]

    def get_queryset(self):
        return Order.objects.filter(buyer=self.request.user).prefetch_related('items__product')


@extend_schema(tags=["Boutique"])
class ShopCheckoutView(APIView):
    """Processes a shopping cart. Automatically adjusts stock and mimics successful payment completion."""
    permission_classes = [IsMemberOrCoach]

    @extend_schema(request=CheckoutSerializer, responses={201: OrderSerializer})
    def post(self, request):
        serializer = CheckoutSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        items_data = serializer.validated_data['items']
        
        # Verify cart isn't empty
        if not items_data:
            return Response({"error": "Cart is empty."}, status=status.HTTP_400_BAD_REQUEST)

        # Build order atomically to prevent stock race conditions
        with transaction.atomic():
            order = Order.objects.create(
                buyer=request.user,
                status='completed' # Mock payment -> Instant completion
            )
            
            total_price = 0
            for item in items_data:
                product_id = item['product_id']
                quantity = item['quantity']
                
                try:
                    product = Product.objects.select_for_update().get(id=product_id)
                except Product.DoesNotExist:
                    # Roolback internally if invalid product is passed
                    return Response({"error": f"Product ID {product_id} not found."}, status=status.HTTP_404_NOT_FOUND)
                
                # Check stock limits
                if product.stock < quantity:
                    return Response(
                        {"error": f"Insufficient stock for {product.name}. Only {product.stock} remaining."},
                        status=status.HTTP_400_BAD_REQUEST
                    )
                
                # Adjust internal stock safely and compile item line
                product.stock -= quantity
                product.save(update_fields=['stock'])
                
                item_price = product.price
                total_price += (item_price * quantity)
                
                OrderItem.objects.create(
                    order=order,
                    product=product,
                    quantity=quantity,
                    price_at_purchase=item_price
                )
            
            order.total_price = total_price
            order.save(update_fields=['total_price'])

            # Send Notification immediately after successful checkout
            Notification.objects.create(
                member=request.user.member_profile if hasattr(request.user, 'member_profile') else request.user,
                notification_type='order_confirmed',
                title=f"Order Confirmed: #{order.pk}",
                message=f"Thank you for your purchase! Your order total was ${total_price}."
            )

        return Response(OrderSerializer(order).data, status=status.HTTP_201_CREATED)
