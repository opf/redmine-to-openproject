Also check out all the repos in the subfolders (redmine, chiliproject, openproject).
See README.txt for the respective SHAs.
Every project includes a .ruby-version file with the required ruby version.

Run the migration script from `./redmine`:

```
bash --login rm_to_op-migration/migration.sh
```

NOTE
----

Each migration is fairly different. Each data set has its own problems.
But this project gives you a rough idea what the steps are to get from Redmine to OpenProject.
In short:

1) Downgrade from Redmine to Chiliproject 2.4.0.
2) Upgrade from ChiliProject 2.4.0 to OpenProject 7.4.2 (which here includes some fixes to make the migration work).
3) Upgrade to latest OpenProject (8.2).

The given script in this folder won't work out of the box.
You need to configure the same database for all projects (redmine, chiliproject, openproject).