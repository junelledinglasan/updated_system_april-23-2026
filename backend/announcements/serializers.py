from rest_framework import serializers
from .models import Announcement, AnnouncementComment, AnnouncementReaction


class CommentSerializer(serializers.ModelSerializer):
    posted_by_name = serializers.ReadOnlyField()
    posted_by_role = serializers.ReadOnlyField()

    class Meta:
        model  = AnnouncementComment
        fields = ['id', 'body', 'posted_by_name', 'posted_by_role', 'created_at']


# ── BAGO: Reaction serializer ───────────────────────────────────────────────
class ReactionSerializer(serializers.ModelSerializer):
    posted_by_name = serializers.CharField(source='user.name', read_only=True)

    class Meta:
        model  = AnnouncementReaction
        fields = ['id', 'reaction_type', 'posted_by_name', 'created_at']


class AnnouncementSerializer(serializers.ModelSerializer):
    posted_by_name  = serializers.ReadOnlyField()
    posted_by_role  = serializers.ReadOnlyField()
    comments        = CommentSerializer(many=True, read_only=True)
    comment_count   = serializers.SerializerMethodField()
    image_url       = serializers.SerializerMethodField()
    # ── BAGO: reaction fields ──
    reactions       = ReactionSerializer(many=True, read_only=True)  # buong listahan — para makita kung sino nag-react
    reaction_counts = serializers.SerializerMethodField()
    total_reactions = serializers.SerializerMethodField()
    my_reaction     = serializers.SerializerMethodField()

    class Meta:
        model  = Announcement
        fields = [
            'id', 'title', 'body', 'type', 'image', 'image_url',
            'pinned', 'is_active', 'posted_by_name', 'posted_by_role',
            'created_at', 'updated_at', 'comments', 'comment_count',
            'reactions', 'reaction_counts', 'total_reactions', 'my_reaction',
        ]
        extra_kwargs = {
            'image':     {'required': False},
            'is_active': {'required': False, 'default': True},
            'pinned':    {'required': False, 'default': False},
        }

    def get_comment_count(self, obj):
        return obj.comments.count()

    def get_image_url(self, obj):
        if not obj.image:
            return None
        request = self.context.get('request')
        if request:
            return request.build_absolute_uri(obj.image.url)
        from django.conf import settings
        return f"{settings.MEDIA_URL}{obj.image.name}"

    # ── BAGO: reaction_counts — hal. {"Like": 3, "Love": 1} ──
    def get_reaction_counts(self, obj):
        counts = {}
        for r in obj.reactions.all():
            counts[r.reaction_type] = counts.get(r.reaction_type, 0) + 1
        return counts

    def get_total_reactions(self, obj):
        return obj.reactions.count()

    # ── BAGO: my_reaction — anong reaction ang ginawa ng kasalukuyang
    # naka-login na user sa post na 'to (o None kung wala pa) ──
    def get_my_reaction(self, obj):
        request = self.context.get('request')
        if not request or not getattr(request, 'user', None) or not request.user.is_authenticated:
            return None
        r = obj.reactions.filter(user=request.user).first()
        return r.reaction_type if r else None

    def to_internal_value(self, data):
        # Fix: FormData sends "true"/"false" as strings — convert to bool
        mutable = data.copy() if hasattr(data, 'copy') else dict(data)
        if 'pinned' in mutable:
            val = mutable['pinned']
            mutable['pinned'] = val in [True, 'true', 'True', '1', 1]
        if 'is_active' in mutable:
            val = mutable['is_active']
            mutable['is_active'] = val in [True, 'true', 'True', '1', 1]
        return super().to_internal_value(mutable)