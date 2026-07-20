from rest_framework import serializers
from .models import Loan


class LoanSerializer(serializers.ModelSerializer):
    member_name = serializers.CharField(source='member.fullname',  read_only=True)
    member_code = serializers.CharField(source='member.member_id', read_only=True)
    member      = serializers.PrimaryKeyRelatedField(read_only=True)

    is_f2f = serializers.BooleanField(required=False, default=False, write_only=True)

    class Meta:
        model  = Loan
        fields = '__all__'


class CreateLoanSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Loan
        fields = ['loan_type', 'amount', 'term_months', 'purpose', 'collateral', 'member']
        extra_kwargs = {
            'member':    { 'required': False },
            'collateral':{ 'required': False },
        }

    def validate(self, data):
        request = self.context.get('request')

        # ── Resolve member ──────────────────────────────────────────────────
        if not data.get('member'):
            if request and getattr(request.user, 'role', None) == 'member':
                from members.models import Member
                try:
                    data['member'] = Member.objects.get(user=request.user)
                except Member.DoesNotExist:
                    raise serializers.ValidationError(
                        {'member': 'No member profile found for this account.'}
                    )
            else:
                raise serializers.ValidationError({'member': 'Member is required.'})

        member = data['member']
        amount = float(data.get('amount', 0))

        # ── 1. Minimum amount ───────────────────────────────────────────────
        if amount < 3000:
            raise serializers.ValidationError(
                {'amount': 'Minimum loan amount is ₱3,000.'}
            )

        # ── 2. Max loanable (Share Capital × 2) ────────────────────────────
        max_loanable = float(member.share_capital) * 2
        if amount > max_loanable:
            raise serializers.ValidationError(
                {'amount': f'Amount exceeds your max loanable of ₱{max_loanable:,.2f} (Share Capital × 2).'}
            )

        # ── 3. Overdue loan check ───────────────────────────────────────────
        overdue_loans = Loan.objects.filter(member=member, status='Overdue')
        if overdue_loans.exists():
            overdue_ids = ', '.join(l.loan_id for l in overdue_loans)
            raise serializers.ValidationError(
                {'non_field_errors': f'You have overdue loan(s): {overdue_ids}. Please settle them first before applying for a new loan.'}
            )

        # ── 4. Active loan performance check ───────────────────────────────
        # Check if member has active loans with poor payment performance
        # Poor = more than 2 months of missed payments
        from django.utils import timezone
        from datetime import date

        active_loans = Loan.objects.filter(member=member, status='Active')
        for loan in active_loans:
            if loan.next_due_date and loan.next_due_date < date.today():
                days_overdue = (date.today() - loan.next_due_date).days
                if days_overdue > 30:
                    raise serializers.ValidationError(
                        {'non_field_errors': f'Your loan {loan.loan_id} has a missed payment. Please settle your dues before applying for a new loan.'}
                    )

        # ── 5. Existing pending/active loan check ───────────────────────────
        # Allow new application only if member has no active loans
        # OR if member has good payment standing
        existing_active = Loan.objects.filter(
            member=member,
            status__in=['Active', 'For Review']
        )
        if existing_active.exists():
            # Check admin role — admin can override
            if request and getattr(request.user, 'role', None) not in ['admin', 'staff']:
                active_ids = ', '.join(l.loan_id for l in existing_active[:3])
                raise serializers.ValidationError(
                    {'non_field_errors': f'You still have an active or pending loan ({active_ids}). Please complete or settle it before applying for a new one.'}
                )

        return data

    def create(self, validated_data):
        amount = float(validated_data['amount'])
        term   = int(validated_data['term_months'])

        if amount <= 50000:
            monthly_rate = 0.0125
        elif amount <= 150000:
            monthly_rate = 0.01125
        else:
            monthly_rate = 0.01

        interest      = monthly_rate * amount * term
        monthly_due   = (amount + interest) / term
        balance       = amount
        interest_rate = monthly_rate * 12 * 100

        is_f2f = validated_data.pop('is_f2f', False)

        loan = Loan.objects.create(
            **validated_data,
            monthly_due   = round(monthly_due, 2),
            balance       = round(balance, 2),
            interest_rate = round(interest_rate, 2),
            status        = 'Active' if is_f2f else 'For Review',
        )
        return loan