from rest_framework import serializers
from .models import LeafMemberInfo, Member, StudentProfile, SeniorProfile, JobProfile, Savings


class StudentProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model  = StudentProfile
        fields = ['id', 'school_name', 'year_level', 'allowance']


class SeniorProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model  = SeniorProfile
        fields = ['id', 'educational_attainment', 'pension_income']


class JobProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model  = JobProfile
        fields = ['id', 'occupation', 'job_type', 'monthly_income']


class LeafMemberInfoSerializer(serializers.ModelSerializer):
    fullname     = serializers.ReadOnlyField()
    is_converted = serializers.SerializerMethodField()

    class Meta:
        model  = LeafMemberInfo
        fields = '__all__'
        read_only_fields = ['app_id', 'created_at', 'reviewed_at', 'reviewed_by']

    def get_is_converted(self, obj):
        return hasattr(obj, 'converted_member')


class LeafMemberInfoListSerializer(serializers.ModelSerializer):
    fullname     = serializers.ReadOnlyField()
    is_converted = serializers.SerializerMethodField()

    class Meta:
        model  = LeafMemberInfo
        fields = [
            'id', 'app_id', 'first_name', 'last_name', 'middle_name',
            'fullname', 'birth_date', 'civil_status', 'educational_attainment',
            'occupation', 'income', 'contact_number', 'address',
            'classification', 'birth_certificate', 'marriage_certificate',
            'application_status', 'reject_reason', 'created_at', 'is_converted',
        ]

    def get_is_converted(self, obj):
        return hasattr(obj, 'converted_member')


class MemberSerializer(serializers.ModelSerializer):
    fullname        = serializers.ReadOnlyField()
    first_name      = serializers.ReadOnlyField()
    last_name       = serializers.ReadOnlyField()
    contact         = serializers.ReadOnlyField()
    email           = serializers.ReadOnlyField()
    status          = serializers.ReadOnlyField()
    classification  = serializers.ReadOnlyField()
    max_loanable    = serializers.ReadOnlyField()
    application_id  = serializers.ReadOnlyField()
    user_username   = serializers.SerializerMethodField()

    student_profile = StudentProfileSerializer(read_only=True)
    senior_profile  = SeniorProfileSerializer(read_only=True)
    job_profile     = JobProfileSerializer(read_only=True)
    pre_member_info = LeafMemberInfoSerializer(source='pre_member', read_only=True)

    class Meta:
        model  = Member
        fields = [
            'id', 'member_id', 'fullname', 'first_name', 'last_name',
            'contact', 'email', 'status', 'classification',
            'membership_status', 'membership_date', 'share_capital',
            # ── BAGO: writable — dito nagse-set ang admin ng 1x/2x/3x. ──
            'loan_multiplier',
            'max_loanable', 'application_id', 'plain_password',
            'student_profile', 'senior_profile', 'job_profile',
            'pre_member_info', 'user', 'pre_member', 'date_registered',
            'user_username',
        ]

    def get_user_username(self, obj):
        return obj.user.username if obj.user else None


class MemberListSerializer(serializers.ModelSerializer):
    fullname       = serializers.ReadOnlyField()
    first_name     = serializers.ReadOnlyField()
    last_name      = serializers.ReadOnlyField()
    contact        = serializers.ReadOnlyField()
    status         = serializers.ReadOnlyField()
    classification = serializers.ReadOnlyField()
    application_id = serializers.ReadOnlyField()
    # ── FIX: nawawala dati ang "max_loanable" dito — kaya sa mga
    # lugar na gumagamit ng LIST endpoint (hal. "New F2F Loan
    # Application" member selector), laging ₱0 ang lumalabas na Max
    # Loanable, kahit may Share Capital naman ang member. ─────────────
    max_loanable   = serializers.ReadOnlyField()
    birth_date     = serializers.SerializerMethodField()

    class Meta:
        model  = Member
        fields = [
            'id', 'member_id', 'fullname', 'first_name', 'last_name',
            'contact', 'share_capital',
            # ── BAGO ──
            'loan_multiplier', 'max_loanable',
            'status', 'membership_status',
            'classification', 'membership_date', 'application_id',
            'birth_date',
        ]

    def get_birth_date(self, obj):
        # ── Try pre_member first ──
        if obj.pre_member and obj.pre_member.birth_date:
            return str(obj.pre_member.birth_date)
        # ── Fallback: check leaf_members_info by user ──
        try:
            info = LeafMemberInfo.objects.filter(user=obj.user).first()
            if info and info.birth_date:
                return str(info.birth_date)
        except Exception:
            pass
        return None


class SavingsSerializer(serializers.ModelSerializer):
    member_name = serializers.CharField(source='member.fullname',  read_only=True)
    member_code = serializers.CharField(source='member.member_id', read_only=True)

    class Meta:
        model  = Savings
        fields = [
            'id', 'member', 'member_name', 'member_code',
            'transaction_type', 'amount', 'balance_after',
            'note', 'recorded_by', 'created_at',
        ]
        read_only_fields = ['balance_after', 'recorded_by', 'created_at']