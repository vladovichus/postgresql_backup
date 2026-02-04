#!/usr/bin/env bash
set -uo pipefail

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/pg}"
BACKUP_TARGET="/backups"
LOG_FILE="${LOG_FILE:-/var/log/pg_backup.log}"

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }

log() {
  local level="$1"; shift
  printf "%s [%s] %s\n" "$(timestamp)" "$level" "$*" >> "$LOG_FILE"
}

fail() {
  log "ERROR" "$*"
  exit 1
}

main() {
  mkdir -p "$BACKUP_ROOT" || fail "Каталог не создал$BACKUP_ROOT"
  mkdir -p "$BACKUP_TARGET" || fail "Каталог не создан $BACKUP_TARGET"

  local run_dir
  run_dir="${BACKUP_ROOT}/run_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$run_dir" || fail "каталог не создан $run_dir"

  log "INFO" "Начало резервного копирования PostgreSQL: host=$PGHOST port=$PGPORT user=$PGUSER run_dir=$run_dir"

  local db_list
  if ! db_list=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -At -c "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>>"$LOG_FILE"); then
    fail "Неверный пароль или параметры подключения, не удалось получить список баз)"
  fi

  if [ -z "$db_list" ]; then
    log "WARN" "Список баз пуст, бэкапить нечего"
    rmdir "$run_dir" 2>/dev/null || true
    exit 0
  fi

  log "INFO" "Найдено баз данных: $(echo "$db_list" | wc -l | tr -d ' ')"

  local db
  for db in $db_list; do
    local dump_file="${run_dir}/${db}.sql"
    log "INFO" "Создание дампа базы '${db}' в ${dump_file}"

    if ! pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -F p -d "$db" -f "$dump_file" >>"$LOG_FILE" 2>&1; then
      log "ERROR" "Дамп базы '${db}' завершился с ошибкой, дальнейшие действия для этой базы отменены"
      rm -f "$dump_file" 2>/dev/null || true
      continue
    fi

    if ! gzip "$dump_file"; then
      log "ERROR" "Не удалось сжать дамп '${dump_file}', удаление и пропуск базы '${db}'"
      rm -f "$dump_file" "${dump_file}.gz" 2>/dev/null || true
      continue
    fi

    log "INFO" "Дамп базы '${db}' создан и сжат"
  done

  if ! ls "${run_dir}"/*.gz >/dev/null 2>&1; then
    log "ERROR" "Нет дампов, архивировать нечего"
    rmdir "$run_dir" 2>/dev/null || true
    exit 1
  fi

  local archive_name="pg_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
  local archive_tmp="${run_dir}/${archive_name}"

  log "INFO" "Сжатие в общий архим ${archive_tmp}"
  if ! tar -czf "$archive_tmp" -C "$run_dir" ./*.gz 2>>"$LOG_FILE"; then
    fail "Не удалось создать архив дампов"
  fi

  log "INFO" "Проверка целостности архива ${archive_tmp}"
  if ! tar -tzf "$archive_tmp" >/dev/null 2>>"$LOG_FILE"; then
    log "ERROR" "Тестирование архива провалилось, архив не перенесён в ${BACKUP_TARGET}"
    rm -f "$archive_tmp" 2>/dev/null || true
    rm -f "${run_dir}"/*.gz 2>/dev/null || true
    rmdir "$run_dir" 2>/dev/null || true
    exit 1
  fi

  local final_archive="${BACKUP_TARGET}/${archive_name}"

  log "INFO" "Переношу архив в ${final_archive}"
  if ! mv "$archive_tmp" "$final_archive"; then
    log "ERROR" "Не удалось перенести архив в ${final_archive}, удаляю временные файлы"
    rm -f "$archive_tmp" 2>/dev/null || true
    rm -f "${run_dir}"/*.gz 2>/dev/null || true
    rmdir "$run_dir" 2>/dev/null || true
    exit 1
  fi

  rm -f "${run_dir}"/*.gz 2>/dev/null || true
  rmdir "$run_dir" 2>/dev/null || true

  log "INFO" "Резервное копирование базы успешно завершено, финальный архив: ${final_archive}"
}

main "$@"
