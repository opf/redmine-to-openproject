# Using MySQL 5.6 in a docker image.
# Deletes all changesets to speed up following migrations massively.
# The changesets can simply be reimported once the migration is complete.

DB_NAME="rm_to_op"
DUMP_FILE="redmine_dump.sql"

echo "drop database $DB_NAME; create database $DB_NAME;" | mysql -uroot -proot -h 127.0.0.1 && \
  mysql -uroot -proot -h 127.0.0.1 -D $DB_NAME < rm_to_op-migration/data/$DUMP_FILE && \
  echo "delete from changes; delete from changeset_parents; delete from changesets_issues; delete from changesets;" \
  | mysql -uroot -proot -h 127.0.0.1 wuh_migrated && \
  echo "Restored $DUMP_FILE to $DB_NAME and trimmed changesets."
