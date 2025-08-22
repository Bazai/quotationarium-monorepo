from .models import Quote, Page, Type, Topic
from rest_framework import serializers

class QuoteSerializer(serializers.ModelSerializer):
    id = serializers.ReadOnlyField()
    signs = serializers.ReadOnlyField()
    font_size = serializers.ReadOnlyField()

    class Meta:
        model = Quote
        fields = '__all__'

class PageSerializer(serializers.ModelSerializer):
    id = serializers.ReadOnlyField()

    class Meta:
        model = Page
        fields = '__all__'

class TypeSerializer(serializers.ModelSerializer):
    id = serializers.ReadOnlyField()

    class Meta:
        model = Type
        fields = '__all__'

class TopicSerializer(serializers.ModelSerializer):
    id = serializers.ReadOnlyField()

    class Meta:
        model = Topic
        fields = '__all__'