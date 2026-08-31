# backend/settings_app/urls.py

from django.urls import path
from . import views

urlpatterns = [
    path('logo/', views.system_logo_view, name='system-logo'),
    path('logo/upload/', views.upload_system_logo_view, name='system-logo-upload'),
    path('logo/reset/', views.reset_system_logo_view, name='system-logo-reset'),

    # ── BAGO: customizable na GCash payment number/account name ──────
    path('gcash/', views.gcash_settings_view, name='gcash-settings'),

    path('features/', views.available_features_view, name='available-features'),
    path('staff-permissions/', views.staff_permissions_list_view, name='staff-permissions-list'),
    path('staff-permissions/<int:staff_id>/', views.staff_permissions_detail_view, name='staff-permissions-detail'),
]