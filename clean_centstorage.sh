#!/bin/bash

##################################################
# CENTREON
#
# Source Copyright 2005-2019 CENTREON
#
# Unauthorized reproduction, copy and distribution
# are not allowed.
#
# For more informations : contact@centreon.com
#
##################################################
DB="centreon_storage"
DB_PATH="/var/lib/mysql/centreon_storage/"
DB_DUMP_FILE_PATH="/tmp/clean_db-$(date +%Y-%m-%d-%H.%M.%S)_$DB"
DB_USER=$1
OPTIMIZE_DB_QUERY="OPTIMIZE table acknowledgements, centreon_acl, comments, customvariables, downtimes, eventhandlers, flappingstatuses, hosts, hoststateevents, hosts_hostgroups, hosts_hosts_dependencies, index_data, issues, logs, log_archive_host, log_archive_last_status, log_archive_service;"
LOG_PATH="/var/log/centreon/clean_dbs.log"
CLEANING_TRANSACTION="BEGIN;

-- Deleting all entries related to hosts/services that are no longer configured
DELETE
FROM acknowledgements
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

DELETE
FROM centreon_acl
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

DELETE
FROM comments
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

DELETE
FROM customvariables
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

DELETE
FROM downtimes
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

DELETE
FROM eventhandlers
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   


DELETE
FROM flappingstatuses
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

DELETE
FROM hosts
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host);


DELETE
FROM hoststateevents
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host);


DELETE
FROM hosts_hostgroups
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host);


DELETE
FROM hosts_hosts_dependencies
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host);

DELETE
FROM issues
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

DELETE
FROM logs
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

DELETE
FROM log_archive_host
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host);

DELETE
FROM log_archive_last_status
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

DELETE
FROM log_archive_service
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

DELETE
FROM notifications
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

DELETE
FROM services
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

DELETE
FROM servicestateevents
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

DELETE
FROM services_servicegroups
WHERE service_id NOT IN ( SELECT service_id FROM centreon.service);

DELETE
FROM services_services_dependencies
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

DELETE
FROM servicestateevents
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   


-- Deleting metrics for unconfigured hosts/services
DELETE
FROM metrics
WHERE index_id IN (
SELECT  id
FROM index_data
WHERE host_id NOT IN (
SELECT  host_id
FROM centreon.host) AND service_id NOT IN (
SELECT  service_id
FROM centreon.service));

-- Deleting index_data pairs that are no longer configured
DELETE
FROM index_data
WHERE host_id NOT IN ( SELECT host_id FROM centreon.host) OR service_id NOT IN ( SELECT service_id FROM centreon.service);   

-- Deleting collected performence data
TRUNCATE TABLE data_bin;

COMMIT;"

help()
{
   # Display Help
   echo "Cleans monitoring data related to hosts/services from old centreon configurations (not in current configuration) "
   echo
   echo "Syntax: clean_centreon_storage [h]"
   echo "options:"
   echo "h     Print this Help."
   echo
}

clean(){
    echo -e "Deleting all collected metrics and all entries related to hosts/services that are no longer configured (BAM & MBI excluded)..."
    mysql --user="$DB_USER" --database="$DB" --execute="$CLEANING_TRANSACTION" > $LOG_PATH

    if [ $? -ne 0 ]; then
        echo -e "$(date +%Y-%m-%d-%Hh%Mm%Ss) [ERROR] Cleaning failed..."
        exit -1
    else
        echo -e "Cleaning of $DB successfully done !"
        return 0
     fi
}


reclaim_space(){

    ORIGINAL_SIZE=$(du --block-size=1 $DB_PATH | cut -d "/" -f1 )

    echo -e "Reclaming space from disk..."
    mysql --user="$DB_USER" --database="$DB" --execute="$OPTIMIZE_DB_QUERY" > $LOG_PATH

    if [ $? -ne 0 ]; then
        echo -e "$(date +%Y-%m-%d-%Hh%Mm%Ss) [ERROR] Reclaming space from disk failed."
        exit -1
    else
        echo -e "Reclaming disk space successfully done !"
        FINAL_SIZE=$(du --block-size=1 $DB_PATH | cut -d "/" -f1)

        SAVED_SPACE=$(($ORIGINAL_SIZE-$FINAL_SIZE))

        echo -e "$(numfmt --to=iec-i --suffix=B $SAVED_SPACE) saved"

        return 0
     fi


}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

clean
reclaim_space

echo -e "Finished !"