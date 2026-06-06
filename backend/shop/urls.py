from django.urls import path
from .views import ShopCatalogueView, ShopOrderHistoryView, ShopCheckoutView

urlpatterns = [
    path('products/', ShopCatalogueView.as_view(), name='shop-catalogue'),
    path('checkout/', ShopCheckoutView.as_view(), name='shop-checkout'),
    path('orders/', ShopOrderHistoryView.as_view(), name='shop-order-history'),
]
