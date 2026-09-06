from django.db import models
from django.utils import timezone
from decimal import Decimal
from members.models import Member

# ── BAGO: 2% penalty kada buwang naliban sa due date, base sa
# "Monthly Amortization" (hindi sa buong balance/loan amount). ────────
PENALTY_RATE = Decimal('0.02')


class Loan(models.Model):

    # ── FIX: dating luma pa rin ang mga choices dito (Regular/
    # Emergency/Salary/Housing/Business/Other) — kahit na-update na
    # natin ang lahat ng frontend (web + mobile) papuntang 4 na bagong
    # types, HINDI NATIN NA-UPDATE ANG BACKEND MODEL NA 'TO. Dahil
    # ino-enforce ng Django "choices" ang validation sa serializer
    # level, tinatanggihan ang mga bagong type name (hal. "ATM Loan")
    # na 400 Bad Request — ito ang totoong ugat ng "Failed to submit
    # loan." na error. ───────────────────────────────────────────────
    LOAN_TYPES = [
        ('Regular Loan',    'Regular Loan'),
        ('Petty Cash Loan', 'Petty Cash Loan'),
        ('Appliance Loan',  'Appliance Loan'),
        ('ATM Loan',        'ATM Loan'),
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
    # ── BAGO: bilang ng buwan na NAKA-APPLY NA ang 2% penalty, para sa
    # kasalukuyang "streak" ng pagkakalampas sa due date. Ginagamit para
    # hindi doble-doble maka-apply ng penalty sa parehong buwan kada
    # tawag ng "apply_overdue_penalty()" — tingnan ang method sa ibaba.
    # Nire-reset ito pabalik sa 0 kapag naabot na ulit ng member ang
    # kanyang susunod na due date (hindi na overdue). ───────────────────
    months_overdue_penalized = models.IntegerField(default=0)
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

    # ══════════════════════════════════════════════════════════════════
    #  BAGO: 2% Penalty kada buwang naliban — tingnan ang usapan tungkol
    #  dito. Ang penalty ay 2% ng "Monthly Amortization" (hindi sa
    #  balance/loan amount), IDINAGDAG DIRETSO sa "balance" (parte na
    #  ng dapat bayaran ng member), at SUMASAMA kada karagdagang buwan
    #  na naliban (2 buwang naliban = 2x ang penalty).
    #
    #  Tinatawag ito sa mga lugar kung saan kinukuha/ipinapakita ang
    #  mga Active loans (hal. sa Loan Payment list view, o sa isang
    #  management command na tumatakbo araw-araw via cron) — hindi ito
    #  awtomatikong tumatakbo sa background nang mag-isa, kailangan
    #  itong TAWAGIN.
    # ══════════════════════════════════════════════════════════════════
    def apply_overdue_penalty(self):
        """I-check kung overdue na ang loan na 'to, at kung gayon,
        i-apply ang ESCALATING na 2% penalty — sa bawat buwan, ang
        batayan ng 2% ay ang KABUUANG naipong hindi pa bayad na
        monthly dues (hindi lang isang buwan), kaya lumalaki ang
        penalty kada karagdagang buwan:
            Buwan 1: (monthly_due × 1) × 2%
            Buwan 2: (monthly_due × 2) × 2%   ← mas malaki, dahil 2
                                                 buwan nang unpaid dues
            Buwan 3: (monthly_due × 3) × 2%
            ...at ang mga ito ay PINAGSASAMA (idinadagdag) sa bawat
        buwan — kaya ang TOTAL penalty pagkatapos ng N buwan ay:
            monthly_due × 2% × N × (N+1) / 2   (triangular number)
        Halimbawa: ₱10,000 loan, 3 months (monthly_due=₱3,333.33) —
        1 buwan late = ₱66.67, 2 buwan late = ₱200 total, 3 buwan
        late = ₱400 total.
        Hindi muling babayaran ang mga buwang na-penalize na dati —
        ang formula sa ibaba ay TAMANG NAG-IINCREMENT kahit tumalon
        nang maraming buwan sa isang tawag (gamit ang pagkakaiba ng
        dalawang triangular number). Ibinabalik ang halaga ng BAGONG
        idinagdag na penalty (0 kung wala)."""
        if self.status not in ('Active', 'Overdue') or not self.next_due_date:
            return Decimal('0.00')

        today = timezone.now().date()
        if self.next_due_date >= today:
            # Hindi pa overdue — kung dati ay overdue, i-reset ang counter.
            if self.months_overdue_penalized > 0:
                self.months_overdue_penalized = 0
                self.save(update_fields=['months_overdue_penalized'])
            return Decimal('0.00')

        # ── Bilangin kung ilang BUONG buwan na ang lumipas mula sa due
        # date (kasama na ang unang buwan mismo, dahil overdue na siya). ──
        months_late = (today.year - self.next_due_date.year) * 12 + (today.month - self.next_due_date.month)
        if today.day < self.next_due_date.day:
            months_late -= 1
        months_late = max(0, months_late) + 1

        if months_late <= self.months_overdue_penalized:
            return Decimal('0.00')

        # ── Triangular number: T(n) = n(n+1)/2 — ang pagkakaiba ng
        # T(bago) at T(dati) ay eksaktong ang TAMANG dagdag na penalty,
        # kahit tumalon nang maraming buwan sa isang tawag. ─────────────
        def triangular(n):
            return n * (n + 1) // 2

        prev_units = triangular(self.months_overdue_penalized)
        new_units  = triangular(months_late)
        added_units = new_units - prev_units  # bilang ng "units" ng monthly_due×2%

        penalty = (self.monthly_due * PENALTY_RATE * added_units).quantize(Decimal('0.01'))
        self.balance = self.balance + penalty
        self.months_overdue_penalized = months_late
        self.status = 'Overdue'
        self.save(update_fields=['balance', 'months_overdue_penalized', 'status'])
        return penalty


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