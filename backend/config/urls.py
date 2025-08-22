"""
URL configuration for collector project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.urls import path, include
from main import views
from main.admin import custom_admin_site
from rest_framework import routers

router = routers.DefaultRouter()
router.register(r'quotes', views.QuoteViewSet)
router.register(r'pages', views.PageViewSet)
router.register(r'types', views.TypeViewSet, basename='type')
router.register(r'topics', views.TopicViewSet, basename='topic')

urlpatterns = [
    path('admin/', custom_admin_site.urls),
    path('api/', include(router.urls)),
    path('', include("django_nextjs.urls")),
    path('', include("main.urls")),
]
