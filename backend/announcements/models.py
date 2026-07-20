from django.db import models
from auth_app.models import User


class Announcement(models.Model):
    TYPE_CHOICES = [
        ('Notice',       'Notice'),
        ('Activity',     'Activity'),
        ('Seminar',      'Seminar'),
        ('Event',        'Event'),
        ('Announcement', 'Announcement'),
    ]

    title      = models.CharField(max_length=200)
    body       = models.TextField()
    type       = models.CharField(max_length=20, choices=TYPE_CHOICES, default='Notice')
    image      = models.ImageField(upload_to='announcements/', null=True, blank=True)
    pinned     = models.BooleanField(default=False)
    is_active  = models.BooleanField(default=True)
    posted_by  = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='announcements')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'announcements'
        ordering = ['-pinned', '-created_at']

    def __str__(self):
        return self.title

    @property
    def image_url(self):
        if self.image:
            return self.image.url
        return None

    @property
    def posted_by_name(self):
        return self.posted_by.name if self.posted_by else "Admin"

    @property
    def posted_by_role(self):
        return self.posted_by.role if self.posted_by else "admin"


class AnnouncementComment(models.Model):
    announcement = models.ForeignKey(Announcement, on_delete=models.CASCADE, related_name='comments')
    posted_by    = models.ForeignKey(User, on_delete=models.CASCADE, related_name='ann_comments')
    body         = models.TextField()
    created_at   = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'announcement_comments'
        ordering = ['created_at']

    @property
    def posted_by_name(self):
        return self.posted_by.name if self.posted_by else "User"

    @property
    def posted_by_role(self):
        return self.posted_by.role if self.posted_by else ""


# ── BAGO: Reactions (parang Facebook Like/Love/Haha/atbp.) ─────────────────
class AnnouncementReaction(models.Model):
    REACTION_CHOICES = [
        ('Like',  'Like'),
        ('Love',  'Love'),
        ('Haha',  'Haha'),
        ('Wow',   'Wow'),
        ('Sad',   'Sad'),
        ('Angry', 'Angry'),
    ]

    announcement   = models.ForeignKey(Announcement, on_delete=models.CASCADE, related_name='reactions')
    user           = models.ForeignKey(User, on_delete=models.CASCADE, related_name='ann_reactions')
    reaction_type  = models.CharField(max_length=10, choices=REACTION_CHOICES, default='Like')
    created_at     = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'announcement_reactions'
        # Isang reaction lang kada user kada post — pag nag-react ulit sila
        # ng ibang type, papalitan lang, hindi magdadagdag ng bago.
        unique_together = ('announcement', 'user')
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.user} {self.reaction_type} on {self.announcement_id}'