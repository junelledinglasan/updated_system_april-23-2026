from django.db import models
from django.utils import timezone
from members.models import Member


class Loan(models.Model):

    LOAN_TYPES = [
        ('Regular Loan',   'Regular Loan'),
        ('Emergency Loan', 'Emergency Loan'),
        ('Salary Loan',    'Salary Loan'),
        ('Housing Loan',   'Housing Loan'),
        ('Business Loan',  'Business Loan'),
        ('Other Loan',     'Other Loan'),
    ]

    STATUS_CHOICES = [
        ('For Review', 'For Review'),
        ('Approved',   'Approved'),
        ('Active',     'Active'),
        ('Completed',  'Completed'),
        ('Declined',   'Declined'),
        ('Overdue',    'Overdue'),
        # ── BAGO: hiwalay sa "Declined" — ito ay kapag ang MEMBER MISMO
        # ang nag-cancel ng sarili niyang "For Review" application, hindi
        # dahil sa desisyon ng admin. ─────────────────────────────────
        ('Cancelled',  'Cancelled'),
    ]

    loan_id        = models.CharField(max_length=20, unique=True, blank=True)
    member         = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='loans')
    loan_type      = models.CharField(max_length=20, choices=LOAN_TYPES)
    amount         = models.DecimalField(max_digits=12, decimal_places=2)
    term_months    = models.IntegerField()
    interest_rate  = models.DecimalField(max_digits=5, decimal_places=2, default=5.00)
    monthly_due    = models.DecimalField(max_digits=12, decimal_places=2)
    balance        = models.DecimalField(max_digits=12, decimal_places=2)
    purpose        = models.TextField()
    collateral     = models.CharField(max_length=200, blank=True)
    status         = models.CharField(max_length=15, choices=STATUS_CHOICES, default='For Review')
    applied_at     = models.DateTimeField(auto_now_add=True)
    approved_at    = models.DateTimeField(null=True, blank=True)
    approved_by    = models.CharField(max_length=50, blank=True)
    # ── BAGO: para sa 2-step na Approve → Confirm Release flow.
    # approved_at/approved_by = kailan/sino nag-"Approve" (status → Approved).
    # released_at/released_by = kailan/sino nag-"Confirm Release" (status → Active,
    # dito lang talaga nakuha ng member ang pera). ──────────────────────────────
    released_at    = models.DateTimeField(null=True, blank=True)
    released_by    = models.CharField(max_length=50, blank=True)
    next_due_date  = models.DateField(null=True, blank=True)
    decline_reason = models.TextField(blank=True)
    remarks        = models.TextField(blank=True)

    class Meta:
        db_table = 'loans'
        ordering = ['-applied_at']

    def __str__(self):
        return f'{self.loan_id} — {self.member.fullname} ({self.status})'

    def save(self, *args, **kwargs):
        if not self.loan_id:
            year   = timezone.now().year
            prefix = f'LN-{year}-'
            existing = Loan.objects.filter(
                loan_id__startswith=prefix
            ).values_list('loan_id', flat=True)
            max_num = 0
            for lid in existing:
                try:
                    num = int(lid.replace(prefix, ''))
                    if num > max_num:
                        max_num = num
                except ValueError:
                    pass
            candidate = f'{prefix}{str(max_num + 1).zfill(3)}'
            while Loan.objects.filter(loan_id=candidate).exists():
                max_num += 1
                candidate = f'{prefix}{str(max_num + 1).zfill(3)}'
            self.loan_id = candidate
        super().save(*args, **kwargs)


# ── Add this to loans/models.py at the bottom ────────────────────────────────

class GCashPaymentRequest(models.Model):
    STATUS_CHOICES = [
        ('Pending',  'Pending'),
        ('Verified', 'Verified'),
        ('Rejected', 'Rejected'),
    ]

    loan            = models.ForeignKey('Loan',   on_delete=models.CASCADE, related_name='gcash_requests')
    member          = models.ForeignKey('members.Member', on_delete=models.CASCADE, related_name='gcash_requests')
    amount          = models.DecimalField(max_digits=12, decimal_places=2)
    reference_number= models.CharField(max_length=20)
    screenshot_url  = models.URLField(max_length=500, blank=True)
    status          = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Pending')
    note            = models.CharField(max_length=200, blank=True)
    verified_by     = models.CharField(max_length=100, blank=True)
    verified_at     = models.DateTimeField(null=True, blank=True)
    reject_reason   = models.CharField(max_length=200, blank=True)
    created_at      = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'gcash_payment_requests'
        ordering = ['-created_at']

    def __str__(self):
        return f'GCash {self.reference_number} — {self.member.fullname} ₱{self.amount} ({self.status})'