from django.urls import path

from . import views

urlpatterns = [
    path('', views.index_cze, name='index_cze'),
    path('cze', views.index_cze, name='index_cze'),
    path('eng', views.index_eng, name='index_eng'),
    path('search', views.search, name='search'),
    path('app', views.app, name='app'),
    path('api/search', views.api_search, name='api_search'),
    path('api/info', views.api_info, name='api_info'),
]
