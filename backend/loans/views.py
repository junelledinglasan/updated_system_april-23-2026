import datetime
from decimal import Decimal, InvalidOperation
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from notifications.email_utils import send_loan_approved_email, send_gcash_verified_email, send_gcash_rejected_email, send_loan_declined_email, send_loan_approved_pending_release_email
from dateutil.relativedelta import relativedelta

from activity_log.utils import log_activity
from .models import Loan
from .serializers import LoanSerializer, CreateLoanSerializer
from django.utils import timezone as tz


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def loan_list_view(request):
    if request.method == 'GET':
        loans = Loan.objects.select_related(
            'member', 'member__pre_member', 'member__user',
        ).all()
        if request.user.role == 'member':
            loans = loans.filter(member__user=request.user)
        if s := request.query_params.get('status'):
            loans = loans.filter(status=s)
        if q := request.query_params.get('search', '').strip():
            loans = loans.filter(member__pre_member__last_name__icontains=q) | \
                    loans.filter(member__pre_member__first_name__icontains=q) | \
                    loans.filter(loan_id__icontains=q)
        return Response(LoanSerializer(loans, many=True).data)

    s = CreateLoanSerializer(data=request.data, context={'request': request})
    if s.is_valid():
        loan = s.save()
        log_activity(
            'loan',
            f'Loan application submitted: {loan.loan_id} — {loan.member.fullname} — ₱{loan.amount:,.2f} ({loan.loan_type})',
            request.user
        )

        # ── If F2F loan (created as Active by serializer), do post-approval tasks ──
        if loan.status == 'Active':
            import datetime
            from members.models import Savings
            from django.db.models import Sum
            from dateutil.relativedelta import relativedelta

            loan.approved_at   = timezone.now()
            loan.approved_by   = request.user.username
            loan.next_due_date = datetime.date.today() + relativedelta(months=1)

            # Add 3% share capital CBU
            share_capital_addition = loan.amount * Decimal('0.03')
            loan.member.share_capital += share_capital_addition
            loan.member.save()

            # Add 1% savings deposit
            savings_deposit = loan.amount * Decimal('0.01')
            total_dep = Savings.objects.filter(member=loan.member, transaction_type='Deposit').aggregate(t=Sum('amount'))['t'] or Decimal('0')
            total_wdr = Savings.objects.filter(member=loan.member, transaction_type='Withdraw').aggregate(t=Sum('amount'))['t'] or Decimal('0')
            new_balance = (total_dep - total_wdr) + savings_deposit
            Savings.objects.create(
                member=loan.member, transaction_type='Deposit', amount=savings_deposit,
                balance_after=new_balance,
                note=f'Auto-deposit from F2F loan {loan.loan_id} (1% savings deposit)',
                recorded_by=request.user.username,
            )
            loan.save()
            log_activity('loan', f'F2F Loan created & activated: {loan.loan_id} — {loan.member.fullname}', request.user)

        return Response(LoanSerializer(loan).data, status=201)

    print(f"[LOAN CREATE ERROR] {s.errors}")
    return Response(s.errors, status=400)


