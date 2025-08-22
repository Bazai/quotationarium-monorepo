from django.urls import path
from main.views import *
from . import views

urlpatterns = [
    path('', index, name="index"),
    path('<slug:slug>', views.page, name='page'),
]