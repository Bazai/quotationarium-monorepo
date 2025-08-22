from django.core.management.base import BaseCommand
from django.db import transaction
from main.models import Quote, Type
from faker import Faker
import random

class Command(BaseCommand):
    help = 'Generate test quotes using Faker'

    def add_arguments(self, parser):
        parser.add_argument('--count', type=int, default=4000, help='Number of quotes to generate')
        parser.add_argument('--clear', action='store_true', help='Clear existing quotes before generating')

    def handle(self, *args, **options):
        fake = Faker(['ru_RU', 'en_US'])
        count = options['count']
        
        if options['clear']:
            self.stdout.write('Clearing existing quotes...')
            Quote.objects.all().delete()
            Type.objects.all().delete()

        # Create some quote types
        types_data = [
            'Философские', 'Мотивационные', 'Жизненные', 'О любви', 
            'О дружбе', 'О успехе', 'О счастье', 'О мудрости',
            'Юмористические', 'Исторические', 'Литературные', 'Научные'
        ]
        
        types = []
        for type_name in types_data:
            type_obj, created = Type.objects.get_or_create(type=type_name)
            types.append(type_obj)
        
        self.stdout.write(f'Generating {count} quotes...')
        
        # Famous authors for variety
        authors = [
            'Александр Пушкин', 'Лев Толстой', 'Фёдор Достоевский', 'Антон Чехов',
            'Михаил Лермонтов', 'Иван Тургенев', 'Николай Гоголь', 'Максим Горький',
            'Владимир Маяковский', 'Сергей Есенин', 'Анна Ахматова', 'Борис Пастернак',
            'Альберт Эйнштейн', 'Стив Джобс', 'Марк Твен', 'Уильям Шекспир',
            'Оскар Уайльд', 'Эрнест Хемингуэй', 'Джордж Оруэлл', 'Чарльз Диккенс',
            'Конфуций', 'Сократ', 'Платон', 'Аристотель', 'Лао-цзы',
            'Махатма Ганди', 'Мартин Лютер Кинг', 'Нельсон Мандела',
            'Томас Эдисон', 'Никола Тесла', 'Исаак Ньютон', 'Леонардо да Винчи'
        ]
        
        books = [
            'Война и мир', 'Преступление и наказание', 'Анна Каренина', 'Мастер и Маргарита',
            'Евгений Онегин', 'Мёртвые души', 'Отцы и дети', 'Обломов',
            'Гарри Поттер', '1984', 'Убить пересмешника', 'Великий Гэтсби',
            'Гордость и предубеждение', 'Джейн Эйр', 'Грозовой перевал',
            'Божественная комедия', 'Дон Кихот', 'Гамлет', 'Король Лир',
            'Ромео и Джульетта', 'Макбет', 'Фауст', 'Илиада', 'Одиссея'
        ]

        batch_size = 100
        quotes_to_create = []
        
        with transaction.atomic():
            for i in range(count):
                # Generate quote text of varying lengths
                if i % 4 == 0:  # 25% long quotes (400-800 chars)
                    quote_text = ' '.join([fake.text(max_nb_chars=100) for _ in range(4, 8)])
                elif i % 4 == 1:  # 25% medium quotes (200-400 chars)
                    quote_text = ' '.join([fake.text(max_nb_chars=100) for _ in range(2, 4)])
                elif i % 4 == 2:  # 25% short quotes (50-200 chars)
                    quote_text = fake.text(max_nb_chars=200)
                else:  # 25% very short quotes (20-50 chars)
                    quote_text = fake.sentence(nb_words=random.randint(3, 10))
                
                # Clean up quote text
                quote_text = quote_text.replace('\n', ' ').strip()
                if len(quote_text) > 1000:
                    quote_text = quote_text[:997] + '...'
                
                author = random.choice(authors) if random.random() > 0.1 else fake.name()
                book = random.choice(books) if random.random() > 0.3 else fake.catch_phrase()
                
                quote = Quote(
                    quote=quote_text,
                    author=author,
                    book=book
                )
                quotes_to_create.append(quote)
                
                if len(quotes_to_create) >= batch_size:
                    Quote.objects.bulk_create(quotes_to_create)
                    
                    # Add types to created quotes
                    last_quotes = Quote.objects.order_by('-id')[:batch_size]
                    for quote in last_quotes:
                        # Assign 1-3 random types to each quote
                        quote_types = random.sample(types, random.randint(1, min(3, len(types))))
                        quote.type.set(quote_types)
                    
                    quotes_to_create = []
                    self.stdout.write(f'Created {i + 1}/{count} quotes...', ending='\r')
            
            # Create remaining quotes
            if quotes_to_create:
                Quote.objects.bulk_create(quotes_to_create)
                last_quotes = Quote.objects.order_by('-id')[:len(quotes_to_create)]
                for quote in last_quotes:
                    quote_types = random.sample(types, random.randint(1, min(3, len(types))))
                    quote.type.set(quote_types)

        total_quotes = Quote.objects.count()
        self.stdout.write(
            self.style.SUCCESS(f'\nSuccessfully generated {count} quotes. Total quotes in DB: {total_quotes}')
        )