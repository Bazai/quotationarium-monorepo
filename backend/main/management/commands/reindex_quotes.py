from django.core.management.base import BaseCommand
from django.db import connection, transaction
from main.models import Quote


class Command(BaseCommand):
    help = 'Reindex all quotes IDs starting from 1'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Run the command without making actual changes'
        )

    def handle(self, *args, **options):
        dry_run = options.get('dry_run', False)
        
        if dry_run:
            self.stdout.write(self.style.WARNING('DRY RUN MODE - No changes will be made'))
        
        # Get all quotes ordered by current ID to maintain order
        quotes = Quote.objects.all().order_by('id')
        total_quotes = quotes.count()
        
        self.stdout.write(f'Found {total_quotes} quotes to reindex')
        
        if total_quotes == 0:
            self.stdout.write(self.style.WARNING('No quotes found'))
            return
        
        # Show current ID range
        first_id = quotes.first().id
        last_id = quotes.last().id
        self.stdout.write(f'Current ID range: {first_id} - {last_id}')
        
        if not dry_run:
            # Ask for confirmation
            confirm = input('\nThis will reindex all quote IDs starting from 1. Are you sure? (yes/no): ')
            if confirm.lower() != 'yes':
                self.stdout.write(self.style.ERROR('Operation cancelled'))
                return
        
        try:
            with transaction.atomic():
                # Store quotes data in memory with their relationships
                quotes_data = []
                for old_quote in quotes:
                    quotes_data.append({
                        'quote': old_quote.quote,
                        'author': old_quote.author,
                        'book': old_quote.book,
                        'type': list(old_quote.type.all()),
                        'topics': list(old_quote.topics.all()),
                    })
                
                if not dry_run:
                    self.stdout.write('Deleting existing quotes...')
                    Quote.objects.all().delete()
                    
                    # Reset the sequence based on database backend
                    with connection.cursor() as cursor:
                        if connection.vendor == 'postgresql':
                            cursor.execute("ALTER SEQUENCE main_quote_id_seq RESTART WITH 1")
                        elif connection.vendor == 'sqlite':
                            cursor.execute("DELETE FROM sqlite_sequence WHERE name='main_quote'")
                        elif connection.vendor == 'mysql':
                            cursor.execute("ALTER TABLE main_quote AUTO_INCREMENT = 1")
                    
                    self.stdout.write('Creating reindexed quotes...')
                    
                    # Recreate quotes with new sequential IDs
                    for i, data in enumerate(quotes_data, 1):
                        new_quote = Quote.objects.create(
                            quote=data['quote'],
                            author=data['author'],
                            book=data['book']
                        )
                        
                        # Restore many-to-many relationships
                        if data['type']:
                            new_quote.type.set(data['type'])
                        if data['topics']:
                            new_quote.topics.set(data['topics'])
                        
                        if i % 100 == 0:
                            self.stdout.write(f'Processed {i}/{total_quotes} quotes...')
                    
                    # Verify the reindexing
                    new_quotes = Quote.objects.all().order_by('id')
                    new_first_id = new_quotes.first().id
                    new_last_id = new_quotes.last().id
                    
                    self.stdout.write(self.style.SUCCESS(
                        f'Successfully reindexed {total_quotes} quotes. New ID range: {new_first_id} - {new_last_id}'
                    ))
                else:
                    self.stdout.write(self.style.SUCCESS(
                        f'DRY RUN: Would reindex {total_quotes} quotes to IDs 1 - {total_quotes}'
                    ))
                    
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Error during reindexing: {str(e)}'))
            raise