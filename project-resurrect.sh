#!/bin/bash
#
# Magento Project Resurrect
# Based on mage-tar
#
# author by: Brandon Mikulka <brandon@customerparadigm.com>
# mage-tar author: Rob Simmons <rob.v.simmons@gmail.com>
#
#

# check args
if [ $# -ne 1 ]; then
    echo Usage: "$(basename $0) project"
    echo Exiting
    exit 1
fi

project=$1
docroot=''

db_name="${project}_${USER}"
db_username="ENTER USERNAME"
db_password="ENTER PASSWORD"
server_name="ENTER URL"

# set docroot
docroot=$HOME/public_html/$project


# check if demo user
if [ $USER != 'demo' ];then
    read -p "You are not currently the demo user. This script is for restoring projects to the demo account. This will restore to your account instead. Are you sure you would like to continue, $USER? Type \"yes\" to proceed: " continue_as_user
    if [ "$(echo $continue_as_user | tr '[:upper:]' '[:lower:]')" != "yes" ]; then
        echo Exiting
        exit 1
    fi
fi

# prompt user for docroot
read -p "Enter full path to docroot (leave blank for \"$docroot\"): " user_docroot
if [ "$user_docroot" != "" ]; then
    $docroot=$user_docroot
fi

# check existence of archive file
echo $project
archive="$project-archive.tgz"

if [ ! -f "/graveyard/$archive" ]; then
    echo "Can't find $archive in the graveyard"
    echo Exiting
    exit 2
fi
if [ -d "$docroot" ]; then
    read -p "$docroot already exists. Overwrite? (type \"yes\" to overwrite): " user_do_unarchive
    if [ ! "$(echo "$user_do_unarchive" | tr '[:upper:]' '[:lower:]')" != "yes" ]; then
        rm -rf $docroot
    else
        echo Exiting
        exit 3
    fi
fi

# Grab sudo password so hopefully it won't prompt later
sudo echo ''

cp "/graveyard/$archive" "$HOME/public_html/$archive"

# extract tar to public_html
echo extract resources from a tar into a project...

cd "$HOME/public_html"
echo untarring ...
tar xzf "$archive"
echo done untarring

# htaccess
cd "$docroot"
if [ ! -f '.htaccess' ]; then
    echo 'WARNING: .htaccess was not found in tar'
fi


# Check validity of Media files
if [ -h 'media' ]; then
    if [ ! -e  "media" ]; then
        echo "WARNING: Media files do not exist in '/images/', This may need to be set up manually"
    fi
elif [ -d 'media' ]; then
    sudo chown -R $USER $docroot/media
    sudo chmod 777 -R $docroot/media
else
    echo 'Media files not found... strange, they should have been tarred up!'
fi

#var
if [ ! -d $docroot/var ]; then
    echo creating var directory
    mkdir $docroot/var
fi
sudo chown -R $USER $docroot/var
sudo chmod 777 -R $docroot/var


# Local.xml
echo updating local.xml ...
# echoes out source local.xml, replaces user, password, and DB name, and puts in target app/etc/local.xml
mv $docroot/app/etc/local.xml $docroot/app/etc/local_backup.xml
cat $docroot/app/etc/local_backup.xml | sed s:dbname.*:dbname\>$db_name\<\/dbname\>: | sed s:username.*:username\>$db_username\<\/username\>: | sed s:password.*:password\>$db_password\<\/password\>: > $docroot/app/etc/local.xml
echo done updating local.xml


#Database
echo

if [ -f "$docroot/db.sql" ]; then
  read -p "Create DB (if not exists) $db_name? Type \"yes\" to proceed: " should_do_database

  if [ "$(echo $should_do_database | tr '[:upper:]' '[:lower:]')" == "yes" ]; then
    echo creating schema '(if not exists)'
    mysql -u $db_username -p"$db_password" <<EOL
create schema if not exists $db_name;
EOL

    echo done creating schema '(if not exists)'

    # mysqldump from source | mysql for user

    echo importing database into sql
    pv "$docroot/db.sql" | mysql -u $db_username -p"$db_password" $db_name
    echo done dumping and importing

    # url
    url="http://$USER.$project.$server_name/"
    echo "Using the following URL (for core_config_data): \"$url\")"


    db_table_prefix=$(cat $docroot/app/etc/local.xml | grep table_prefix | sed -r 's:.*table_prefix>(.*)</table_prefix>.*:\1:' | sed -r 's:<!\[CDATA\[(.*)\]\]>:\1:')

    # update core_config_data with correct url
    echo updating core_config_data with url
    mysql -u $db_username -p"$db_password" $db_name <<EOL
update ${db_table_prefix}core_config_data
set value = '$url'
where path in ('web/unsecure/base_url', 'web/secure/base_url') and scope_id = 0;
EOL

    echo 'done updating core_config_data'

  else
    echo "Leaving DB alone"
  fi
else
  echo "db.sql not found in docroot"
fi

# .git Folder
if [ ! -d "$docroot/.git" ]; then
  echo "WARNING: There is no git set up for this project! This should not be the case!"
fi

echo Removing temporary files
rm -rf "$HOME/public_html/$archive"
rm -rf "$docroot/app/etc/local_backup.xml"

echo ""
echo "PLEASE DOUBLE CHECK THAT THERE ARE NO WARNINGS ABOVE!!!!!"
echo "Check that your project now loads and is functional in the browser"
echo "And you can get to the admin"
read -p "If all is good, would you like to remove the archive? Enter the name of the project to delete the archive: " delete_project_archive
if [ "$delete_project_archive" == "$project" ]; then
    echo "Removing Archive"
    rm -rf "/graveyard/$archive"
else
    echo "Archive will remain in /graveyard/$archive"
fi

echo
echo ".__  __              _____  .____    ._______   _______________._.";
echo "|__|/  |_  ______   /  _  \ |    |   |   \   \ /   /\_   _____/| |";
echo "|  \   __\/  ___/  /  /_\  \|    |   |   |\   Y   /  |    __)_ | |";
echo "|  ||  |  \___ \  /    |    \    |___|   | \     /   |        \ \|";
echo "|__||__| /____  > \____|__  /_______ \___|  \___/   /_______  / __";
echo "              \/          \/        \/                      \/  \/";
echo "                                                                  ";
echo "                                                                  ";
echo "                                                                  ";
echo Project Ressurrected
