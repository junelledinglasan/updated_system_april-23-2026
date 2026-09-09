# backend/settings_app/views.py

from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from django.contrib.auth import get_user_model
from .models import SystemSettings, StaffFeaturePermission, AVAILABLE_FEATURES, get_default_features, GCashAccount
from .serializers import SystemSettingsSerializer, StaffFeaturePermissionSerializer, GCashAccountSerializer

User = get_user_model()


@api_view(['GET'])
@permission_classes([AllowAny])
def system_logo_view(request):
    """Kunin ang kasalukuyang custom logo (kung meron). PUBLIC — hindi
    kailangan ng login dito, dahil kailangan din ito ng Landing Page
    (bago pa mag-login) at ng Login page mismo, hindi lang ng mga
    naka-login na Admin/Staff/Member layouts."""
    settings_obj = SystemSettings.get_solo()
    serializer = SystemSettingsSerializer(settings_obj, context={'request': request})
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def upload_system_logo_view(request):
    """I-upload/palitan ang logo — ADMIN ONLY."""
    if request.user.role != 'admin':
        return Response({'error': 'Unauthorized. Admin access only.'}, status=403)

    if 'logo' not in request.FILES:
        return Response({'error': 'No logo file provided.'}, status=400)

    settings_obj = SystemSettings.get_solo()
    settings_obj.logo = request.FILES['logo']
    settings_obj.updated_by = request.user
    settings_obj.save()

    serializer = SystemSettingsSerializer(settings_obj, context={'request': request})
    return Response(serializer.data, status=200)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def reset_system_logo_view(request):
    """Ibalik sa default logo (alisin ang custom upload) — ADMIN ONLY."""
    if request.user.role != 'admin':
        return Response({'error': 'Unauthorized. Admin access only.'}, status=403)

    settings_obj = SystemSettings.get_solo()
    if settings_obj.logo:
        settings_obj.logo.delete(save=False)
    settings_obj.logo = None
    settings_obj.updated_by = request.user
    settings_obj.save()

    return Response({'message': 'Logo reset to default.'}, status=200)


# ══════════════════════════════════════════════════════════════════
#  BAGO: GCASH PAYMENT NUMBER/NAME — dating hardcoded sa
#  GCashPayment.jsx (GCASH_NUMBER / GCASH_NAME constants), ngayon
#  nasa database na para ma-edit ng admin sa Settings nang hindi na
#  kailangang galawin ang code.
# ══════════════════════════════════════════════════════════════════

@api_view(['GET', 'PATCH'])
@permission_classes([IsAuthenticated])
def gcash_settings_view(request):
    """GET — kunin ang kasalukuyang GCash number/account name.
    Naka-IsAuthenticated lang (hindi AllowAny tulad ng logo), dahil
    ginagamit lang ito sa loob ng "Pay via GCash" modal ng member
    (naka-login na siya doon) — hindi kailangan pre-login/public.
    PATCH — i-update — ADMIN ONLY."""
    settings_obj = SystemSettings.get_solo()

    if request.method == 'GET':
        return Response({
            'gcash_number': settings_obj.gcash_number,
            'gcash_name':   settings_obj.gcash_name,
        })

    # PATCH — ADMIN ONLY
    if request.user.role != 'admin':
        return Response({'error': 'Unauthorized. Admin access only.'}, status=403)

    number = request.data.get('gcash_number', '').strip()
    name   = request.data.get('gcash_name', '').strip()

    if not number:
        return Response({'error': 'GCash number is required.'}, status=400)
    if not name:
        return Response({'error': 'Account name is required.'}, status=400)

    settings_obj.gcash_number = number
    settings_obj.gcash_name   = name
    settings_obj.updated_by   = request.user
    settings_obj.save()

    return Response({
        'gcash_number': settings_obj.gcash_number,
        'gcash_name':   settings_obj.gcash_name,
    }, status=200)


