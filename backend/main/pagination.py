from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from collections import OrderedDict
import math

class CustomQuotePagination(PageNumberPagination):
    """
    Custom pagination that follows special logic:
    - 100 quotes per page for all pages except the merged page
    - For ordering=id: Last page gets up to 199 quotes (previous page + remainder) 
    - For ordering=-id: First page gets up to 199 quotes (first + second page)
    """
    page_size = 100
    page_size_query_param = 'page_size'
    max_page_size = 199
    
    def _is_descending_order(self, request):
        """Определить, используется ли убывающая сортировка по ID"""
        ordering = request.query_params.get('ordering', '')
        return ordering == '-id'
    
    def _format_min_max_label(self, first_id, last_id):
        """Форматировать лейбл в формате min-max"""
        min_id = min(first_id, last_id)
        max_id = max(first_id, last_id)
        return f"{min_id} - {max_id}"

    def get_page_size(self, request):
        """Determine page size based on current page and total items"""
        page_size = super().get_page_size(request)
        
        # Get total count from queryset
        if hasattr(self, 'django_paginator_class'):
            total_count = self.django_paginator_class.count
        else:
            # If we don't have the paginator yet, use default page size
            return page_size
            
        return page_size

    def paginate_queryset(self, queryset, request, view=None):
        """
        Custom pagination logic that merges pages based on ordering direction:
        - ordering=-id: merges first page (first + second pages)
        - ordering=id: merges last page (last two pages)
        """
        page_size = self.get_page_size(request)
        if not page_size:
            return None

        paginator = self.django_paginator_class(queryset, page_size)
        page_number = int(request.query_params.get(self.page_query_param, 1))
        is_descending = self._is_descending_order(request)
        
        # Calculate total pages with standard page size
        total_count = paginator.count
        standard_pages = math.ceil(total_count / page_size)
        
        # If we have more than 1 page, check if we need to merge pages
        if standard_pages > 1:
            remainder_items = total_count % page_size
            if remainder_items > 0 and remainder_items < page_size:
                # We have a partial page, need to merge
                adjusted_pages = standard_pages - 1
                
                if is_descending:
                    # For descending order, merge first page
                    if page_number == 1:
                        # Get items for the merged first page (first page + remainder)
                        start_index = 0
                        end_index = page_size + remainder_items
                        merged_page_items = queryset[start_index:end_index]
                        
                        # Create custom page object
                        class CustomPage:
                            def __init__(self, object_list, number, paginator):
                                self.object_list = list(object_list)
                                self.number = number
                                self.paginator = paginator
                                
                            def has_next(self):
                                return self.number < self.paginator.num_pages
                                
                            def has_previous(self):
                                return False
                                
                            def next_page_number(self):
                                return self.number + 1 if self.has_next() else None
                                
                            def previous_page_number(self):
                                return None
                        
                        # Update paginator to reflect adjusted page count
                        paginator.num_pages = adjusted_pages
                        self.page = CustomPage(merged_page_items, 1, paginator)
                        return self.page.object_list
                    
                    elif page_number <= adjusted_pages:
                        # Normal page request (offset by merged first page)
                        start_index = page_size + remainder_items + (page_number - 2) * page_size
                        end_index = start_index + page_size
                        page_items = queryset[start_index:end_index]
                        
                        class CustomPage:
                            def __init__(self, object_list, number, paginator):
                                self.object_list = list(object_list)
                                self.number = number
                                self.paginator = paginator
                                
                            def has_next(self):
                                return self.number < self.paginator.num_pages
                                
                            def has_previous(self):
                                return self.number > 1
                                
                            def next_page_number(self):
                                return self.number + 1 if self.has_next() else None
                                
                            def previous_page_number(self):
                                return self.number - 1 if self.has_previous() else None
                        
                        paginator.num_pages = adjusted_pages
                        self.page = CustomPage(page_items, page_number, paginator)
                        return self.page.object_list
                    else:
                        # Requesting page beyond our adjusted pages
                        return None
                else:
                    # For ascending order, merge last page (existing logic)
                    if page_number == adjusted_pages:
                        # Get items for the merged last page
                        start_index = (adjusted_pages - 1) * page_size
                        end_index = total_count
                        merged_page_items = queryset[start_index:end_index]
                        
                        class CustomPage:
                            def __init__(self, object_list, number, paginator):
                                self.object_list = list(object_list)
                                self.number = number
                                self.paginator = paginator
                                
                            def has_next(self):
                                return False
                                
                            def has_previous(self):
                                return self.number > 1
                                
                            def next_page_number(self):
                                return None
                                
                            def previous_page_number(self):
                                return self.number - 1 if self.has_previous() else None
                        
                        # Update paginator to reflect adjusted page count
                        paginator.num_pages = adjusted_pages
                        self.page = CustomPage(merged_page_items, adjusted_pages, paginator)
                        return self.page.object_list
                    
                    elif page_number < adjusted_pages:
                        # Normal page request
                        self.page = paginator.page(page_number)
                        return self.page.object_list
                    else:
                        # Requesting page beyond our adjusted pages
                        return None
            else:
                # No partial page, use standard pagination
                self.page = paginator.page(page_number)
                return self.page.object_list
        else:
            # Only one page or less, use standard pagination
            self.page = paginator.page(page_number)
            return self.page.object_list

    def get_paginated_response(self, data):
        """Custom response format with additional metadata"""
        # Calculate page info
        total_count = self.page.paginator.count
        page_size = self.page_size
        
        # Calculate adjusted pages (accounting for merged last page)
        standard_pages = math.ceil(total_count / page_size)
        if standard_pages > 1:
            last_page_items = total_count % page_size
            if last_page_items > 0 and last_page_items < page_size:
                total_pages = standard_pages - 1
            else:
                total_pages = standard_pages
        else:
            total_pages = standard_pages

        current_page = self.page.number
        
        # Calculate items range for current page
        if current_page == total_pages and total_pages > 1:
            # This is the merged last page
            start_item = ((current_page - 1) * page_size) + 1
            end_item = total_count
            items_on_page = len(data)
        else:
            # Normal page
            start_item = ((current_page - 1) * page_size) + 1
            end_item = min(current_page * page_size, total_count)
            items_on_page = len(data)

        # Get actual IDs from the data for the label in min-max format
        if data:
            first_id = data[0].get('id', start_item) if isinstance(data[0], dict) else start_item
            last_id = data[-1].get('id', end_item) if isinstance(data[-1], dict) else end_item
            page_label = self._format_min_max_label(first_id, last_id)
        else:
            page_label = f"{start_item} - {end_item}"
        
        return Response(OrderedDict([
            ('count', total_count),
            ('total_pages', total_pages),
            ('current_page', current_page),
            ('page_size', page_size),
            ('items_on_page', items_on_page),
            ('start_item', start_item),
            ('end_item', end_item),
            ('page_label', page_label),
            ('next', self.get_next_link()),
            ('previous', self.get_previous_link()),
            ('results', data)
        ]))

    def get_next_link(self):
        if not self.page.has_next():
            return None
        return None  # Simplified for now

    def get_previous_link(self):
        if not self.page.has_previous():
            return None
        return None  # Simplified for now