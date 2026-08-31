# backend/settings_app/models.py
# Bagong Django app para sa: (1) customizable na logo, (2) per-staff
# feature permissions (checkbox kung anong module ang makikita nila),
# (3) BAGO: customizable na GCash payment number/account name.

from django.db import models
from django.conf import settings


class SystemSettings(models.Model):
    """Singleton — isa lang dapat na row ang gagamitin (id=1)."""
    logo = models.ImageField(upload_to='system/', null=True, blank=True)
    # ── BAGO: GCash number/account name na ipinapakita sa member sa
    # "Pay via GCash" modal — dating hardcoded sa GCashPayment.jsx,
    # ngayon nasa database na para ma-edit ng admin sa Settings. ──────
    gcash_number = models.CharField(max_length=20, blank=True, default='0967-006-3500')
    gcash_name   = models.CharField(max_length=100, blank=True, default='LEAF MPC')
    updated_at = models.DateTimeField(auto_now=True)
    updated_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)

    class Meta:
        db_table = 'system_settings'

    def __str__(self):
        return 'System Settings'

    @classmethod
    def get_solo(cls):
        """Kumuha (o gumawa kung wala pa) ng iisang settings row."""
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj


# ── Listahan ng lahat ng available na "features" na pwedeng i-toggle ──────
# I-update lang ito kapag may bagong module na dapat ma-gate.
AVAILABLE_FEATURES = [
    ('members',           'Manage Members'),
    ('applications',      'Online Applications'),
    ('loan-payment',      'Loan Payment'),
    ('loan-approval',     'Loan Approval'),
    ('gcash-verification','GCash Verification'),
    ('announcement',      'Announcement'),
    ('reports',           'Reports'),
]

# ── Default features kada staff_role — GINAGAMIT LANG minsan, sa
# unang pagkakataon na gagawa ng permission record para sa isang
# staff (hal. bago pa sila na-configure sa Settings). Ito yung
# dating hardcoded na NAV_BY_ROLE sa StaffLayout.jsx — para hindi
# biglang mawalan ng access ang mga existing na staff account kapag
# unang na-rollout ang bagong permission system na ito. ──────────
DEFAULT_FEATURES_BY_ROLE = {
    'cashier':     ['loan-payment'],
    'collector':   ['loan-payment'],
    'bookkeeper':  ['reports'],
    'admin_clerk': ['members', 'applications', 'loan-approval', 'announcement', 'reports'],
}


def get_default_features(staff):
    """Ibalik ang default feature list base sa staff_role ng staff —
    ginagamit lang bilang panimulang value kapag UNANG ginawa ang
    kanilang permission record."""
    role = getattr(staff, 'staff_role', None)
    return list(DEFAULT_FEATURES_BY_ROLE.get(role, []))


class StaffFeaturePermission(models.Model):
    """Isang row kada staff account — listahan ng feature keys na
    pinapayagan silang makita/gamitin."""
    staff = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='feature_permission')
    # JSON list ng feature keys, hal. ["members", "reports"]
    features = models.JSONField(default=list, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'staff_feature_permissions'

    def __str__(self):
        return f'{self.staff} — {len(self.features)} features'