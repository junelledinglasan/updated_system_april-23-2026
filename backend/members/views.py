import random, string
from django.utils import timezone
from django.db.models import Sum, Prefetch
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from notifications.email_utils import (
    send_member_approved_email,
    send_loan_approved_email,
    send_application_approved_email,
)

from auth_app.models import User
from activity_log.utils import log_activity
from .models import LeafMemberInfo, Member, StudentProfile, SeniorProfile, JobProfile, Savings, OnlineApplication
from .serializers import (
    LeafMemberInfoSerializer, LeafMemberInfoListSerializer,
    MemberSerializer, MemberListSerializer,
    SavingsSerializer,
)


# ── Helpers ────────────────────────────────────────────────────────────────────
def gen_password():
    return 'leaf' + ''.join(random.choices(string.digits, k=4))


def gen_username(first_name, last_name):
    base  = f'{first_name.lower().strip()}.{last_name.lower().strip()}'
    uname = base
    i = 1
    while User.objects.filter(username=uname).exists():
        uname = f'{base}{i}'
        i    += 1
    return uname


def gen_member_id():
    existing = Member.objects.filter(
        member_id__startswith='LEAF-'
    ).values_list('member_id', flat=True)
    max_num = 0
    for mid in existing:
        try:
            num = int(mid.replace('LEAF-', ''))
            if num > max_num:
                max_num = num
        except ValueError:
            pass
    candidate = f'LEAF-{str(max_num + 1).zfill(3)}'
    while Member.objects.filter(member_id=candidate).exists():
        max_num += 1
        candidate = f'LEAF-{str(max_num + 1).zfill(3)}'
    return candidate


def save_sub_profile(member, classification, data):
    if classification == 'Student':
        StudentProfile.objects.update_or_create(
            member=member,
            defaults={
                'school_name': data.get('school_name', ''),
                'year_level':  data.get('year_level', ''),
                'allowance':   data.get('allowance', 0) or 0,
            }
        )
    elif classification == 'Senior':
        SeniorProfile.objects.update_or_create(
            member=member,
            defaults={
                'educational_attainment': data.get('educational_attainment', ''),
                'pension_income':         data.get('pension_income', 0) or 0,
            }
        )
    elif classification == 'Employed':
        JobProfile.objects.update_or_create(
            member=member,
            defaults={
                'occupation':     data.get('occupation', ''),
                'job_type':       data.get('job_type', 'Employed'),
                'monthly_income': data.get('monthly_income', 0) or 0,
            }
        )


# ── Helper to get username/password for online application ──
def get_app_credentials(app_id):
    """Get username and plain_password from leaf_members_info → members."""
    try:
        lmi = LeafMemberInfo.objects.select_related('user').get(app_id=app_id)
        if lmi.user:
            try:
                member = Member.objects.get(user=lmi.user)
                return lmi.user.username, member.plain_password
            except Member.DoesNotExist:
                return lmi.user.username, ''
    except LeafMemberInfo.DoesNotExist:
        pass
    return '', ''


# ══════════════════════════════════════════════════════════════════
# APPLICATIONS — leaf_members_info
# ══════════════════════════════════════════════════════════════════

@api_view(['GET', 'POST'])
def application_list_view(request):
    if request.method == 'GET':
        if not request.user.is_authenticated:
            return Response({'error': 'Authentication required.'}, status=401)
        if request.user.role not in ['admin', 'staff']:
            return Response({'error': 'Unauthorized.'}, status=403)

        apps = LeafMemberInfo.objects.filter(is_f2f=False)
        if s := request.query_params.get('status'):
            apps = apps.filter(application_status=s)
        if q := request.query_params.get('search', '').strip():
            apps = apps.filter(last_name__icontains=q)  | \
                   apps.filter(first_name__icontains=q)  | \
                   apps.filter(app_id__icontains=q)
        return Response(LeafMemberInfoListSerializer(apps, many=True).data)

    user = request.user if request.user.is_authenticated else None
    s    = LeafMemberInfoSerializer(data=request.data)
    if s.is_valid():
        info = s.save(user=user)
        log_activity('application', f'New application from {info.fullname} ({info.app_id})', user)
        return Response(LeafMemberInfoSerializer(info).data, status=201)
    return Response(s.errors, status=400)


