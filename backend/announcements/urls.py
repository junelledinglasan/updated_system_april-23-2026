from django.urls import path
from .views import (
    announcement_list_view,
    announcement_detail_view,
    add_comment_view,
    delete_comment_view,
    react_view,
)

urlpatterns = [
    path('',                                    announcement_list_view,   name='ann-list'),
    path('<int:pk>/',                           announcement_detail_view, name='ann-detail'),
    path('<int:pk>/comments/',                  add_comment_view,         name='add-comment'),
    path('<int:pk>/comments/<int:comment_pk>/', delete_comment_view,      name='del-comment'),
    path('<int:pk>/react/',                     react_view,               name='ann-react'),
]