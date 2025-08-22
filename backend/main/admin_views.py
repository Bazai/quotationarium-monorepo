from django.shortcuts import render
from django.contrib.admin.views.decorators import staff_member_required
from django.db.models import Count
from .models import Quote, Type, Topic


@staff_member_required
def statistics_view(request):
    """
    View для отображения статистики цитат в админке
    """
    
    # Статистика по приёмам (Type)
    type_stats = Type.objects.annotate(
        quote_count=Count('quote')
    ).filter(quote_count__gt=0).order_by('-quote_count')
    
    # Цитаты без приёмов
    quotes_without_types = Quote.objects.filter(type__isnull=True).count()
    
    # Статистика по темам (Topic)
    topic_stats = Topic.objects.annotate(
        quote_count=Count('quote')
    ).filter(quote_count__gt=0).order_by('-quote_count')
    
    # Цитаты без тем
    quotes_without_topics = Quote.objects.filter(topics__isnull=True).count()
    
    # Статистика по авторам
    author_quotes = Quote.objects.exclude(author='').values('author').annotate(
        quote_count=Count('id')
    )
    
    # Обработка авторов для сортировки по фамилии
    author_stats = []
    for item in author_quotes:
        author_name = item['author'].strip()
        quote_count = item['quote_count']
        
        # Извлечение фамилии (второе слово или первое, если одно)
        name_parts = author_name.split()
        if len(name_parts) >= 2:
            # Фамилия - второе слово
            surname = name_parts[1]
        else:
            # Фамилия - первое слово (если одно)
            surname = name_parts[0] if name_parts else author_name
        
        author_stats.append({
            'full_name': author_name,
            'surname': surname,
            'quote_count': quote_count
        })
    
    # Сортировка по фамилии в алфавитном порядке
    author_stats.sort(key=lambda x: x['surname'].lower())
    
    # Цитаты без авторов
    quotes_without_authors = Quote.objects.filter(author='').count()
    
    context = {
        'title': 'Статистика цитат',
        'type_stats': type_stats,
        'quotes_without_types': quotes_without_types,
        'topic_stats': topic_stats,
        'quotes_without_topics': quotes_without_topics,
        'author_stats': author_stats,
        'quotes_without_authors': quotes_without_authors,
        'opts': Quote._meta,  # Для интеграции с admin breadcrumbs
    }
    
    return render(request, 'admin/statistics.html', context)