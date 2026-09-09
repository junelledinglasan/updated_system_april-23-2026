# backend/settings_app/serializers.py

from rest_framework import serializers
from .models import SystemSettings, StaffFeaturePermission, AVAILABLE_FEATURES, GCashAccount


class SystemSettingsSerializer(serializers.ModelSerializer):
    logo_url = serializers.SerializerMethodField()

    class Meta:
        model = SystemSettings
        # ── BAGO: kasama na ang gcash_number/gcash_name — read-write
        # (hindi write_only tulad ng logo), dahil kailangan silang
        # ibalik nang direkta sa GET response (walang hiwalay na "url"
        # transform tulad ng logo → logo_url). ─────────────────────────
        fields = ['id', 'logo', 'logo_url', 'gcash_number', 'gcash_name', 'updated_at']
        extra_kwargs = {'logo': {'write_only': True, 'required': False}}

    def get_logo_url(self, obj):
        request = self.context.get('request')
        if obj.logo and hasattr(obj.logo, 'url'):
            url = obj.logo.url
            if request is not None:
                return request.build_absolute_uri(url)
            return url
        return None


# ── BAGO: para sa maraming GCash account ─────────────────────────────
class GCashAccountSerializer(serializers.ModelSerializer):
    class Meta:
        model  = GCashAccount
        fields = ['id', 'label', 'number', 'account_name', 'is_active', 'created_at']


class StaffFeaturePermissionSerializer(serializers.ModelSerializer):
    staff_id = serializers.IntegerField(source='staff.id', read_only=True)
    staff_name = serializers.SerializerMethodField()
    staff_role = serializers.SerializerMethodField()

    class Meta:
        model = StaffFeaturePermission
        fields = ['staff_id', 'staff_name', 'staff_role', 'features', 'updated_at']

    def get_staff_name(self, obj):
        return getattr(obj.staff, 'name', None) or obj.staff.username

    def get_staff_role(self, obj):
        return getattr(obj.staff, 'staff_role', None)