#!/bin/bash

echo "🧹 Удаление сгенерированных файлов (*.freezed.dart и *.g.dart)..."

# Удаление сгенерированных файлов (исключая lib/generated/app_images.g.dart и всю папку lib/i18n)
DELETED_COUNT=$(find . -type f \( -name "*.freezed.dart" -o -name "*.g.dart" \) ! -path "./.git/*" ! -path "./lib/generated/app_images.g.dart" ! -path "./lib/i18n/*" | wc -l | tr -d ' ')

if [ "$DELETED_COUNT" -gt 0 ]; then
    find . -type f \( -name "*.freezed.dart" -o -name "*.g.dart" \) ! -path "./.git/*" ! -path "./lib/generated/app_images.g.dart" ! -path "./lib/i18n/*" -delete
    echo "✅ Удалено файлов: $DELETED_COUNT"
else
    echo "ℹ️  Сгенерированные файлы не найдены"
fi

echo ""
echo "🔍 Проверка удаления..."

# Проверка удаления (исключая lib/generated/app_images.g.dart и всю папку lib/i18n)
REMAINING_COUNT=$(find . -type f \( -name "*.freezed.dart" -o -name "*.g.dart" \) ! -path "./.git/*" ! -path "./lib/generated/app_images.g.dart" ! -path "./lib/i18n/*" | wc -l | tr -d ' ')

if [ "$REMAINING_COUNT" -eq 0 ]; then
    echo "✅ Все сгенерированные файлы успешно удалены"
else
    echo "⚠️  Осталось файлов: $REMAINING_COUNT"
fi

echo ""
echo "🔨 Генерация новых файлов..."

# Генерация новых файлов
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
dart run slang

echo ""
echo "✨ Готово заебал!"
echo "Сам-то можешь что сделать??"