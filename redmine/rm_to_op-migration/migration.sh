set -e

echo "[$(date)] Starting migration ..."

SECONDS=0

if [ ! "$PWD" = "*/migrate_from_redmine/redmine" ]; then
  echo 'Run the script from within the redmine root folder via `bash --login rm_to_op-migration/migration.sh`!'
  exit 1
fi

echo "1/8) Importing original dump"
bash rm_to_op-migration/reset_dump.sh

echo "2/8) Rolling back to chiliproject schema"
bash --login rm_to_op-migration/downgrade_redmine.sh

echo "3/8) Migrating back up to chiliproject 2.4.0"
cd ../chiliproject

# if ! ruby --version | grep 2.1.10 &>/dev/null; then
  # source ~/.rvm/scripts/rvm && rvm use ruby-2.1.10
# fi

bundle exec rake db:migrate

echo "4/8) Migrating up to OpenProject 7.4.2"
cd ../openproject/migration-openproject-ce
# source ~/.rvm/scripts/rvm
# rvm use ruby-2.4.2

source .env.db # defines DATABASE_URL for migration-openproject-ce

bundle exec rake db:migrate || echo "ok" # fails due to version/project attachments
bundle exec rake migrations:attachments:move_to_wiki
bundle exec rake db:migrate

echo "5/8) Finishing touches..."
bundle exec rails runner 'load("./post_migration_fixes.rb"); puts "applying fixes"; apply_fixes!'

echo "6/8) Final migration to stable/8"
cd ../openproject-ce
source .env.db # defines DATABASE_URL for openproject-ce

bundle exec rake db:migrate

echo "7/8) Final finishing touches..."
bundle exec rails runner 'load("./post_migration_fixes.rb"); puts "applying fixes"; apply_fixes!'

echo "8/8) Dumping migrated database..."
FILE_NAME=`date '+rm_to_op-migrated-%Y-%m-%d.sql'`
mysqldump --hex-blob -uroot -proot -h 127.0.0.1 rm_to_op > rm_to_op-migration/data/$FILE_NAME
cd rm_to_op-migration/data
tar -czf $FILE_NAME.tar.gz $FILE_NAME

echo "[$(date)] Finished migration after $(($SECONDS / 60 / 60))h$(( ($SECONDS % 3600) / 60 ))m)."
