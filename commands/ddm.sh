#!/bin/bash

# Скрипт для генерации Clean Architecture модуля (data и domain)
# Использование: generate_module.sh <name>
# Создаёт структуру:
#   data/
#     data_source/
#       name/
#         name_data_sources.dart
#         name_remote_data_source_impl.dart
#     repository/
#       name/
#         name_repository_impl.dart
#   domain/
#     repositories/
#       name/
#         name_repository.dart
#     use_cases/
#       name/
#         name_use_case.dart
#         name_use_case_impl.dart

SCRIPT_NAME=$(basename "$0")

if [ -z "$1" ]; then
    echo "Ошибка: укажите имя модуля"
    echo "Использование: $SCRIPT_NAME <name>"
    exit 1
fi

NAME="$1"
# Преобразуем snake_case в PascalCase (user_main -> UserMain)
NAME_PASCAL=$(echo "$NAME" | perl -pe 's/(^|_)([a-z])/\U$2/g')
# Преобразуем snake_case в camelCase (user_main -> userMain)
NAME_CAMEL=$(echo "$NAME" | perl -pe 's/_([a-z])/\U$1/g')
BASE_PATH="$(pwd)"

# Создаём структуру папок
mkdir -p "$BASE_PATH/data/data_sources/$NAME"
mkdir -p "$BASE_PATH/data/repositories/$NAME"
mkdir -p "$BASE_PATH/domain/repositories/$NAME"
mkdir -p "$BASE_PATH/domain/use_cases/$NAME"

# ========== DATA LAYER ==========

# Создаём name_data_source.dart
cat > "$BASE_PATH/data/data_sources/$NAME/${NAME}_data_source.dart" << EOF
abstract interface class ${NAME_PASCAL}DataSource {
  Future<DataModel> getData();
}
EOF

# Создаём name_remote_data_source_impl.dart
cat > "$BASE_PATH/data/data_sources/$NAME/${NAME}_remote_data_source_impl.dart" << EOF
import '${NAME}_data_source.dart';

class ${NAME_PASCAL}RemoteDataSourceImpl implements ${NAME_PASCAL}DataSource {
  final ApiService _apiService;

  ${NAME_PASCAL}RemoteDataSourceImpl({
    required ApiService apiService,
  }) : _apiService = apiService;

  @override
  Future<DataModel> getData() async {
    final response = await _apiService.get('https://api.example.com/data');
    if (response.statusCode == 200) {
      return DataModel.fromJson(response.data);
    } else {
      throw Exception('Failed to load data');
    }
  }
}
EOF

# Создаём name_repository_impl.dart
cat > "$BASE_PATH/data/repositories/$NAME/${NAME}_repository_impl.dart" << EOF
class ${NAME_PASCAL}RepositoryImpl implements ${NAME_PASCAL}Repository {
  final ${NAME_PASCAL}DataSource _${NAME_CAMEL}DataSource;

  ${NAME_PASCAL}RepositoryImpl({
    required ${NAME_PASCAL}DataSource ${NAME_CAMEL}DataSource,
  }) : _${NAME_CAMEL}DataSource = ${NAME_CAMEL}DataSource;

  @override
  Future<DataEntity> getData() async {
    final dataModel = await _${NAME_CAMEL}DataSource.getData();
    return dataModel.toEntity();
  }
}
EOF

# ========== DOMAIN LAYER ==========

# Создаём name_repository.dart
cat > "$BASE_PATH/domain/repositories/$NAME/${NAME}_repository.dart" << EOF
abstract interface class ${NAME_PASCAL}Repository {
  Future<DataEntity> getData();
}
EOF

# Создаём name_use_case.dart
cat > "$BASE_PATH/domain/use_cases/$NAME/${NAME}_use_case.dart" << EOF
abstract interface class ${NAME_PASCAL}UseCase {
  Future<DataEntity> getData();
}
EOF

# Создаём name_use_case_impl.dart
cat > "$BASE_PATH/domain/use_cases/$NAME/${NAME}_use_case_impl.dart" << EOF
import '${NAME}_use_case.dart';

class ${NAME_PASCAL}UseCaseImpl implements ${NAME_PASCAL}UseCase {
  final ${NAME_PASCAL}Repository _${NAME_CAMEL}Repository;

  ${NAME_PASCAL}UseCaseImpl({
    required ${NAME_PASCAL}Repository ${NAME_CAMEL}Repository,
  }) : _${NAME_CAMEL}Repository = ${NAME_CAMEL}Repository;

  @override
  Future<DataEntity> getData() {
    return _${NAME_CAMEL}Repository.getData();
  }
}
EOF

echo "✅ Создан модуль '$NAME' в: $BASE_PATH"
echo ""
echo "Структура:"
echo "  data/"
echo "    data_source/"
echo "      $NAME/"
echo "        - ${NAME}_data_source.dart"
echo "        - ${NAME}_remote_data_source_impl.dart"
echo "    repository/"
echo "      $NAME/"
echo "        - ${NAME}_repository_impl.dart"
echo "  domain/"
echo "    repository/"
echo "      $NAME/"
echo "        - ${NAME}_repository.dart"
echo "    use_case/"
echo "      $NAME/"
echo "        - ${NAME}_use_case.dart"
echo "        - ${NAME}_use_case_impl.dart"