# ══════════════════════════════════════════════════════════════════
#  BAGO: MARAMING GCASH ACCOUNT — dating iisang number/name lang
#  (tingnan ang "gcash_settings_view" sa itaas, na iniwan pa rin para
#  sa backward compatibility). Ito na ang PANGUNAHING gagamitin ng
#  bagong "Pay via GCash" flow — puwede nang magdagdag ang admin ng
#  ILAN pang account, at pipiliin ng member kung saan magbabayad.
# ══════════════════════════════════════════════════════════════════

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def gcash_accounts_list_view(request):
    """GET — listahan ng LAHAT ng GCash accounts (aktibo man o hindi)
    — para sa Settings management table, ADMIN lang makakakita nito.
    POST — magdagdag ng bagong account — ADMIN ONLY."""
    GCashAccount.ensure_default()

    if request.method == 'GET':
        if request.user.role != 'admin':
            return Response({'error': 'Unauthorized. Admin access only.'}, status=403)
        accounts = GCashAccount.objects.all()
        return Response(GCashAccountSerializer(accounts, many=True).data)

    # POST — ADMIN ONLY
    if request.user.role != 'admin':
        return Response({'error': 'Unauthorized. Admin access only.'}, status=403)

    number = request.data.get('number', '').strip()
    name   = request.data.get('account_name', '').strip()
    label  = request.data.get('label', '').strip()

    if not number:
        return Response({'error': 'GCash number is required.'}, status=400)
    if not name:
        return Response({'error': 'Account name is required.'}, status=400)

    account = GCashAccount.objects.create(
        label=label, number=number, account_name=name,
        is_active=True, updated_by=request.user,
    )
    return Response(GCashAccountSerializer(account).data, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def gcash_accounts_active_view(request):
    """Ibalik lang ang mga AKTIBONG GCash accounts — ito ang tinatawag
    ng member sa "Pay via GCash" modal, para makapagpakita ng listahan
    ng mga puwedeng piliin. Kahit sinong naka-login (member man o
    staff) ay puwedeng tumawag dito."""
    GCashAccount.ensure_default()
    accounts = GCashAccount.objects.filter(is_active=True)
    return Response(GCashAccountSerializer(accounts, many=True).data)


@api_view(['PATCH', 'DELETE'])
@permission_classes([IsAuthenticated])
def gcash_account_detail_view(request, pk):
    """PATCH — i-edit ang isang account (kasama ang pag-toggle ng
    is_active). DELETE — permanenteng burahin. ADMIN ONLY sa pareho."""
    if request.user.role != 'admin':
        return Response({'error': 'Unauthorized. Admin access only.'}, status=403)

    try:
        account = GCashAccount.objects.get(pk=pk)
    except GCashAccount.DoesNotExist:
        return Response({'error': 'GCash account not found.'}, status=404)

    if request.method == 'DELETE':
        account.delete()
        return Response(status=204)

    # PATCH
    if 'number' in request.data:
        number = request.data.get('number', '').strip()
        if not number:
            return Response({'error': 'GCash number is required.'}, status=400)
        account.number = number
    if 'account_name' in request.data:
        name = request.data.get('account_name', '').strip()
        if not name:
            return Response({'error': 'Account name is required.'}, status=400)
        account.account_name = name
    if 'label' in request.data:
        account.label = request.data.get('label', '').strip()
    if 'is_active' in request.data:
        account.is_active = bool(request.data.get('is_active'))

    account.updated_by = request.user
    account.save()
    return Response(GCashAccountSerializer(account).data, status=200)


# ══════════════════════════════════════════════════════════════════
#  STAFF FEATURE PERMISSIONS
# ══════════════════════════════════════════════════════════════════

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def available_features_view(request):
    """Ibalik ang buong listahan ng mga "features" na pwedeng i-toggle
    — ginagamit ng frontend para malaman anong checkboxes ilalagay."""
    return Response([{'key': k, 'label': l} for k, l in AVAILABLE_FEATURES])


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def staff_permissions_list_view(request):
    """Listahan ng LAHAT ng staff accounts + kanilang kasalukuyang
    permissions — ADMIN ONLY, para sa Settings UI table."""
    if request.user.role != 'admin':
        return Response({'error': 'Unauthorized. Admin access only.'}, status=403)

    staff_users = User.objects.filter(role='staff').order_by('name')
    results = []
    for staff in staff_users:
        perm, _ = StaffFeaturePermission.objects.get_or_create(staff=staff, defaults={'features': get_default_features(staff)})
        results.append(StaffFeaturePermissionSerializer(perm).data)
    return Response(results)


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def staff_permissions_detail_view(request, staff_id):
    """GET — kunin ang permissions ng isang staff (pwedeng tawagin
    ng staff mismo, para malaman anong features makikita niya).
    POST — i-update ang permissions ng isang staff — ADMIN ONLY."""
    try:
        staff = User.objects.get(pk=staff_id, role='staff')
    except User.DoesNotExist:
        return Response({'error': 'Staff not found.'}, status=404)

    if request.method == 'GET':
        # Payagan ang admin (kahit kaninong staff), AT ang staff mismo
        # na tumitingin ng sarili niyang permissions.
        if request.user.role != 'admin' and request.user.id != staff.id:
            return Response({'error': 'Unauthorized.'}, status=403)
        perm, _ = StaffFeaturePermission.objects.get_or_create(staff=staff, defaults={'features': get_default_features(staff)})
        return Response(StaffFeaturePermissionSerializer(perm).data)

    # POST — ADMIN ONLY
    if request.user.role != 'admin':
        return Response({'error': 'Unauthorized. Admin access only.'}, status=403)

    features = request.data.get('features', [])
    if not isinstance(features, list):
        return Response({'error': 'features must be a list.'}, status=400)

    valid_keys = {k for k, _ in AVAILABLE_FEATURES}
    features = [f for f in features if f in valid_keys]

    perm, _ = StaffFeaturePermission.objects.get_or_create(staff=staff, defaults={'features': get_default_features(staff)})
    perm.features = features
    perm.save()

    return Response(StaffFeaturePermissionSerializer(perm).data, status=200)