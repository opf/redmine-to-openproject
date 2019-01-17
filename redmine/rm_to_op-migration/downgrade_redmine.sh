MYSQL_HOST_OPTION="-h 127.0.0.1"
MYSQL_DB="rm_to_op"

MYSQL_PWD=root mysql -uroot $MYSQL_HOST_OPTION -D $MYSQL_DB <<EOF
  -- fix attachments downgrade by removing NULL values
  UPDATE attachments SET
    container_id = 0,
    container_type = ''
  WHERE
    container_id IS NULL AND container_type IS NULL;
EOF

if [ $? = 0 ]; then
  echo '1) Fixed null attachments'
else
  echo Failed to fix null attachments
  exit 1
fi

echo '2) Rolling back migrations...'

if ! ruby --version | grep 2.1.10 &>/dev/null; then
  echo "Error: expected Ruby 2.1.10" && exit 1
  # if rvm is present use that to switch to the correct version:
  # source ~/.rvm/scripts/rvm && rvm use ruby-2.1.10
fi

# rollback all the way down to just after
# 20110401192910_add_index_to_users_type.rb
# which is a shared state between redmine and OpenProject
bundle exec rake db:rollback STEP=50