@api_view(['GET', 'PATCH'])
@permission_classes([IsAuthenticated])
def application_detail_view(request, pk):
    try:
        app = LeafMemberInfo.objects.get(pk=pk)
    except LeafMemberInfo.DoesNotExist:
        return Response({'error': 'Not found.'}, status=404)

    if request.method == 'GET':
        return Response(LeafMemberInfoSerializer(app).data)

    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)

    new_status = request.data.get('status') or request.data.get('application_status')
    if new_status in ['Approved', 'Rejected']:
        app.application_status = new_status
        app.reviewed_at        = timezone.now()
        app.reviewed_by        = request.user.username
        if new_status == 'Rejected':
            app.reject_reason = request.data.get('reject_reason', '')
        app.save()
        log_activity('application',
            f'Application {app.app_id} ({app.fullname}) {new_status.lower()} by {request.user.name}',
            request.user)
    return Response(LeafMemberInfoSerializer(app).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_application_view(request):
    try:
        app = LeafMemberInfo.objects.get(user=request.user)
        return Response(LeafMemberInfoSerializer(app).data)
    except LeafMemberInfo.DoesNotExist:
        return Response({'error': 'No application found.'}, status=404)


# ══════════════════════════════════════════════════════════════════
# CONVERT APPLICATION → OFFICIAL MEMBER
# ══════════════════════════════════════════════════════════════════

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def convert_to_member_view(request, pk):
    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)

    try:
        info = LeafMemberInfo.objects.get(pk=pk)
    except LeafMemberInfo.DoesNotExist:
        return Response({'error': 'Application not found.'}, status=404)

    if info.application_status != 'Approved':
        return Response({'error': 'Application must be Approved first.'}, status=400)

    if Member.objects.filter(pre_member=info).exists():
        existing = Member.objects.get(pre_member=info)
        return Response({
            'error':     'Already converted to official member.',
            'member_id': existing.member_id,
        }, status=400)

    user     = info.user
    plain_pw = gen_password()

    if not user:
        uname = gen_username(info.first_name, info.last_name)
        user  = User.objects.create_user(
            username=uname, password=plain_pw,
            name=info.fullname, role='member',
        )
        info.user = user
        info.save()
    else:
        user.role      = 'member'
        user.name      = info.fullname
        user.is_active = True
        user.set_password(plain_pw)
        user.save()

    paid_amount   = float(request.data.get('share_capital', 0) or 0)
    share_capital = paid_amount * 2

    try:
        member = Member.objects.create(
            user              = user,
            pre_member        = info,
            membership_status = 'Active',
            plain_password    = plain_pw,
            share_capital     = share_capital,
        )
    except Exception as e:
        return Response({'error': f'Failed to create member: {str(e)}'}, status=500)

    save_sub_profile(member, info.classification, request.data)

    log_activity('member',
        f'Member converted: {member.fullname} ({member.member_id}) from {info.app_id} '
        f'— Paid: ₱{paid_amount:,.2f} → Share Capital: ₱{share_capital:,.2f}',
        request.user)

    return Response({
        'message':       f'{member.fullname} is now an official member!',
        'member_id':     member.member_id,
        'username':      user.username,
        'password':      plain_pw,
        'share_capital': share_capital,
        'member':        MemberSerializer(member).data,
    }, status=201)