@api_view(['GET', 'PATCH'])
@permission_classes([IsAuthenticated])
def loan_detail_view(request, pk):
    try:
        loan = Loan.objects.select_related(
            'member', 'member__pre_member', 'member__user',
        ).get(pk=pk)
    except Loan.DoesNotExist:
        return Response({'error': 'Not found.'}, status=404)

    if request.method == 'GET':
        return Response(LoanSerializer(loan).data)

    # ══════════════════════════════════════════════════════════════════
    # ── BAGO: MEMBER-SIDE edit/cancel — pinapayagan LANG habang "For
    # Review" pa ang status (bago pa ma-review ng admin), at ang
    # nag-e-edit/cancel ay dapat ang may-ari mismo ng loan. Kapag
    # "Approved" na o iba pa, hindi na dito papasok — babagsak sa
    # admin/staff-only block sa ibaba, na magbabalik ng "Unauthorized"
    # para sa member. ────────────────────────────────────────────────
    # ══════════════════════════════════════════════════════════════════
    if request.user.role == 'member':
        if not loan.member.user_id or loan.member.user_id != request.user.id:
            return Response({'error': 'Unauthorized.'}, status=403)
        if loan.status != 'For Review':
            return Response({'error': 'You can only edit or cancel a loan application while it is still For Review.'}, status=400)

        new_status = request.data.get('status')

        # ── CANCEL ──
        if new_status == 'Cancelled':
            loan.status = 'Cancelled'
            loan.save()
            log_activity('loan',
                f'Loan application cancelled by member: {loan.loan_id} — {loan.member.fullname}',
                request.user)
            return Response(LoanSerializer(loan).data)

        if new_status:
            return Response({'error': 'Invalid status update.'}, status=400)

        # ── EDIT (no 'status' in payload → treat as a details edit) ──
        amount_raw      = request.data.get('amount', loan.amount)
        term_raw        = request.data.get('term_months', loan.term_months)
        purpose         = request.data.get('purpose', loan.purpose)
        collateral      = request.data.get('collateral', loan.collateral)
        loan_type       = request.data.get('loan_type', loan.loan_type)

        try:
            amount = Decimal(str(amount_raw))
            term_months = int(term_raw)
        except (ValueError, TypeError, InvalidOperation):
            return Response({'error': 'Invalid amount or term.'}, status=400)

        if amount < 3000:
            return Response({'error': 'Minimum loan amount is ₱3,000.'}, status=400)

        max_loanable = float(loan.member.share_capital) * 2
        if float(amount) > max_loanable:
            return Response({'error': f'Amount exceeds your max loanable of ₱{max_loanable:,.2f} (Share Capital × 2).'}, status=400)

        if not str(purpose).strip():
            return Response({'error': 'Purpose is required.'}, status=400)

        if amount <= 50000:
            monthly_rate = Decimal('0.0125')
        elif amount <= 150000:
            monthly_rate = Decimal('0.01125')
        else:
            monthly_rate = Decimal('0.01')

        interest      = monthly_rate * amount * term_months
        monthly_due   = (amount + interest) / term_months
        interest_rate = monthly_rate * 12 * 100

        loan.loan_type     = loan_type
        loan.amount        = amount.quantize(Decimal('0.01'))
        loan.term_months   = term_months
        loan.purpose       = purpose
        loan.collateral    = collateral
        loan.monthly_due   = monthly_due.quantize(Decimal('0.01'))
        loan.balance       = amount.quantize(Decimal('0.01'))
        loan.interest_rate = interest_rate.quantize(Decimal('0.01'))
        loan.save()

        log_activity('loan',
            f'Loan application edited by member: {loan.loan_id} — {loan.member.fullname} — ₱{loan.amount:,.2f}',
            request.user)
        return Response(LoanSerializer(loan).data)

    # ══════════════════════════════════════════════════════════════════
    # ── ADMIN/STAFF path (existing — unchanged) ──
    # ══════════════════════════════════════════════════════════════════
    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)

    new_status = request.data.get('status')
    if new_status:
        if new_status == 'Approved':
            # ── BAGO: guard laban sa race condition — posibleng na-
            # cancel na ng member ang loan na ito (o na-process na ng
            # ibang admin session) habang stale pa ang datos na
            # kinukuha ng kasalukuyang view. Kailangang "For Review"
            # pa talaga bago payagang mag-Approve. ────────────────────
            if loan.status != 'For Review':
                return Response({'error': f'This loan is no longer For Review (current status: {loan.status}). It may have been cancelled or already processed.'}, status=400)

            # ── BAGO: Approve lang — HINDI pa naibibigay ang pera.
            # Walang CBU, walang savings deposit, walang due date pa.
            # Ang mga 'yon ay mangyayari lang pagka-"Confirm Release"
            # (new_status == 'Active', ibaba). ───────────────────────
            loan.status       = 'Approved'
            loan.approved_at  = timezone.now()
            loan.approved_by  = request.user.username

            log_activity('loan',
                f'Loan approved (waiting for release): {loan.loan_id} — {loan.member.fullname} — ₱{loan.amount:,.2f}',
                request.user)

            try:
                pm = getattr(loan.member, 'pre_member', None)
                email_addr = (pm.email if pm else None) or getattr(loan.member.user, 'email', None)
                if email_addr:
                    send_loan_approved_pending_release_email(
                        email=email_addr, fullname=loan.member.fullname,
                        member_id=loan.member.member_id, loan_id=loan.loan_id,
                        loan_type=loan.loan_type, amount=loan.amount,
                    )
            except Exception as e:
                print(f"[EMAIL ERROR] Loan approved-pending-release email failed: {e}")

        elif new_status == 'Active':
            # ── BAGO: "Confirm Release" — dito lang mangyayari ang
            # totoong pag-release ng pera (F2F sa opisina). Dito lang
            # magsisimula ang due date countdown, CBU, at savings
            # deposit — hindi na sa unang "Approve" step. ────────────
            if loan.status != 'Approved':
                return Response({'error': 'Loan must be Approved first before it can be released.'}, status=400)

            # ── FIX: tinanggal ang lokal na "from decimal import
            # Decimal" na dating narito. Dahil sa Python scoping rules,
            # kapag may import/assignment sa isang pangalan KAHIT SAAN
            # sa loob ng function, itinuturing itong LOCAL variable sa
            # BUONG function — kahit may global import na sa taas ng
            # file. Ito ang naging dahilan ng "UnboundLocalError:
            # cannot access local variable 'Decimal'" sa member-edit
            # branch (na tumatakbo bago maabot ang linyang ito). Gamit
            # na lang ngayon ang Decimal mula sa module-level import
            # (linya 2 ng file). ─────────────────────────────────────
            from members.models import Savings
            from django.db.models import Sum

            loan.status        = 'Active'
            loan.released_at   = timezone.now()
            loan.released_by   = request.user.username
            loan.next_due_date = datetime.date.today() + relativedelta(months=1)

            share_capital_addition = loan.amount * Decimal('0.03')
            loan.member.share_capital += share_capital_addition
            loan.member.save()

            savings_deposit = loan.amount * Decimal('0.01')
            total_dep = Savings.objects.filter(member=loan.member, transaction_type='Deposit').aggregate(t=Sum('amount'))['t'] or Decimal('0')
            total_wdr = Savings.objects.filter(member=loan.member, transaction_type='Withdraw').aggregate(t=Sum('amount'))['t'] or Decimal('0')
            current_balance = total_dep - total_wdr
            new_balance     = current_balance + savings_deposit

            Savings.objects.create(
                member=loan.member, transaction_type='Deposit', amount=savings_deposit,
                balance_after=new_balance,
                note=f'Auto-deposit from loan {loan.loan_id} (1% savings deposit)',
                recorded_by=request.user.username,
            )

            log_activity('loan',
                f'Loan money released & activated: {loan.loan_id} — {loan.member.fullname} — ₱{loan.amount:,.2f} | Share Capital +₱{share_capital_addition:,.2f} | Savings Deposit +₱{savings_deposit:,.2f}',
                request.user)

            try:
                pm = getattr(loan.member, 'pre_member', None)
                email_addr = (pm.email if pm else None) or getattr(loan.member.user, 'email', None)
                if email_addr:
                    send_loan_approved_email(
                        email=email_addr, fullname=loan.member.fullname,
                        member_id=loan.member.member_id, loan_id=loan.loan_id,
                        loan_type=loan.loan_type, amount=loan.amount,
                        monthly_due=loan.monthly_due, term_months=loan.term_months,
                        next_due_date=str(loan.next_due_date),
                    )
            except Exception as e:
                print(f"[EMAIL ERROR] Loan released/active email failed: {e}")

        elif new_status == 'Declined':
            # ── BAGO: parehong guard — hindi puwedeng i-decline ang
            # loan na hindi na "For Review" (hal. na-cancel na ng
            # member, o na-approve na sa ibang session). ─────────────
            if loan.status != 'For Review':
                return Response({'error': f'This loan is no longer For Review (current status: {loan.status}). It may have been cancelled or already processed.'}, status=400)

            loan.status         = 'Declined'
            loan.decline_reason = request.data.get('decline_reason', '')
            log_activity('loan', f'Loan declined: {loan.loan_id} — {loan.member.fullname}', request.user)

            try:
                pm = getattr(loan.member, 'pre_member', None)
                email_addr = (pm.email if pm else None) or getattr(loan.member.user, 'email', None)
                if email_addr:
                    send_loan_declined_email(
                        email=email_addr, fullname=loan.member.fullname,
                        member_id=loan.member.member_id, loan_id=loan.loan_id,
                        loan_type=loan.loan_type, amount=loan.amount,
                        decline_reason=loan.decline_reason,
                    )
            except Exception as e:
                print(f"[EMAIL ERROR] Loan declined email failed: {e}")
        else:
            loan.status = new_status

        if request.data.get('remarks'):
            loan.remarks = request.data.get('remarks')
        loan.save()

    return Response(LoanSerializer(loan).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def due_dates_view(request):
    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)

    loans = Loan.objects.filter(
        status__in=['Active', 'Overdue'], next_due_date__isnull=False
    ).select_related('member', 'member__pre_member')

    month_str = request.query_params.get('month', '')
    if month_str:
        try:
            year, month = map(int, month_str.split('-'))
            loans = loans.filter(next_due_date__year=year, next_due_date__month=month)
        except Exception:
            pass

    grouped = {}
    for loan in loans:
        key = loan.next_due_date.strftime('%Y-%m-%d')
        if key not in grouped:
            grouped[key] = []
        grouped[key].append({
            'loan_id':     loan.loan_id,
            'member_name': loan.member.fullname,
            'member_id':   loan.member.member_id,
            'loan_type':   loan.loan_type,
            'balance':     float(loan.balance),
            'monthly_due': float(loan.monthly_due),
            'status':      loan.status,
        })

    return Response(grouped)


