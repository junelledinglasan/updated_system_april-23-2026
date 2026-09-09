# backend/settings_app/urls.py

from django.urls import path
from . import views

urlpatterns = [
    path('logo/', views.system_logo_view, name='system-logo'),
    path('logo/upload/', views.upload_system_logo_view, name='system-logo-upload'),
    path('logo/reset/', views.reset_system_logo_view, name='system-logo-reset'),

    # ── BAGO: customizable na GCash payment number/account name ──────
    path('gcash/', views.gcash_settings_view, name='gcash-settings'),

    # ── BAGO: maraming GCash account (multiple accounts support) ─────
    path('gcash-accounts/', views.gcash_accounts_list_view, name='gcash-accounts-list'),
    path('gcash-accounts/active/', views.gcash_accounts_active_view, name='gcash-accounts-active'),
    path('gcash-accounts/<int:pk>/', views.gcash_account_detail_view, name='gcash-accounts-detail'),

    path('features/', views.available_features_view, name='available-features'),
    path('staff-permissions/', views.staff_permissions_list_view, name='staff-permissions-list'),
    path('staff-permissions/<int:staff_id>/', views.staff_permissions_detail_view, name='staff-permissions-detail'),
]