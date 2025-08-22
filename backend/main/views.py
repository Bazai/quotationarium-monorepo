from .models import Quote, Page, Type, Topic
from django.views.decorators.csrf import csrf_exempt
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from .serializers import QuoteSerializer, PageSerializer, TypeSerializer, TopicSerializer
from .pagination import CustomQuotePagination
from django_nextjs.render import render_nextjs_page_sync
from django.db.models.functions import Length
from django.db.models import Count
from rest_framework.filters import SearchFilter, OrderingFilter
from django_filters.rest_framework import DjangoFilterBackend
from .filters import QuoteFilter
import math


def index(request):
    return render_nextjs_page_sync(request)

def page(request, slug):
    return render_nextjs_page_sync(request)

class QuoteViewSet(viewsets.ModelViewSet):
    queryset = Quote.objects.all().order_by(Length('quote').asc())
    serializer_class = QuoteSerializer
    permission_classes = []
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_class = QuoteFilter
    ordering_fields = ['id']
    pagination_class = CustomQuotePagination
    
    def _is_descending_order(self, request):
        """Определить, используется ли убывающая сортировка по ID"""
        ordering = request.query_params.get('ordering', '')
        return ordering == '-id'
    
    def _format_min_max_label(self, first_id, last_id):
        """Форматировать лейбл в формате min-max"""
        min_id = min(first_id, last_id)
        max_id = max(first_id, last_id)
        return f"{min_id} - {max_id}"
    
    def filter_queryset(self, queryset):
        """Override to ignore type/topic filters when search is present"""
        # If search parameter is present, only apply search filter
        if self.request.query_params.get('search'):
            # Create a copy of query params without type and topic
            original_params = self.request.query_params
            mutable_params = original_params.copy()
            mutable_params.pop('type', None)
            mutable_params.pop('topic', None)
            mutable_params.pop('page', None)
            
            # Temporarily replace query_params for filtering
            self.request._request.GET = mutable_params
            queryset = super().filter_queryset(queryset)
            # Restore original params
            self.request._request.GET = original_params
            return queryset
        
        # Normal filtering for non-search requests
        return super().filter_queryset(queryset)
    
    def paginate_queryset(self, queryset):
        """Disable pagination when searching or filtering by type or topic"""
        # Check if search, type or topic filter is applied
        if (self.request.query_params.get('search') or 
            self.request.query_params.get('type') or 
            self.request.query_params.get('topic')):
            return None  # No pagination
        return super().paginate_queryset(queryset)
    
    def list(self, request, *args, **kwargs):
        """Override list to handle unpaginated responses consistently"""
        queryset = self.filter_queryset(self.get_queryset())
        
        # Handle position parameter for single quote retrieval
        position = request.query_params.get('position')
        if position:
            try:
                pos = int(position) - 1  # Convert to 0-based index
                total_count = queryset.count()
                
                # Validate position is within range
                if pos < 0 or pos >= total_count:
                    return Response({
                        'error': 'Position out of range',
                        'total_count': total_count
                    }, status=400)
                
                # Get the specific quote at position
                quote = queryset[pos:pos+1].first()
                if quote:
                    serializer = self.get_serializer(quote)
                    return Response(serializer.data)
                else:
                    return Response({'error': 'Quote not found'}, status=404)
                    
            except ValueError:
                return Response({'error': 'Invalid position parameter'}, status=400)
        
        if (request.query_params.get('search') or 
            request.query_params.get('type') or 
            request.query_params.get('topic')):
            # When search, type or topic filter is applied, return all results without pagination
            serializer = self.get_serializer(queryset, many=True)
            return Response({
                'count': queryset.count(),
                'total_pages': 1,
                'current_page': 1,
                'page_size': queryset.count(),
                'items_on_page': queryset.count(),
                'start_item': 1,
                'end_item': queryset.count(),
                'page_label': f"1 - {queryset.count()}",
                'next': None,
                'previous': None,
                'results': serializer.data
            })
        
        # Normal paginated response
        return super().list(request, *args, **kwargs)

    @action(detail=False, methods=['get'])
    def pages_info(self, request):
        """Get pagination metadata for all available pages"""
        # Apply same filters as main queryset
        queryset = self.filter_queryset(self.get_queryset())
        total_count = queryset.count()
        
        # Check if search, type or topic filter is applied - if so, disable pagination
        if (request.query_params.get('search') or 
            request.query_params.get('type') or 
            request.query_params.get('topic')):
            return Response({
                'total_count': total_count,
                'total_pages': 0,
                'page_size': 0,
                'pages': [],
                'pagination_disabled': True
            })
        
        page_size = 100
        standard_pages = math.ceil(total_count / page_size)
        is_descending = self._is_descending_order(request)
        
        # Calculate adjusted pages (accounting for merged page)
        if standard_pages > 1:
            remainder_items = total_count % page_size
            if remainder_items > 0 and remainder_items < page_size:
                total_pages = standard_pages - 1
            else:
                total_pages = standard_pages
        else:
            total_pages = standard_pages
        
        # Generate page info for each page
        pages = []
        for page_num in range(1, total_pages + 1):
            # Determine if this is the merged page
            if is_descending:
                # For descending order, first page is merged
                is_merged_page = (page_num == 1 and total_pages > 1 and 
                                total_count % page_size > 0 and 
                                total_count % page_size < page_size)
            else:
                # For ascending order, last page is merged
                is_merged_page = (page_num == total_pages and total_pages > 1 and
                                total_count % page_size > 0 and 
                                total_count % page_size < page_size)
            
            if is_merged_page:
                if is_descending:
                    # First page with merged content
                    remainder = total_count % page_size
                    items_count = page_size + remainder
                    start_item = 1
                    end_item = items_count
                else:
                    # Last page with merged content  
                    start_item = ((page_num - 1) * page_size) + 1
                    end_item = total_count
                    items_count = end_item - start_item + 1
            else:
                if is_descending and total_pages > 1 and total_count % page_size > 0 and total_count % page_size < page_size:
                    # Adjust for pages after the merged first page
                    remainder = total_count % page_size
                    start_item = ((page_num - 1) * page_size) + 1 + remainder
                    end_item = min(page_num * page_size + remainder, total_count)
                    items_count = end_item - start_item + 1
                else:
                    # Normal page
                    start_item = ((page_num - 1) * page_size) + 1
                    end_item = min(page_num * page_size, total_count)
                    items_count = end_item - start_item + 1
            
            # Get actual IDs for this page range
            page_start_index = start_item - 1
            page_end_index = end_item
            
            # Get the actual quote IDs for this page
            page_quotes = queryset[page_start_index:page_end_index]
            if page_quotes:
                # Get first and last IDs on this page
                page_ids = list(page_quotes.values_list('id', flat=True))
                first_id = page_ids[0] if page_ids else start_item
                last_id = page_ids[-1] if page_ids else end_item
                
                # Use actual IDs for the label in min-max format
                label = self._format_min_max_label(first_id, last_id)
            else:
                label = f"{start_item} - {end_item}"
            
            pages.append({
                'page': page_num,
                'start_item': start_item,
                'end_item': end_item,
                'items_count': items_count,
                'label': label
            })
        
        return Response({
            'total_count': total_count,
            'total_pages': total_pages,
            'page_size': page_size,
            'pages': pages,
            'pagination_disabled': False
        })

    @action(detail=False, methods=['get'])
    def total_count(self, request):
        """Get total count of quotes with current filters applied"""
        # Apply same filters as main queryset
        queryset = self.filter_queryset(self.get_queryset())
        total_count = queryset.count()
        
        return Response({
            'total_count': total_count
        })

class PageViewSet(viewsets.ModelViewSet):
    queryset = Page.objects.all()
    serializer_class = PageSerializer
    permission_classes = []

class TypeViewSet(viewsets.ModelViewSet):
    serializer_class = TypeSerializer
    permission_classes = []
    
    def get_queryset(self):
        queryset = Type.objects.annotate(num_items=Count('quote')).filter(num_items__gt=0).order_by('type')
        
        # Filter types by selected topic
        topic = self.request.query_params.get('topic')
        if topic:
            queryset = queryset.filter(quote__topics__id=topic).distinct()
        
        return queryset

class TopicViewSet(viewsets.ModelViewSet):
    serializer_class = TopicSerializer
    permission_classes = []
    
    def get_queryset(self):
        queryset = Topic.objects.annotate(num_items=Count('quote')).filter(num_items__gt=0).order_by('topic')
        
        # Filter topics by selected type
        type_id = self.request.query_params.get('type')
        if type_id:
            queryset = queryset.filter(quote__type__id=type_id).distinct()
        
        return queryset
