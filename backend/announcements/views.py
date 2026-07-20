from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser

from activity_log.utils import log_activity
from .models import Announcement, AnnouncementComment, AnnouncementReaction
from .serializers import AnnouncementSerializer, CommentSerializer, ReactionSerializer
from rest_framework.permissions import IsAuthenticated, AllowAny


def serialize_ann(ann_or_qs, request, many=False):
    """Helper — always pass request so image_url/my_reaction become correct."""
    return AnnouncementSerializer(
        ann_or_qs, many=many, context={'request': request}
    ).data


@api_view(['GET', 'POST'])
@permission_classes([])          
@parser_classes([MultiPartParser, FormParser, JSONParser])
def announcement_list_view(request):
    if request.method == 'GET':
        anns = Announcement.objects.filter(is_active=True)
        if t := request.query_params.get('type'):
            anns = anns.filter(type=t)
        return Response(serialize_ann(anns, request, many=True))

    if not request.user.is_authenticated:
        return Response({'error': 'Authentication required.'}, status=401)
    if request.user.role not in ['admin', 'staff']:
        return Response({'error': 'Unauthorized.'}, status=403)

    s = AnnouncementSerializer(data=request.data, context={'request': request})
    if s.is_valid():
        ann = s.save(posted_by=request.user, is_active=True)  # ← force is_active=True
        log_activity('announcement', f'Announcement posted: "{ann.title}" by {request.user.name}', request.user)
        return Response(serialize_ann(ann, request), status=201)

    print("[ANNOUNCEMENT CREATE ERROR]", s.errors)
    return Response(s.errors, status=400)


@api_view(['GET', 'PUT', 'DELETE'])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def announcement_detail_view(request, pk):
    try:
        ann = Announcement.objects.get(pk=pk)
    except Announcement.DoesNotExist:
        return Response({'error': 'Not found.'}, status=404)

    if request.method == 'GET':
        return Response(serialize_ann(ann, request))

    if not request.user.is_authenticated:
        return Response({'error': 'Authentication required.'}, status=401)

    if request.method == 'PUT':
        if request.user.role not in ['admin', 'staff']:
            return Response({'error': 'Unauthorized.'}, status=403)
        s = AnnouncementSerializer(ann, data=request.data, partial=True, context={'request': request})
        if s.is_valid():
            s.save()
            log_activity('announcement', f'Announcement updated: "{ann.title}" by {request.user.name}', request.user)
            return Response(serialize_ann(ann, request))
        print("[ANNOUNCEMENT UPDATE ERROR]", s.errors)
        return Response(s.errors, status=400)

    if request.method == 'DELETE':
        if request.user.role != 'admin':
            return Response({'error': 'Unauthorized.'}, status=403)
        title = ann.title
        ann.delete()
        log_activity('announcement', f'Announcement deleted: "{title}" by {request.user.name}', request.user)
        return Response({'message': 'Deleted.'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_comment_view(request, pk):
    try:
        ann = Announcement.objects.get(pk=pk)
    except Announcement.DoesNotExist:
        return Response({'error': 'Not found.'}, status=404)

    body = request.data.get('body', '').strip()
    if not body:
        return Response({'error': 'Comment cannot be empty.'}, status=400)

    comment = AnnouncementComment.objects.create(
        announcement=ann,
        posted_by=request.user,
        body=body,
    )
    log_activity('announcement', f'{request.user.name} commented on: "{ann.title}"', request.user)
    return Response(CommentSerializer(comment).data, status=201)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_comment_view(request, pk, comment_pk):
    try:
        c = AnnouncementComment.objects.get(pk=comment_pk, announcement__pk=pk)
    except AnnouncementComment.DoesNotExist:
        return Response({'error': 'Not found.'}, status=404)

    if request.user != c.posted_by and request.user.role != 'admin':
        return Response({'error': 'Unauthorized.'}, status=403)

    c.delete()
    return Response({'message': 'Deleted.'})


# ── BAGO: React / un-react / palitan ng reaction sa isang post ─────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def react_view(request, pk):
    """
    POST body: { "reaction_type": "Like" }
    - Kung wala pang reaction ang user sa post na ito → gagawa ng bago.
    - Kung meron na siyang reaction PERO ibang type → papalitan.
    - Kung meron na siyang EXACT na reaction type na 'yon → aalisin
      (parang "un-react", tulad ng pag-untap ng Like sa Facebook).
    Ibinabalik ang updated reaction_counts/total_reactions/my_reaction
    para direktang ma-update ng frontend nang walang kailangan pang
    hiwalay na re-fetch.
    """
    try:
        ann = Announcement.objects.get(pk=pk)
    except Announcement.DoesNotExist:
        return Response({'error': 'Not found.'}, status=404)

    reaction_type = request.data.get('reaction_type', 'Like')
    valid_types = [c[0] for c in AnnouncementReaction.REACTION_CHOICES]
    if reaction_type not in valid_types:
        return Response({'error': f'Invalid reaction_type. Must be one of {valid_types}.'}, status=400)

    existing = AnnouncementReaction.objects.filter(announcement=ann, user=request.user).first()

    if existing and existing.reaction_type == reaction_type:
        # Same type — un-react
        existing.delete()
        my_reaction = None
    elif existing:
        # Different type — palitan
        existing.reaction_type = reaction_type
        existing.save()
        my_reaction = reaction_type
    else:
        # Wala pa — gumawa ng bago
        AnnouncementReaction.objects.create(announcement=ann, user=request.user, reaction_type=reaction_type)
        my_reaction = reaction_type

    counts = {}
    for r in ann.reactions.all():
        counts[r.reaction_type] = counts.get(r.reaction_type, 0) + 1

    return Response({
        'reaction_counts': counts,
        'total_reactions': ann.reactions.count(),
        'my_reaction':      my_reaction,
    })