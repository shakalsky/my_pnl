#!/bin/bash

# Скрипт для генерации папки с dart файлами
# Использование: generate_file.sh <name>
# Создаёт папку name/ с файлами:
#   - name_view.dart
#   - name_page.dart
#   - name_view_action_extension.dart

SCRIPT_NAME=$(basename "$0")

if [ -z "$1" ]; then
    echo "Ошибка: укажите имя"
    echo "Использование: $SCRIPT_NAME <name>"
    exit 1
fi

NAME="$1"
# Преобразуем snake_case в PascalCase (user_main -> UserMain)
NAME_PASCAL=$(echo "$NAME" | perl -pe 's/(^|_)([a-z])/\U$2/g')
# Преобразуем snake_case в camelCase (user_main -> userMain)
NAME_CAMEL=$(echo "$NAME" | perl -pe 's/_([a-z])/\U$1/g')
DIR_PATH="$(pwd)/$NAME"

# Создаём папку
mkdir -p "$DIR_PATH"

# Создаём name_view.dart с содержимым
cat > "$DIR_PATH/_${NAME}_view.dart" << EOF
part of '${NAME}_page.dart';

class _${NAME_PASCAL}View extends StatefulWidget {
  const _${NAME_PASCAL}View();

  @override
  State<_${NAME_PASCAL}View> createState() => _${NAME_PASCAL}ViewState();
}

class _${NAME_PASCAL}ViewState extends State<_${NAME_PASCAL}View> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold();
  }
}
EOF

# Создаём name_page.dart с содержимым
cat > "$DIR_PATH/${NAME}_page.dart" << EOF
import 'package:flutter/material.dart';

import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:auto_route/auto_route.dart';

import 'package:rad/core/config/routes/router.dart';
import 'package:rad/injector.dart';

part '_${NAME}_view_action_extension.dart';
part '_${NAME}_view.dart';

@RoutePage(name: RouteNames.${NAME_CAMEL}Page)
class ${NAME_PASCAL}Page extends StatelessWidget {
  const ${NAME_PASCAL}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return StateNotifierProvider<${NAME_PASCAL}Provider, ${NAME_PASCAL}State>(
      create: (BuildContext context) => getIt<${NAME_PASCAL}Provider>()..init(),
      builder: (context, child) => GestureDetector(
        onTap: FocusScope.of(context).unfocus,
        child: const SafeArea(
          child: _${NAME_PASCAL}View(),
        ),
      ),
    );
  }
}
EOF

# Создаём _name_view_action_extension.dart с содержимым
cat > "$DIR_PATH/_${NAME}_view_action_extension.dart" << EOF
part of '${NAME}_page.dart';

extension ${NAME_PASCAL}ViewActionExtension on _${NAME_PASCAL}ViewState {}
EOF

echo "✅ Создана папка: $DIR_PATH"
echo "✅ Созданы файлы:"
echo "  - ${NAME}_view.dart"
echo "  - ${NAME}_page.dart"
echo "  - ${NAME}_view_action_extension.dart"
