#!/bin/bash
#
# Magento Project Kill
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

# check if demo user
if [ $USER != 'demo' ];then
    read -p "You are not currently the demo user. This script is for backing up projects from the demo account. Are you sure you would like to continue?, $USER? Type \"yes\" to proceed: " continue_as_user
    if [ "$(echo $continue_as_user | tr '[:upper:]' '[:lower:]')" != "yes" ]; then
        echo Exiting
        exit 1
    fi
fi


# attempt to pre-determine docroot
if [ -d $HOME/public_html/$project ]; then
    # server
    docroot=$HOME/public_html/$project
fi

# prompt user for docroot
read -p "Enter full path to docroot (leave blank for \"$docroot\"): " user_docroot
if [ "$user_docroot" != "" ]; then
    docroot=$user_docroot
fi

# check if archive exists
if [ -f "/graveyard/$project-archive.tgz" ]; then
    echo
    echo "Archive exists already exists!"
    read -p "Would you like to override the old archive, '$project'? Type \"yes\" to proceed: " delete_archive
    if [ "$(echo $delete_archive | tr '[:upper:]' '[:lower:]')" != "yes" ]; then
        echo Exiting
        exit 3
    fi
fi

# check existence of docroot and app/Mage.php
if [ ! -d "$docroot" ]; then
    echo "can't find $docroot"
    echo Exiting
    exit 4
elif [ ! -f "$docroot/app/Mage.php" ]; then
    echo "can't find $docroot/app/Mage.php"
    echo Exiting
    exit 5
fi
if [ ! -f "$docroot/app/etc/local.xml" ]; then
    echo "can't find $docroot/app/etc/local.xml"
    echo Exiting
    exit 6
fi
cd $docroot
#Check everything has been committed to git
if [ ! -d "$docroot/.git" ]; then
    echo "Git has not been initialized for this project, you should fix that first"
    echo Exiting
    exit 7
fi

if [ "$(git status -s)" ]; then
    echo "There are uncommitted changes in the repository. Please deal with them first"
    echo Exiting
    exit 7
fi

# Check everything has been pushed to git (Develop and master)
git fetch

if [ "$(git log origin/develop..develop)" ]; then
    echo "You have not pushed everything from the develop branch to origin"
    echo Exiting
    exit 7
fi
if [ "$(git log origin/master..master)" ]; then
    echo "You have not pushed everything from the master branch to origin"
    echo Exiting
    exit 7
fi


#change ownership of all files to ensure a successfull tar
owner=$(stat -c '%U' $docroot)
if [ "$USER" != "$owner" ]; then
    echo "You must be $owner to archive this project"
    echo Exiting
    exit 8
fi
sudo chown -R "$owner": "$docroot"

# create tar from docroot
echo create archive tar from a project...

# parse creds
echo parsing creds from local.xml...
local_xml="$docroot/app/etc/local.xml"
db_user=$(cat $local_xml | grep username | sed -r 's:.*username>(.*)</username>.*:\1:' | sed -r 's:<!\[CDATA\[(.*)\]\]>:\1:')

db_pass=$(cat $local_xml | grep password | sed -r 's:.*password>(.*)</password>.*:\1:' | sed -r 's:<!\[CDATA\[(.*)\]\]>:\1:')

db_name=$(cat $local_xml | grep dbname | sed -r 's:.*dbname>(.*)</dbname>.*:\1:' | sed -r 's:<!\[CDATA\[(.*)\]\]>:\1:')
echo done parsing creds from local.xml


# dump db to sql file, using parsed creds

echo dumping db...
mysqldump -u $db_user -p"$db_pass" $db_name | pv > db.sql
echo done dumping db


# tar it up
cd .. #In public_html dir
resource_basename="$project-archive"
tarname="$resource_basename.tgz"
echo creating tgz...
tar -czf "$tarname" "$project"
mv $tarname /graveyard/
echo done creating tgz

echo
echo Created /graveyard/$tarname
echo Project Successfully Archived


# remove the project and database
echo
read -p "Would you like to remove the project '$project'? Type \"yes\" to proceed: " DELETE_PROJECT
if [ "$(echo $DELETE_PROJECT | tr '[:upper:]' '[:lower:]')" == "yes" ]; then

    echo Removing the project...
    rm -rf $project

    echo Dropping the database...
    mysql -u $db_user -p"$db_pass" <<EOL
DROP DATABASE ${db_name}
EOL

    echo "            .--. .-,       .-..-.__"
    echo "          .'(\`.-\` \_.-'-./\`  |\\_( \"\\__"
    echo "       __.>\ ';  _;---,._|   / __/\`'--)"
    echo "      /.--.  : |/' _.--.<|  /  | |"
    echo "  _..-'    \`\\     /' /\`  /_/ _/_/"
    echo "   >_.-\`\`-. \`Y  /' _;---.\`|/))))"
    echo "  '\` .-''. \\|:  \\.'   __, .-'\"\`"
    echo "   .'--._ \`-:  \\/:  /'  '.\             _|_"
    echo "       /.'\`\\ :;   /'      \`-           \`-|-\`"
    echo "      -\`    \|   \|                      |"
    echo "            :.; : |                  .-'~^~\`-."
    echo "            |:    |                .' _     _ \`."
    echo "            |:.   |                | |_) | |_) |"
    echo "            :. :  |                | | \ | |   |"
    echo "          .   . : ;                |           |"
    echo "  -.\"-/\\\\\\/:::.    \`\\.\"-._'.\"-\"_\\\\-|           |///.\"-"
    echo "  \" -.\"-.\\\\\"-.\"//.-\".\`-.\"_\\\\-.\".-\\\\\`=.........=\`//-\"."
fi


echo Project Killed

