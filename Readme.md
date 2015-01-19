# Magento Project Kill and Resurrect Scripts
For tarring and backing up magento projects on a server that uses an `http://$USER.$project.$domain_name` domain name.

Uses the following steps when killing:
* Does files-system check on the project
* Dumps the database
* Tars Everything up
* Moves the tar to a "/graveyard/" folder
* Gives option for deleting original files

Uses the following steps when Resurrecting:
* Moves the tar back to `public_html`
* Untars the project
* Creates/Uploads the database
* Changes the `core_config_data` base urls
* Configures the local.xml
* Gives option for removing the archive


Note: this was built for a system with multiple users with a file structure of /home/user/public_html/project_name for the magento root.