# ══════════════════════════════════════════════════════════════════════════════
# GCASH PAYMENT REQUESTS
# ══════════════════════════════════════════════════════════════════════════════

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def gcash_request_list_view(request):
    if request.method == 'GET':
        from .models import GCashPaymentRequest
        if request.user.role in ['admin', 'staff']:
            qs = GCashPaymentRequest.objects.select_related(
                'loan', 'member', 'member__pre_member'
            ).all()
            if s := request.query_params.get('status'):
                qs = qs.filter(status=s)
        else:
            try:
                from members.models import Member
                member = Member.objects.get(user=request.user)
                qs = GCashPaymentRequest.objects.filter(member=member).select_related('loan')
            except Member.DoesNotExist:
                return Response([], status=200)

        return Response([{
            'id':               r.id,
            'loan_id':          r.loan.loan_id,
            'loan_pk':          r.loan.id,
            'member_id':        r.member.member_id,
            'member_name':      r.member.fullname,
            'amount':           float(r.amount),
            'reference_number': r.reference_number,
            'screenshot_url':   r.screenshot_url,
            'status':           r.status,
            'note':             r.note,
            'verified_by':      r.verified_by,
            'verified_at':      str(r.verified_at)[:16] if r.verified_at else '',
            'reject_reason':    r.reject_reason,
            'created_at':       r.created_at.strftime('%Y-%m-%d %H:%M'),
        } for r in qs])

    # POST — member submits
    if request.user.role not in ['member']:
        return Response({'error': 'Only members can submit GCash payment requests.'}, status=403)

    try:
        from members.models import Member
        member = Member.objects.get(user=request.user)
    except Member.DoesNotExist:
        return Response({'error': 'Member profile not found.'}, status=404)

    from .models import GCashPaymentRequest
    data           = request.data
    loan_pk        = data.get('loan_id')
    amount         = data.get('amount')
    ref_no         = data.get('reference_number', '').strip()
    note           = data.get('note', '')
    # ── FIX: dating hindi kinukuha ang screenshot_url mula sa request
    # body — kahit matagumpay na na-upload ng member sa Supabase
    # Storage ang proof of payment (at nakuha nga ang public URL sa
    # frontend), hindi ito naisasave sa database dahil wala itong
    # dinaanan papunta sa .create() call sa ibaba. ────────────────────
    screenshot_url = data.get('screenshot_url', '')

    if not loan_pk:
        return Response({'error': 'loan_id is required.'}, status=400)
    if not amount or float(amount) <= 0:
        return Response({'error': 'Valid amount is required.'}, status=400)
    if not ref_no:
        return Response({'error': 'GCash reference number is required.'}, status=400)
    if len(ref_no) < 10:
        return Response({'error': 'Invalid reference number format. Must be at least 10 characters.'}, status=400)
    if GCashPaymentRequest.objects.filter(reference_number=ref_no).exists():
        return Response({'error': 'This GCash reference number has already been submitted.'}, status=400)

    try:
        loan = Loan.objects.get(pk=loan_pk, member=member)
    except Loan.DoesNotExist:
        return Response({'error': 'Loan not found.'}, status=404)

    if loan.status not in ['Active', 'Overdue']:
        return Response({'error': 'Payment can only be submitted for active or overdue loans.'}, status=400)

    existing = GCashPaymentRequest.objects.filter(loan=loan, status='Pending').first()
    if existing:
        return Response({'error': f'You already have a pending GCash request (Ref: {existing.reference_number}). Wait for admin verification.'}, status=400)

    req = GCashPaymentRequest.objects.create(
        loan=loan, member=member, amount=float(amount),
        reference_number=ref_no, note=note,
        screenshot_url=screenshot_url,
    )

    log_activity('payment',
        f'GCash payment request: {member.fullname} ({member.member_id}) — Loan {loan.loan_id} — ₱{float(amount):,.2f} — Ref: {ref_no}',
        request.user)

    return Response({
        'id':               req.id,
        'message':          'GCash payment request submitted! Admin will verify and record your payment.',
        'reference_number': ref_no,
        'amount':           float(amount),
        'status':           'Pending',
    }, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def gcash_request_detail_view(request, pk):
    from .models import GCashPaymentRequest
    try:
        req = GCashPaymentRequest.objects.select_related(
            'loan', 'member', 'member__pre_member'
        ).get(pk=pk)
    except GCashPaymentRequest.DoesNotExist:
        return Response({'error': 'Not found.'}, status=404)

    if request.user.role == 'member':
        from members.models import Member
        try:
            member = Member.objects.get(user=request.user)
            if req.member != member:
                return Response({'error': 'Unauthorized.'}, status=403)
        except Member.DoesNotExist:
            return Response({'error': 'Unauthorized.'}, status=403)

    return Response({
        'id':               req.id,
        'loan_id':          req.loan.loan_id,
        'loan_pk':          req.loan.id,
        'member_id':        req.member.member_id,
        'member_name':      req.member.fullname,
        'amount':           float(req.amount),
        'reference_number': req.reference_number,
        'screenshot_url':   req.screenshot_url,
        'status':           req.status,
        'note':             req.note,
        'verified_by':      req.verified_by,
        'verified_at':      str(req.verified_at)[:16] if req.verified_at else '',
        'reject_reason':    req.reject_reason,
        'created_at':       req.created_at.strftime('%Y-%m-%d %H:%M'),
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def gcash_verify_view(request, pk):
    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)

    from .models import GCashPaymentRequest
    try:
        req = GCashPaymentRequest.objects.select_related('loan', 'member', 'member__user').get(pk=pk)
    except GCashPaymentRequest.DoesNotExist:
        return Response({'error': 'Not found.'}, status=404)

    if req.status != 'Pending':
        return Response({'error': f'Request already {req.status}.'}, status=400)

    action        = request.data.get('action')
    reject_reason = request.data.get('reject_reason', '')

    if action not in ['verify', 'reject']:
        return Response({'error': "action must be 'verify' or 'reject'."}, status=400)

    # ── REJECT ────────────────────────────────────────────────────────────────
    if action == 'reject':
        req.status        = 'Rejected'
        req.reject_reason = reject_reason or 'Payment could not be verified.'
        req.verified_by   = request.user.username
        req.verified_at   = tz.now()
        req.save()

        log_activity('payment',
            f'GCash payment REJECTED: {req.member.fullname} Ref:{req.reference_number} — {req.reject_reason}',
            request.user)

        # ── Send rejected email ──
        try:
            pm = getattr(req.member, 'pre_member', None)
            email_addr = (pm.email if pm else None) or getattr(req.member.user, 'email', None)
            if email_addr:
                send_gcash_rejected_email(
                    email=email_addr, fullname=req.member.fullname,
                    member_id=req.member.member_id, loan_id=req.loan.loan_id,
                    reference_number=req.reference_number,
                    amount=float(req.amount), reject_reason=req.reject_reason,
                )
        except Exception as e:
            print(f"[EMAIL ERROR] GCash rejected email failed: {e}")

        # ── In-app notification ──
        try:
            from notifications.models import Notification
            Notification.objects.create(
                user       = req.member.user,
                title      = "GCash Payment Not Verified ❌",
                message    = f"Your GCash payment (Ref: {req.reference_number}, ₱{float(req.amount):,.2f}) for loan {req.loan.loan_id} was not verified. Reason: {req.reject_reason}. Please resubmit with the correct details.",
                notif_type = "payment",
            )
        except Exception as e:
            print(f"[NOTIF ERROR] {e}")

        return Response({'message': 'Payment request rejected.', 'status': 'Rejected'})

    # ── VERIFY ────────────────────────────────────────────────────────────────
    from decimal import Decimal
    from payments.models import Payment

    loan   = req.loan
    amount = Decimal(str(req.amount))

    new_balance = max(Decimal('0'), loan.balance - amount)

    # ── Create payment (tx_id and hash auto-generated by Payment model) ──
    payment = Payment.objects.create(
        loan        = loan,
        member      = loan.member,
        amount      = amount,
        balance     = new_balance,
        recorded_by = request.user.username,
        note        = f'GCash payment — Ref: {req.reference_number}',
    )

    # ── Record on blockchain ──
    try:
        from payments.blockchain import record_payment_on_blockchain
        bc = record_payment_on_blockchain(
            tx_id     = payment.tx_id,
            member_id = loan.member.member_id,
            loan_id   = loan.loan_id,
            amount    = float(amount),
        )
        payment.hash         = bc.get('hash', payment.hash)
        payment.polygon_tx   = bc.get('tx_hash')
        payment.block_number = bc.get('block')
        payment.network      = bc.get('network', 'local')
        payment.save()
    except Exception as e:
        print(f"[BLOCKCHAIN ERROR] GCash blockchain record failed: {e}")

    tx_id = payment.tx_id
    loan.balance = new_balance
    if new_balance <= 0:
        loan.status  = 'Completed'
        loan.balance = Decimal('0')
    else:
        loan.next_due_date = datetime.date.today() + relativedelta(months=1)
    loan.save()

    req.status      = 'Verified'
    req.verified_by = request.user.username
    req.verified_at = tz.now()
    req.save()

    log_activity('payment',
        f'GCash payment VERIFIED: {req.member.fullname} ({req.member.member_id}) — Loan {loan.loan_id} — ₱{float(amount):,.2f} — Ref: {req.reference_number} — by {request.user.username}',
        request.user)

    # ── Send verified email ──
    try:
        pm = getattr(req.member, 'pre_member', None)
        email_addr = (pm.email if pm else None) or getattr(req.member.user, 'email', None)
        if email_addr:
            send_gcash_verified_email(
                email=email_addr, fullname=req.member.fullname,
                member_id=req.member.member_id, loan_id=loan.loan_id,
                reference_number=req.reference_number,
                amount=float(amount), new_balance=float(new_balance),
            )
    except Exception as e:
        print(f"[EMAIL ERROR] GCash verified email failed: {e}")

    # ── In-app notification ──
    try:
        from notifications.models import Notification
        Notification.objects.create(
            user       = req.member.user,
            title      = "GCash Payment Verified ✅",
            message    = f"Your GCash payment of ₱{float(amount):,.2f} for loan {loan.loan_id} (Ref: {req.reference_number}) has been verified and recorded. New balance: ₱{float(new_balance):,.2f}.",
            notif_type = "payment",
        )
    except Exception as e:
        print(f"[NOTIF ERROR] {e}")

    return Response({
        'message':    f'Payment of ₱{float(amount):,.2f} verified and recorded.',
        'tx_id':      tx_id,
        'new_balance':float(new_balance),
        'loan_status':loan.status,
        'status':     'Verified',
    })