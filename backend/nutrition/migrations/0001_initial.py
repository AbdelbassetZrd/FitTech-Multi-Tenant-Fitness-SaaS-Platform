# Generated migration for nutrition app

from django.db import migrations, models
import django.db.models.deletion
import nutrition.models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('users', '0001_initial'),  # Adjust based on users app migrations
    ]

    operations = [
        migrations.CreateModel(
            name='NutritionProfile',
            fields=[
                ('id', models.CharField(default=nutrition.models.generate_chat_id, editable=False, max_length=36, primary_key=True, serialize=False)),
                ('height_cm', models.FloatField(blank=True, help_text='Height in cm', null=True)),
                ('weight_kg', models.FloatField(blank=True, help_text='Weight in kg', null=True)),
                ('age', models.IntegerField(blank=True, null=True)),
                ('activity_level', models.CharField(choices=[('sedentary', 'Sedentary'), ('light', 'Lightly Active'), ('moderate', 'Moderately Active'), ('very_active', 'Very Active'), ('extremely_active', 'Extremely Active')], default='moderate', max_length=20)),
                ('dietary_preference', models.CharField(choices=[('omnivore', 'Omnivore'), ('vegetarian', 'Vegetarian'), ('vegan', 'Vegan'), ('pescatarian', 'Pescatarian'), ('keto', 'Keto'), ('paleo', 'Paleo'), ('low_carb', 'Low Carb')], default='omnivore', max_length=20)),
                ('allergies', models.TextField(blank=True, help_text='Comma-separated list of food allergies')),
                ('dislikes', models.TextField(blank=True, help_text='Foods the member dislikes')),
                ('nutrition_goals', models.TextField(blank=True, help_text="e.g., 'lose 5kg', 'gain muscle', 'improve energy'")),
                ('target_daily_calories', models.IntegerField(blank=True, help_text='Target daily calorie intake', null=True)),
                ('target_daily_protein_g', models.FloatField(blank=True, help_text='Target daily protein in grams', null=True)),
                ('medical_conditions', models.TextField(blank=True, help_text="e.g., 'diabetes', 'hypertension', 'lactose intolerant'")),
                ('supplements_taken', models.TextField(blank=True, help_text='Current supplements or medications')),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('member', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='nutrition_profile', to='users.member')),
            ],
            options={
                'db_table': 'nutrition_profiles',
            },
        ),
        migrations.CreateModel(
            name='NutritionChat',
            fields=[
                ('id', models.CharField(default=nutrition.models.generate_chat_id, editable=False, max_length=36, primary_key=True, serialize=False)),
                ('title', models.CharField(blank=True, max_length=255)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('member', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='nutrition_chats', to='users.member')),
            ],
            options={
                'db_table': 'nutrition_chats',
                'ordering': ['-updated_at'],
            },
        ),
        migrations.CreateModel(
            name='NutritionMessage',
            fields=[
                ('id', models.CharField(default=nutrition.models.generate_chat_id, editable=False, max_length=36, primary_key=True, serialize=False)),
                ('role', models.CharField(choices=[('user', 'User'), ('assistant', 'Assistant')], max_length=10)),
                ('content', models.TextField()),
                ('tokens_used', models.IntegerField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('chat', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='messages', to='nutrition.nutritionchat')),
            ],
            options={
                'db_table': 'nutrition_messages',
                'ordering': ['created_at'],
            },
        ),
    ]
