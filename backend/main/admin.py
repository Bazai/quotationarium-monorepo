from django.contrib import admin
from django.urls import path, reverse
from django.contrib.auth.models import User, Group
from django.contrib.auth.admin import UserAdmin, GroupAdmin
from .models import Type, Topic, Quote, Page
from . import admin_views 

# Register your models here.
class QuoteAdmin(admin.ModelAdmin):
    list_display = ('quote', 'author', 'book', 'get_types', 'get_topics')

    def get_types(self, instance):
        return [type.type for type in instance.type.all()]
    get_types.short_description = 'Types'
    
    def get_topics(self, instance):
        return [topic.topic for topic in instance.topics.all()]
    get_topics.short_description = 'Topics'
    

class PageAdmin(admin.ModelAdmin):
    pass

# Создаем кастомную AdminSite для добавления статистики
class CustomAdminSite(admin.AdminSite):
    site_header = 'Quotes Administration'
    site_title = 'Quotes Admin Portal'
    index_title = 'Welcome to Quotes Administration'
    
    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path('statistics/', admin_views.statistics_view, name='admin_statistics'),
        ]
        return custom_urls + urls
    
    def index(self, request, extra_context=None):
        extra_context = extra_context or {}
        
        # Добавляем кастомную секцию статистики
        app_list = self.get_app_list(request)
        
        # Создаем виртуальное приложение для статистики
        statistics_app = {
            'name': 'Statistics',
            'app_label': 'statistics', 
            'app_url': reverse('custom_admin:admin_statistics'),
            'has_module_perms': True,
            'models': [
                {
                    'name': 'Statistics',
                    'object_name': 'Statistics',
                    'admin_url': reverse('custom_admin:admin_statistics'),
                    'add_url': None,
                    'view_only': True,
                    'perms': {'view': True}
                }
            ]
        }
        
        app_list.append(statistics_app)
        extra_context['app_list'] = app_list
        
        return super().index(request, extra_context)

# Создаем экземпляр кастомной админки
custom_admin_site = CustomAdminSite(name='custom_admin')

# Регистрируем встроенные Django модели в кастомной админке
custom_admin_site.register(User, UserAdmin)
custom_admin_site.register(Group, GroupAdmin)

# Регистрируем наши модели в кастомной админке
custom_admin_site.register(Type)
custom_admin_site.register(Topic)
custom_admin_site.register(Quote, QuoteAdmin)
custom_admin_site.register(Page, PageAdmin)

# Также регистрируем в стандартной админке для совместимости
admin.site.register(Type)
admin.site.register(Topic)
admin.site.register(Quote, QuoteAdmin)
admin.site.register(Page, PageAdmin)