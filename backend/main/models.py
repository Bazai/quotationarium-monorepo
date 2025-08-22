from django.db import models

# Create your models here.
class Type(models.Model):
    type = models.CharField('Type', max_length=200)

    class Meta:
        verbose_name_plural = 'Types'
        verbose_name = 'Type'

    def __str__(self):
        return self.type

class Topic(models.Model):
    topic = models.CharField('Topic', max_length=200)

    class Meta:
        verbose_name_plural = 'Topics'
        verbose_name = 'Topic'

    def __str__(self):
        return self.topic

class Quote(models.Model):
    quote = models.TextField('Quote')
    author = models.CharField('Author', max_length=200, blank=True)
    book = models.CharField('Book', max_length=200, blank=True)
    type = models.ManyToManyField(Type, blank=True)
    topics = models.ManyToManyField(Topic, blank=True)

    @property
    def signs(self):
        return len(self.quote) if self.quote else 0
    
    @property
    def font_size(self):
        if self.signs > 600:
            return 'min'
        elif self.signs > 400:
            return 'under'
        elif self.signs > 300:
            return 'middle'
        elif self.signs > 100:
            return 'upper'
        else:
            return 'max'
    class Meta:
        verbose_name_plural = 'Quotes'
        verbose_name = 'Quote'

    def __str__(self):
        return self.quote
    

class Page(models.Model):
    title = models.CharField('Title', max_length=200)
    slug = models.CharField('Slug', max_length=200, unique = True)
    content = models.TextField('Content')

    class Meta:
        verbose_name_plural = 'Pages'
        verbose_name = 'Page'

    def __str__(self):
        return self.title