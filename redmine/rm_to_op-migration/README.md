# Redmine-to-OpenProject Migration Steps

1) Restore dump to mysql/postgres database

3) Downgrade to shared redmine/chiliproject/openproject state
   by running downgrade_redmine.sh in fixed redmine-2.6 branch
4) Run `bundle exec rake db:migrate` in chiliproject 2.4.0
5) Run `bundle exec rake db:migrate` in openprojet-ce (stable/8)
   which will fail because of existing version and project attachments.
6) Run `bundle exec rake migrations:attachments:move_to_wiki`
7) Run `bundle exec rake db:migrate` in openprojet-ce (stable/8)
8) Run post-migration fixes in openproject-ce (stable/8):
   > bundle exec rails console
   >> load './post_migration_fixes.rb'
   >> apply_fixes!

9) On the server copy the attachments and migrate them:

```
   sudo cp /tmp/openproject/files/* /tmp/openproject/files/*/**/* /var/db/openproject/files/

   sudo openproject run rake migrations:attachments:move_old_files
```
10) Delete all work package notification delayed jobs which were created during the migration:

```
Delayed::Job.where("handler LIKE '%WorkPackageNotification%'").delete_all
```