# ══════════════════════════════════════════════════════════════════
# OFFICIAL MEMBERS — F2F Walk-in Registration
# ══════════════════════════════════════════════════════════════════

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def member_list_view(request):
    if request.method == 'GET':
        members = Member.objects.select_related('user', 'pre_member').all()
        if s := request.query_params.get('status'):
            members = members.filter(membership_status=s)
        if q := request.query_params.get('search', '').strip():
            members = members.filter(pre_member__last_name__icontains=q)  | \
                      members.filter(pre_member__first_name__icontains=q) | \
                      members.filter(member_id__icontains=q)
        return Response(MemberListSerializer(members, many=True).data)

    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)

    data     = request.data
    plain_pw = gen_password()
    fname    = data.get('first_name', data.get('firstname', ''))
    lname    = data.get('last_name',  data.get('lastname',  ''))
    uname    = gen_username(fname, lname)

    user = User.objects.create_user(
        username=uname, password=plain_pw,
        name=f'{fname} {lname}'.strip(),
        role='member', is_active=True,
    )

    try:
        info = LeafMemberInfo.objects.create(
            user                   = user,
            first_name             = fname,
            last_name              = lname,
            middle_name            = data.get('middle_name', data.get('middlename', '')),
            birth_date             = data.get('birth_date',  data.get('birthdate')) or None,
            civil_status           = data.get('civil_status', 'Single'),
            educational_attainment = data.get('educational_attainment', ''),
            occupation             = data.get('occupation', ''),
            income                 = data.get('income', 0) or 0,
            contact_number         = data.get('contact_number', data.get('contact', '')),
            email                  = data.get('email', ''),
            address                = data.get('address', ''),
            classification         = data.get('classification', 'Employed'),
            birth_certificate      = data.get('birth_certificate', False),
            marriage_certificate   = data.get('marriage_certificate', False),
            application_status     = 'Approved',
            is_f2f                 = True,
        )
    except Exception as e:
        user.delete()
        return Response({'error': f'Failed to create info: {str(e)}'}, status=500)

    paid_amount   = float(data.get('share_capital', 0) or 0)
    share_capital = paid_amount * 2

    try:
        member = Member.objects.create(
            user              = user,
            pre_member        = info,
            membership_status = 'Active',
            plain_password    = plain_pw,
            share_capital     = share_capital,
        )
    except Exception as e:
        info.delete(); user.delete()
        return Response({'error': f'Failed to create member: {str(e)}'}, status=500)

    save_sub_profile(member, data.get('classification', 'Employed'), data)

    log_activity('member',
        f'New F2F member: {member.fullname} ({member.member_id}) by {request.user.name} '
        f'— Paid: ₱{paid_amount:,.2f} → Share Capital: ₱{share_capital:,.2f}',
        request.user)

    return Response({
        'message':        f'{member.fullname} is now an official member!',
        'member_id':      member.member_id,
        'username':       uname,
        'plain_password': plain_pw,
        'share_capital':  share_capital,
        'member':         MemberSerializer(member).data,
    }, status=201)


@api_view(['GET', 'PUT', 'DELETE'])
@permission_classes([IsAuthenticated])
def member_detail_view(request, pk):
    try:
        member = Member.objects.select_related('user', 'pre_member').get(pk=pk)
    except Member.DoesNotExist:
        return Response({'error': 'Not found.'}, status=404)

    if request.method == 'GET':
        return Response(MemberSerializer(member).data)

    if request.method == 'PUT':
        if request.user.role not in ['admin', 'staff']:
            return Response({'error': 'Unauthorized.'}, status=403)
        data = request.data

        if member.pre_member:
            info = member.pre_member
            for field in [
                'first_name', 'last_name', 'middle_name', 'birth_date',
                'civil_status', 'educational_attainment', 'occupation',
                'income', 'contact_number', 'email', 'address',
                'birth_certificate', 'marriage_certificate',
            ]:
                if field in data:
                    setattr(info, field, data[field])
            info.save()

        if new_pw := data.get('plain_password', ''):
            member.user.set_password(new_pw)
            member.user.save()
            member.plain_password = new_pw

        if ms := data.get('membership_status', data.get('status', '')):
            member.membership_status = ms
        if sc := data.get('share_capital'):
            member.share_capital = sc

        member.save()

        if member.pre_member:
            save_sub_profile(member, member.pre_member.classification, data)

        log_activity('member', f'Member updated: {member.fullname} ({member.member_id})', request.user)
        return Response(MemberSerializer(member).data)

    if request.method == 'DELETE':
        if request.user.role != 'admin':
            return Response({'error': 'Unauthorized.'}, status=403)
        name     = member.fullname
        mid      = member.member_id
        user     = member.user
        pre      = member.pre_member
        member.delete()
        if pre:
            pre.delete()
        # ── Delete online_applications record too para hindi bumalik sa Pending ──
        if user:
            OnlineApplication.objects.filter(user=user).delete()
            user.delete()
        # ── Also delete via pre_member app_id (for NULL user_id cases) ──
        if pre and pre.app_id:
            OnlineApplication.objects.filter(app_id=pre.app_id).delete()
        log_activity('member', f'Member deleted: {name} ({mid})', request.user)
        return Response({'message': 'Member deleted.'})


