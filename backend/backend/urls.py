from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import TokenRefreshView
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/',             admin.site.urls),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    # LEAF MPC API
    path('api/notifications/', include('notifications.urls')),
    path('api/auth/',          include('auth_app.urls')),
    path('api/members/',       include('members.urls')),
    path('api/loans/',         include('loans.urls')),
    path('api/payments/',      include('payments.urls')),
    path('api/announcements/', include('announcements.urls')),
    path('api/reports/',       include('reports.urls')),
    path('api/activity-log/',  include('activity_log.urls')),
    path('api/settings/', include('settings_app.urls')),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)