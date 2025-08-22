from django.core.management.base import BaseCommand
from main.models import Quote


class Command(BaseCommand):
    help = 'Check quotes IDs range and continuity'

    def handle(self, *args, **options):
        quotes = Quote.objects.all().order_by('id')
        total = quotes.count()
        
        if total == 0:
            self.stdout.write(self.style.WARNING('No quotes found'))
            return
        
        first_id = quotes.first().id
        last_id = quotes.last().id
        
        self.stdout.write(f'Total quotes: {total}')
        self.stdout.write(f'ID range: {first_id} - {last_id}')
        self.stdout.write(f'Expected range for continuous IDs: 1 - {total}')
        
        # Check for gaps in IDs
        all_ids = set(quotes.values_list('id', flat=True))
        expected_ids = set(range(first_id, last_id + 1))
        missing_ids = expected_ids - all_ids
        
        if missing_ids:
            self.stdout.write(self.style.WARNING(f'Found {len(missing_ids)} gaps in IDs'))
            if len(missing_ids) <= 10:
                self.stdout.write(f'Missing IDs: {sorted(missing_ids)}')
        else:
            self.stdout.write(self.style.SUCCESS('✓ No gaps in ID sequence'))
        
        # Check if starts from 1
        if first_id == 1:
            self.stdout.write(self.style.SUCCESS('✓ IDs start from 1'))
        else:
            self.stdout.write(self.style.WARNING(f'⚠ IDs start from {first_id} instead of 1'))
        
        # Check if continuous from 1 to total
        if first_id == 1 and last_id == total and not missing_ids:
            self.stdout.write(self.style.SUCCESS('✓ Perfect sequential IDs from 1 to ' + str(total)))