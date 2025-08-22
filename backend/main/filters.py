from django_filters import rest_framework as filters
from .models import Quote
from django.db.models import Q

class QuoteFilter(filters.FilterSet):
    search = filters.CharFilter(method='custom_search', label='Search')
    type = filters.NumberFilter(field_name='type__id', lookup_expr='exact', label='Type')
    topic = filters.NumberFilter(field_name='topics__id', lookup_expr='exact', label='Topic')

    class Meta:
        model = Quote
        fields = ['search', 'type', 'topic']

    def custom_search(self, queryset, name, value):
        regex_pattern = r'(\W|^|«)' + value
        return queryset.filter(
            Q(quote__iregex=regex_pattern) |
            Q(author__iregex=regex_pattern) |
            Q(book__iregex=regex_pattern)
        ).distinct()
