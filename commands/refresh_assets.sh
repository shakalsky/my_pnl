#!/bin/bash

echo "📦 Получение зависимостей..."
flutter pub get

echo ""
echo "🖼️ Генерация ассетов..."
fgen --name AppImages --output lib/generated/app_images.g.dart --no-preview --no-watch

echo ""
echo "✨ Готово!"