@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def member_status_view(request, pk):
    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)
    try:
        member = Member.objects.get(pk=pk)
    except Member.DoesNotExist:
        return Response({'error': 'Not found.'}, status=404)

    st = request.data.get('status') or request.data.get('membership_status')
    if st:
        old = member.membership_status
        member.membership_status = st
        member.save()
        log_activity('member', f'Member status: {member.fullname} {old} → {st}', request.user)
    return Response(MemberSerializer(member).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def member_stats_view(request):
    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)
    return Response({
        'total':                 Member.objects.count(),
        'active':                Member.objects.filter(membership_status='Active').count(),
        'inactive':              Member.objects.filter(membership_status='Inactive').count(),
        'suspended':             Member.objects.filter(membership_status='Suspended').count(),
        'deactivated':           Member.objects.filter(membership_status='Deactivated').count(),
        'pending_applications':  LeafMemberInfo.objects.filter(application_status='Pending').count(),
        'approved_applications': LeafMemberInfo.objects.filter(application_status='Approved').count(),
        'total_applications':    LeafMemberInfo.objects.count(),
        'students':              Member.objects.filter(pre_member__classification='Student').count(),
        'seniors':               Member.objects.filter(pre_member__classification='Senior').count(),
        'employed':              Member.objects.filter(pre_member__classification='Employed').count(),
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_profile_view(request):
    try:
        member = Member.objects.select_related(
            'pre_member', 'student_profile', 'senior_profile', 'job_profile'
        ).get(user=request.user)
        data = MemberSerializer(member).data

        # ── Include sub-profile income data for recommendation engine ──
        sp = getattr(member, 'student_profile', None)
        sr = getattr(member, 'senior_profile',  None)
        jp = getattr(member, 'job_profile',      None)

        data['student_profile'] = {
            'allowance': float(sp.allowance) if sp else 0,
            'school_name': sp.school_name if sp else '',
            'year_level':  sp.year_level  if sp else '',
        } if sp else None
        data['senior_profile'] = {
            'pension_income': float(sr.pension_income) if sr else 0,
        } if sr else None
        data['job_profile'] = {
            'monthly_income': float(jp.monthly_income) if jp else 0,
            'job_type':       jp.job_type   if jp else '',
            'occupation':     jp.occupation if jp else '',
        } if jp else None

        return Response(data)
    except Member.DoesNotExist:
        return Response({'error': 'Not an official member yet.'}, status=404)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def member_financial_summary_view(request, pk):
    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)
    try:
        member = Member.objects.get(pk=pk)
    except Member.DoesNotExist:
        return Response({'error': 'Not found.'}, status=404)

    from loans.models import Loan
    from payments.models import Payment

    loans = Loan.objects.filter(member=member).prefetch_related(
        Prefetch(
            'payments',
            queryset=Payment.objects.order_by('-paid_at'),
            to_attr='prefetched_payments'
        )
    ).order_by('-applied_at')

    active_loans = [l for l in loans if l.status in ['Active', 'Overdue']]

    total_paid = Payment.objects.filter(member=member).aggregate(
        t=Sum('amount')
    )['t'] or 0

    share_capital = float(member.share_capital or 0)
    amount_paid   = share_capital / 2

    return Response({
        'share_capital':     share_capital,
        'amount_paid':       amount_paid,
        'max_loanable':      share_capital * 2,
        'total_loans':       len(loans),
        'active_loans':      len(active_loans),
        'total_loan_amount': sum(float(l.amount)  for l in active_loans),
        'total_balance':     sum(float(l.balance) for l in active_loans),
        'total_paid':        float(total_paid),
        'loans': [
            {
                'loan_id':     l.loan_id,
                'loan_type':   l.loan_type,
                'amount':      float(l.amount),
                'balance':     float(l.balance),
                'monthly_due': float(l.monthly_due),
                'status':      l.status,
                'applied_at':  str(l.applied_at)[:10],
                'payments': [
                    {
                        'tx_id':       p.tx_id,
                        'amount':      float(p.amount),
                        'balance':     float(p.balance),
                        'paid_at':     p.paid_at.strftime('%Y-%m-%d %H:%M'),
                        'recorded_by': p.recorded_by,
                        'note':        p.note or '—',
                    }
                    for p in getattr(l, 'prefetched_payments', [])
                ],
            }
            for l in loans
        ]
    })


# ══════════════════════════════════════════════════════════════════
# SAVINGS — Deposit & Withdraw
# ══════════════════════════════════════════════════════════════════

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def savings_list_view(request):
    if request.method == 'GET':
        member_id = request.query_params.get('member')
        savings = Savings.objects.select_related('member').order_by('-created_at')
        if member_id:
            savings = savings.filter(member_id=member_id)
        elif request.user.role == 'member':
            savings = savings.filter(member__user=request.user)

        # ── Limit for history tab — max 200 latest records ──
        limit = request.query_params.get('limit')
        if limit:
            try:
                savings = savings[:int(limit)]
            except (ValueError, TypeError):
                savings = savings[:200]
        
        return Response(SavingsSerializer(savings, many=True).data)

    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)

    member_id        = request.data.get('member')
    transaction_type = request.data.get('transaction_type')
    amount           = float(request.data.get('amount', 0))
    note             = request.data.get('note', '')

    if not member_id or not transaction_type or amount <= 0:
        return Response({'error': 'member, transaction_type, and amount are required.'}, status=400)

    try:
        member = Member.objects.get(id=member_id)
    except Member.DoesNotExist:
        return Response({'error': 'Member not found.'}, status=404)

    total_deposit   = Savings.objects.filter(member=member, transaction_type='Deposit').aggregate(t=Sum('amount'))['t'] or 0
    total_withdraw  = Savings.objects.filter(member=member, transaction_type='Withdraw').aggregate(t=Sum('amount'))['t'] or 0
    current_balance = float(total_deposit) - float(total_withdraw)

    if transaction_type == 'Withdraw':
        if amount > current_balance:
            return Response({'error': f'Insufficient balance. Current balance: ₱{current_balance:,.2f}'}, status=400)
        new_balance = current_balance - amount
    else:
        new_balance = current_balance + amount

    savings_tx = Savings.objects.create(
        member           = member,
        transaction_type = transaction_type,
        amount           = amount,
        balance_after    = new_balance,
        note             = note,
        recorded_by      = request.user.username,
    )

    log_activity(
        'savings',
        f'{transaction_type} ₱{amount:,.2f} for {member.fullname} ({member.member_id}) '
        f'— Balance: ₱{new_balance:,.2f} — by {request.user.name}',
        request.user
    )

    return Response(SavingsSerializer(savings_tx).data, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def member_savings_summary_view(request, pk):
    try:
        member = Member.objects.get(pk=pk)
    except Member.DoesNotExist:
        return Response({'error': 'Member not found.'}, status=404)

    savings = Savings.objects.filter(member=member)

    total_deposit  = savings.filter(transaction_type='Deposit').aggregate(t=Sum('amount'))['t'] or 0
    total_withdraw = savings.filter(transaction_type='Withdraw').aggregate(t=Sum('amount'))['t'] or 0
    balance        = float(total_deposit) - float(total_withdraw)

    return Response({
        'balance':        balance,
        'total_deposit':  float(total_deposit),
        'total_withdraw': float(total_withdraw),
        'transactions':   SavingsSerializer(savings, many=True).data,
    })


# ══════════════════════════════════════════════════════════════════
# ONLINE APPLICATIONS — separate table
# ══════════════════════════════════════════════════════════════════

@api_view(['GET', 'POST'])
def online_application_list_view(request):
    if request.method == 'GET':
        if not request.user.is_authenticated:
            return Response({'error': 'Authentication required.'}, status=401)
        if request.user.role not in ['admin', 'staff']:
            return Response({'error': 'Unauthorized.'}, status=403)

        apps = OnlineApplication.objects.all()
        if s := request.query_params.get('status'):
            apps = apps.filter(application_status=s)
            # ── For Approved: exclude apps where user is already an official member ──
            if s == 'Approved':
                converted_user_ids = Member.objects.values_list('user_id', flat=True)
                apps = apps.exclude(user_id__in=converted_user_ids)
        if q := request.query_params.get('search', '').strip():
            apps = apps.filter(last_name__icontains=q)  | \
                   apps.filter(first_name__icontains=q)  | \
                   apps.filter(app_id__icontains=q)

        def get_credentials(a):
            """Get username/password — use plain_password from online_applications first."""
            username      = a.user.username if a.user else ''
            plain_password = a.plain_password or ''  # ── direct from online_applications table
            # Fallback: if approved and converted, get from members table
            if not plain_password and a.user:
                try:
                    m = Member.objects.get(user=a.user)
                    plain_password = m.plain_password
                except Member.DoesNotExist:
                    pass
            return username, plain_password

        result = []
        for a in apps:
            username, plain_password = get_credentials(a)
            result.append({
                'id':                     a.id,
                'app_id':                 a.app_id,
                'fullname':               a.fullname,
                'first_name':             a.first_name,
                'last_name':              a.last_name,
                'middle_name':            a.middle_name,
                'birth_date':             str(a.birth_date) if a.birth_date else '',
                'civil_status':           a.civil_status,
                'educational_attainment': a.educational_attainment,
                'occupation':             a.occupation,
                'income':                 str(a.income),
                'contact_number':         a.contact_number,
                'email':                  a.email,
                'address':                a.address,
                'classification':         a.classification,
                'birth_certificate':      a.birth_certificate,
                'marriage_certificate':   a.marriage_certificate,
                'id_front_url':           a.id_front_url or '',
                'id_back_url':            a.id_back_url  or '',
                'application_status':     a.application_status,
                'reviewed_at':            str(a.reviewed_at) if a.reviewed_at else '',
                'reviewed_by':            a.reviewed_by,
                'reject_reason':          a.reject_reason,
                'created_at':             str(a.created_at)[:10],
                'username':               username,
                'plain_password':         plain_password,
            })

        return Response(result)

    # POST — submit new online application
    user = request.user if request.user.is_authenticated else None
    data = request.data

    if user and OnlineApplication.objects.filter(user=user).exists():
        existing = OnlineApplication.objects.get(user=user)
        # ── Allow resubmit only if Rejected ──
        if existing.application_status == 'Rejected':
            existing.delete()  # delete rejected app, allow new submission
        else:
            return Response({'error': 'You already have a pending application.'}, status=400)

    try:
        app = OnlineApplication.objects.create(
            user                   = user,
            first_name             = data.get('first_name', ''),
            last_name              = data.get('last_name', ''),
            middle_name            = data.get('middle_name', ''),
            birth_date             = data.get('birth_date') or None,
            civil_status           = data.get('civil_status', 'Single'),
            educational_attainment = data.get('educational_attainment', ''),
            occupation             = data.get('occupation', ''),
            income                 = data.get('income', 0) or 0,
            contact_number         = data.get('contact_number', ''),
            email                  = data.get('email', ''),
            address                = data.get('address', ''),
            classification         = data.get('classification', 'Employed'),
            birth_certificate      = data.get('birth_certificate', False),
            marriage_certificate   = data.get('marriage_certificate', False),
            id_front_url           = data.get('id_front_url', ''),
            id_back_url            = data.get('id_back_url', ''),
        )
        log_activity('application', f'New online application: {app.fullname} ({app.app_id})', user)
        return Response({'app_id': app.app_id, 'message': 'Application submitted.'}, status=201)
    except Exception as e:
        return Response({'error': str(e)}, status=400)


@api_view(['GET', 'PATCH'])
@permission_classes([IsAuthenticated])
def online_application_detail_view(request, pk):
    try:
        app = OnlineApplication.objects.get(pk=pk)
    except OnlineApplication.DoesNotExist:
        return Response({'error': 'Not found.'}, status=404)

    if request.method == 'GET':
        # ── Get credentials ──
        username       = app.user.username if app.user else ''
        plain_password = app.plain_password or ''  # ── direct from online_applications
        if not plain_password and app.user:
            try:
                m = Member.objects.get(user=app.user)
                plain_password = m.plain_password
            except Member.DoesNotExist:
                pass

        return Response({
            'id':                     app.id,
            'app_id':                 app.app_id,
            'fullname':               app.fullname,
            'first_name':             app.first_name,
            'last_name':              app.last_name,
            'middle_name':            app.middle_name,
            'birth_date':             str(app.birth_date) if app.birth_date else '',
            'civil_status':           app.civil_status,
            'educational_attainment': app.educational_attainment,
            'occupation':             app.occupation,
            'income':                 str(app.income),
            'contact_number':         app.contact_number,
            'email':                  app.email,
            'address':                app.address,
            'classification':         app.classification,
            'birth_certificate':      app.birth_certificate,
            'marriage_certificate':   app.marriage_certificate,
            'id_front_url':           app.id_front_url or '',
            'id_back_url':            app.id_back_url  or '',
            'application_status':     app.application_status,
            'reviewed_at':            str(app.reviewed_at) if app.reviewed_at else '',
            'reviewed_by':            app.reviewed_by,
            'reject_reason':          app.reject_reason,
            'created_at':             str(app.created_at)[:10],
            'username':               username,
            'plain_password':         plain_password,
        })

    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)

    new_status = request.data.get('status') or request.data.get('application_status')
    if new_status in ['Approved', 'Rejected']:
        app.application_status = new_status
        app.reviewed_at        = timezone.now()
        app.reviewed_by        = request.user.username
        if new_status == 'Rejected':
            app.reject_reason = request.data.get('reject_reason', '')
        app.save()
        log_activity('application',
            f'Online application {app.app_id} ({app.fullname}) {new_status.lower()} by {request.user.name}',
            request.user)

        # ── Send approval email with requirements ──
        if new_status == 'Approved':
            try:
                email_addr = app.email or (app.user.email if app.user else None)
                if email_addr:
                    send_application_approved_email(
                        email    = email_addr,
                        fullname = app.fullname,
                        app_id   = app.app_id,
                    )
            except Exception as e:
                print(f"[EMAIL ERROR] Application approved email failed: {e}")

    return Response({'application_status': app.application_status})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def convert_online_application_view(request, pk):
    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)

    try:
        online_app = OnlineApplication.objects.get(pk=pk)
    except OnlineApplication.DoesNotExist:
        return Response({'error': 'Not found.'}, status=404)

    if online_app.application_status != 'Approved':
        return Response({'error': 'Application must be Approved first.'}, status=400)

    if online_app.user and Member.objects.filter(user=online_app.user).exists():
        existing = Member.objects.get(user=online_app.user)
        return Response({'error': 'Already converted.', 'member_id': existing.member_id}, status=400)

    user     = online_app.user
    plain_pw = gen_password()

    user.role = 'member'
    user.set_password(plain_pw)
    user.save()

    info = LeafMemberInfo.objects.create(
        user                   = user,
        first_name             = online_app.first_name,
        last_name              = online_app.last_name,
        middle_name            = online_app.middle_name,
        birth_date             = online_app.birth_date,
        civil_status           = online_app.civil_status,
        educational_attainment = online_app.educational_attainment,
        occupation             = online_app.occupation,
        income                 = online_app.income,
        contact_number         = online_app.contact_number,
        email                  = online_app.email,
        address                = online_app.address,
        classification         = online_app.classification,
        birth_certificate      = online_app.birth_certificate,
        marriage_certificate   = online_app.marriage_certificate,
        application_status     = 'Approved',
        reviewed_by            = request.user.username,
        reviewed_at            = timezone.now(),
        is_f2f                 = False,
    )

    # ── Fixed: ₱4,000 paid → ₱8,000 share capital ──
    paid_amount   = float(request.data.get('share_capital', 4000) or 4000)
    share_capital = paid_amount * 2  # default ₱4,000 × 2 = ₱8,000

    member = Member.objects.create(
        user              = user,
        pre_member        = info,
        membership_status = 'Active',
        plain_password    = plain_pw,
        share_capital     = share_capital,
    )

    save_sub_profile(member, online_app.classification, request.data)

    # ── Hindi na nadi-delete — nananatili sa online_applications as Approved ──

    log_activity('member',
        f'Online applicant converted: {member.fullname} ({member.member_id})',
        request.user)

    # ── Send welcome email ────────────────────────────────────────────────────
    try:
        email_addr = online_app.email or getattr(user, 'email', None)
        if email_addr:
            send_member_approved_email(
                email          = email_addr,
                fullname       = member.fullname,
                member_id      = member.member_id,
                username       = user.username,
                plain_password = plain_pw,
                membership_date= member.membership_date.strftime('%B %d, %Y') if member.membership_date else str(timezone.now().date()),
            )
    except Exception as e:
        print(f"[EMAIL ERROR] Member approved email failed: {e}")

    return Response({
        'message':    f'{member.fullname} is now an official member!',
        'member_id':  member.member_id,
        'username':   user.username,
        'password':   plain_pw,
    }, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_online_application_view(request):
    try:
        app = OnlineApplication.objects.get(user=request.user)
        return Response({
            'app_id':             app.app_id,
            'application_status': app.application_status,
            'reject_reason':      app.reject_reason,
            'created_at':         str(app.created_at)[:10],
        })
    except OnlineApplication.DoesNotExist:
        return Response({'error': 'No application found.'}, status=404)

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def share_capital_deposit_view(request, pk):
    """Record a manual share capital deposit for a member / list transactions."""
    try:
        member = Member.objects.get(pk=pk)
    except Member.DoesNotExist:
        return Response({'error': 'Member not found.'}, status=404)
 
    if request.method == 'GET':
        # ── Payagan ang admin/staff (kahit kaninong member), AT ang
        # member mismo na tumitingin ng sarili niyang share capital
        # history — hindi tulad ng POST na admin/staff-only pa rin. ──
        is_owner = member.user_id == request.user.id
        if request.user.role not in ['admin', 'staff'] and not is_owner:
            return Response({'error': 'Unauthorized.'}, status=403)
 
        from .models import ShareCapitalTransaction
        txns = ShareCapitalTransaction.objects.filter(member=member).order_by('-created_at')[:100]
        return Response([{
            'id':           t.id,
            'txn_type':     t.txn_type,
            'amount':       float(t.amount),
            'balance_after':float(t.balance_after),
            'note':         t.note,
            'recorded_by':  t.recorded_by,
            'created_at':   t.created_at.strftime('%Y-%m-%d %H:%M'),
        } for t in txns])
 
    # POST — record deposit (ADMIN/STAFF ONLY — hindi ito nabago)
    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)
 
    amount = float(request.data.get('amount', 0))
    note   = request.data.get('note', 'Share capital deposit')
    txn_type = request.data.get('txn_type', 'Deposit')
 
    if amount <= 0:
        return Response({'error': 'Amount must be greater than 0.'}, status=400)
 
    # ── Update share capital ──
    from .models import ShareCapitalTransaction
    old_sc = float(member.share_capital)
    member.share_capital = old_sc + amount
    member.save()
 
    # ── Save transaction record ──
    ShareCapitalTransaction.objects.create(
        member       = member,
        txn_type     = txn_type,
        amount       = amount,
        balance_after= float(member.share_capital),
        note         = note,
        recorded_by  = request.user.username,
    )
 
    log_activity(
        'member',
        f'Share capital deposit: ₱{amount:,.2f} for {member.fullname} ({member.member_id}) '
        f'| SC: ₱{old_sc:,.2f} → ₱{float(member.share_capital):,.2f} by {request.user.username}',
        request.user
    )
 
    return Response({
        'message':       f'Share capital deposit of ₱{amount:,.2f} recorded.',
        'member_id':     member.member_id,
        'old_sc':        old_sc,
        'new_sc':        float(member.share_capital),
        'max_loanable':  float(member.share_capital) * 2,
    }, status=200)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def share_capital_history_view(request):
    """Return all share capital transactions — for history tab."""
    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)
    from .models import ShareCapitalTransaction
    txns = ShareCapitalTransaction.objects.select_related('member').order_by('-created_at')[:200]
    return Response([{
        'id':            t.id,
        'member_id':     t.member.member_id,
        'member_name':   t.member.fullname,
        'txn_type':      t.txn_type,
        'amount':        float(t.amount),
        'balance_after': float(t.balance_after),
        'note':          t.note,
        'recorded_by':   t.recorded_by,
        'created_at':    t.created_at.strftime('%Y-%m-%d %H:%M'),
    } for t in txns])



