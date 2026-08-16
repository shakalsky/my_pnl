#!/bin/bash

# Скрипт для генерации папки с provider и state файлами
# Использование: generate_provider.sh <name>
# Создаёт папку name/ с файлами:
#   - name_provider.dart
#   - name_state.dart

SCRIPT_NAME=$(basename "$0")

if [ -z "$1" ]; then
    echo "Ошибка: укажите имя"
    echo "Использование: $SCRIPT_NAME <name>"
    exit 1
fi

NAME="$1"
# Преобразуем snake_case в PascalCase (user_main -> UserMain)
NAME_PASCAL=$(echo "$NAME" | perl -pe 's/(^|_)([a-z])/\U$2/g')
DIR_PATH="$(pwd)/$NAME"

# Создаём папку
mkdir -p "$DIR_PATH"

# Создаём name_provider.dart с содержимым
cat > "$DIR_PATH/${NAME}_provider.dart" << EOF
import 'package:rad/presentation/provider_270/app_state_notifier.dart';

import '${NAME}_state.dart';

class ${NAME_PASCAL}Provider extends AppStateNotifier<${NAME_PASCAL}State> {
  ${NAME_PASCAL}Provider() : super(${NAME_PASCAL}State.initial());

  Future<void> init() async {}
}
EOF

# Создаём name_state.dart с содержимым
cat > "$DIR_PATH/${NAME}_state.dart" << EOF
import 'package:equatable/equatable.dart';

class ${NAME_PASCAL}State extends Equatable {
  final bool isLoading;

  const ${NAME_PASCAL}State({
    required this.isLoading,
  });

  factory ${NAME_PASCAL}State.initial() => const ${NAME_PASCAL}State(isLoading: false);

  ${NAME_PASCAL}State copyWith({
    bool? isLoading,
  }) {
    return ${NAME_PASCAL}State(
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object> get props => [isLoading];
}
EOF

echo "✅ Создана папка: $DIR_PATH"
echo "✅ Созданы файлы:"
echo "  - ${NAME}_provider.dart"
echo "  - ${NAME}_state.dart"
