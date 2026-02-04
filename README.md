-PostgreSQL backup script.
Скрипт делает бэкап всех баз PostgreSQL, кладёт дампы в gzip-архив, проверяет его и переносит в `/backups`.

-Требования к выполнению:
bash.
PostgreSQL client (psql, pg_dump).
Доступ к кластеру PostgreSQL, по указанным параметрам подключения.
Права на запись в каталоги `/var/backups/pg` и `/backups`.
Права на запись в лог-файл (по умолчанию `/var/log/pg_backup.log`).

-Переменные окружения:
`PGHOST`- хост PostgreSQL (по умолчанию `localhost`).
`PGPORT` - порт PostgreSQL (по умолчанию `5432`).
`PGUSER` - пользователь PostgreSQL (по умолчанию `postgres`).
`BACKUP_ROOT`-  каталог для временных файлов (по умолчанию `/var/backups/pg`).
`BACKUP_TARGET` - конечный каталог для архивов (по умолчанию `/backups`).
`LOG_FILE`- путь к лог-файлу (по умолчанию `/var/log/pg_backup.log`).


-Запуск руками:
chmod +x /usr/local/sbin/pg_backup.sh
PGHOST=db.example.org PGUSER=backup PGPASSWORD='secret' \
  BACKUP_TARGET=/backups \
  LOG_FILE=/var/log/pg_backup.log \
  /usr/local/sbin/pgbackup.sh

-Настройка кронджобы:
crontab -e

-Пример ежедневного запуска в 04:21:
21 4 * * * PGHOST=db.example.org PGUSER=backup PGPASSWORD='secret' BACKUP_TARGET=/backups LOG_FILE=/var/log/pg_backup.log /usr/local/sbin/backup_postgres.sh

-Проверка результата работы скрипта:
Проверить лог-файл на ошибки, и есть ли сообщение об успешном завершении.
Убедиться, что в /backups появился новый архив, с названием типа pg_backup_YYYYMMDD_HHMMSS.tar.gz.
Распаковать архив в отдельный каталог, и убедиться, что внутри лежат дампы баз в формате.sql.gz.