# ══════════════════════════════════════════════════════════════════
# DEACTIVATE MEMBER — Permanent, insurance covers active loans
# ══════════════════════════════════════════════════════════════════

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def deactivate_member_view(request, pk):
    if request.user.role not in ['admin']:
        return Response({'error': 'Only admin can deactivate members.'}, status=403)

    try:
        member = Member.objects.select_related('user').get(pk=pk)
    except Member.DoesNotExist:
        return Response({'error': 'Member not found.'}, status=404)

    if member.membership_status == 'Deactivated':
        return Response({'error': 'Member is already deactivated.'}, status=400)

    from loans.models import Loan
    from decimal import Decimal

    # ── Set all Active/Overdue loans to Completed with balance = 0 ──
    active_loans = Loan.objects.filter(
        member=member,
        status__in=['Active', 'Overdue']
    )
    loan_ids = []
    for loan in active_loans:
        loan.balance     = Decimal('0')
        loan.status      = 'Completed'
        loan.save()
        loan_ids.append(loan.loan_id)

    # ── Deactivate the member ──
    member.membership_status = 'Deactivated'
    member.save()

    # ── Disable login ──
    if member.user:
        member.user.is_active = False
        member.user.save()

    log_activity(
        'member',
        f'Member DEACTIVATED: {member.fullname} ({member.member_id}) by {request.user.username}'
        + (f' — Loans completed: {", ".join(loan_ids)}' if loan_ids else ''),
        request.user
    )

    return Response({
        'message':        f'{member.fullname} has been deactivated.',
        'member_id':      member.member_id,
        'loans_completed': loan_ids,
    })