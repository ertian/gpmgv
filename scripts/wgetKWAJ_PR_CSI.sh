#!/bin/sh
#
################################################################################
#
#  wgetKWAJ_PR_CSI.sh     Morris/SAIC/GPM GV     December 2008
#
#  DESCRIPTION
#    Retrieves KWAJ CSI subset PR files from DAAC site:
#       disc2.nascom.nasa.gov/data/s4pa
#
#  ROUTINES CALLED
#
#  FILES
#
#  DATABASE
#    Catalogs data in 'orbit_subset_products' table in 'gpmgv' database in
#    PostGRESQL via call to psql utility.  Tracks status of file retrieval
#    in 'appstatus' table.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    wgetKWAJ_PR_CSI.YYMMDD.log in data/logs subdirectory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to
#      PostGRESQL database 'gpmgv', and INSERT privilege on table. 
#    - Utility 'psql' must be in user's $PATH.
#    - User must have write privileges in $DATA_DIR and its subdirectories
#
#  HISTORY
#    December 2008 - Morris - Created.
#    March 2012    - Morris - Modified to retrieve only V7 files and handle
#                             YYYYMMDD in the filename convention.
#    June 2012     - Morris - Write TRMM Version to the database to override
#                             table column default value of 6.
#    November 2013 - Morris - Using >> rather than "| tee -a" to capture any
#                             psql error output in data load query.
#
################################################################################

GV_BASE_DIR=/home/gvoper
DATA_DIR=/data/gpmgv
PR_BASE=${DATA_DIR}/prsubsets
TMP_KWAJ_DATA=${DATA_DIR}/tmp/PR_KWAJ_DAAC
DIR_PRE=${TMP_KWAJ_DATA}/TRMM_
DIR_POST='_CSI_KWAJ/'
BIN_DIR=${GV_BASE_DIR}/scripts
LOG_DIR=${DATA_DIR}/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/wgetKWAJ_PR_CSI.${rundate}.log
export LOG_FILE
LOG_DATA_FILE=${LOG_DIR}/KWAJ_PR_CSI_newfiles.${rundate}.log
PATH=${PATH}:${BIN_DIR}
ZZZ=1800

umask 0002

# re-usable file to hold output from database queries
DBTEMPFILE=${TMP_KWAJ_DATA}/dbtempfile
# file listing all yymmdd to be processed this run
FILES2DO=${TMP_KWAJ_DATA}/DatesToGet
rm -f $FILES2DO
# file listing status of each date's download attempts
THE_SCOOP=${TMP_KWAJ_DATA}/DateStatus
rm -f $THE_SCOOP

# Constants for possible status of downloads, for appstatus table in database
UNTRIED='U'    # haven't attempted initial download yet
SUCCESS='S'    # got the desired file
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed Nth round of tries, no more attempts
DUPLICATE='D'  # prior attempt was successful as file exists, but db was in error
INCOMPLETE='I' # got fewer than all 4 PR files for an orbit

have_retries='f'  # indicates whether we have missing prior filedates to retry
status=$UNTRIED   # assume we haven't yet tried to get current file

today=`date -u +%Y%m%d`
echo "===================================================" | tee $LOG_FILE
echo " Attempting download of KWAJ CSI PR files on $today." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 3 ]
  then
    thistime=`date -u`
    echo "Message from wgetKWAJ_PR_CSI.sh cron job on ${thistime}:" \
      > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "${pgproccount} Postgres processes active, should be 3 !!" \
      >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ws1-gpmgv' makofski@radar.gsfc.nasa.gov \
      -c kenneth.r.morris@nasa.gov < /tmp/PG_MAIL_ERROR_MSG.txt
    cat /tmp/PG_MAIL_ERROR_MSG.txt | tee -a $LOG_FILE
    exit 1
  else
    echo "${pgproccount} Postgres processes active, should be 3." \
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi
#exit  #uncomment for just testing e-mail notifications


# DEFINE FUNCTIONS

################################################################################
function wgetPRtypes4date() {

     # Use wget to download PR KWAJ subsets for each type from DAAC ftp site. 
     # Repeat attempts at intervals of $ZZZ seconds if file(s) not retrieved in
     # first attempt.  If file is still not found, record the failure in the
     # log file and do not increment $found variable.

 declare -i tries=0
 declare -i found=0
 ZZZ=1
 ftploc=disc2.nascom.nasa.gov/data/s4pa

 for type in 1C21 2A23 2A25 2B31
   do
     runagain='y'
     while [ "$runagain" != 'n' ]
       do
          tries=tries+1
          echo "Try = ${tries}, max = 5." | tee -a $LOG_FILE

          # select the proper directory subtree for the product type
          case $type in
                           1C21 )  LDIR='TRMM_L1' ;;
             2A23 | 2A25 | 2B31 )  LDIR='TRMM_L2' ;;
                              * )  ;;
          esac

          # limit new retrievals to Version 7 files (YYYYMMDD datestamps)
          wget -P $2 -N \
            ftp://${ftploc}/${LDIR}/TRMM_${type}_CSI_KWAJ/$1/${type}*.*$3.*.KWAJ.7.HDF.Z
          filelist4type=`ls $2/${type}*.*$3.*.KWAJ.7.HDF.Z`
          if [ $? != 0 ]
            then
               if [ $tries -eq 2 ]
                 then
                    runagain='n'
                    echo "Failed after 2 tries, giving up." | tee -a $LOG_FILE
                 else
                    echo "Failed to get file, sleeping $ZZZ s before next try."\
	              | tee -a $LOG_FILE
                    sleep $ZZZ
               fi
            else
               runagain='n'
               found=found+1
          fi
     done
     tries=0
     sleep 2
 done
 return $found
}
################################################################################
function PRproductsToDB() {

   # satid is the id of the instrument whose data file products are being
   # mirrored and is used to identify the orbit product files' data source
   # in the gpmgv database
    satid="PR"

   # catalog the files in the database - need separate logic for the GPM_KMA
   # subset files, as they have a different naming convention
    for type in 1C21 2A23 2A25 2B31
      do
        for file in `ls ${type}*.*$1.*`
          do
           #  Check for presence of downloaded files, process if any
	    if [ -s  $2/${type}/${file} ]  # check existence in the baseline directory
	      then
	        echo "File $2/${type}/${file} already exists.  Skip cataloging."\
		  | tee -a $LOG_FILE 2>&1
		rm -v ${file}  | tee -a $LOG_FILE 2>&1
            else
	        dateString=`echo $file | cut -f2 -d '.' | awk \
                  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)}'`
                orbit=`echo $file | cut -f3 -d '.'`
                echo $file | grep "GPM_KMA" > /dev/null
                if  [ $? = 0 ]
                  then
                    subset='GPM_KMA'
                    version=`echo $file | cut -f4 -d '.'`
                  else
	            temp1=`echo $file | cut -f4 -d '.'`
	            temp2=`echo $file | cut -f5 -d '.'`
	            # The product version number precedes (follows) the subset ID
	            # in the GPMGV (baseline CSI) product filenames.  Find which of
	            # temp1 and temp2 is the version number.
	            expr $temp1 + 1 > /dev/null 2>&1
	            if [ $? = 0 ]   # is $temp1 a number?
	              then
	                version=$temp1
		        subset=$temp2
	              else
	                expr $temp2 + 1 > /dev/null 2>&1
		        if [ $? = 0 ]   # is $temp2 a number?
		          then
		            subset=$temp1
		            version=$temp2
		          else
		            echo "Cannot find version number in PR filename: $file"\
		              | tee -a $LOG_FILE
		            exit 2
	    	        fi
	            fi
                fi
	        echo "subset ID = $subset" | tee -a $LOG_FILE
                #echo "file = ${file}, dbdate = ${dateString}, orbit = $orbit"
	        echo "INSERT INTO orbit_subset_product VALUES \
('${satid}',${orbit},'${type}','${dateString}','${file}','${subset}',${version});" \
	        | psql -a -d gpmgv  >> $LOG_FILE 2>&1
	       # move file into the baseline PR product directory
	        mv -v $file $2/${type} | tee -a $LOG_FILE
	       # tally the PR file in the data log file - filename must be 2nd 'word'
	       # to match the mirror log file to which data log will be appended
	        echo "Got $file" | tee -a $3
               echo "" | tee -a $LOG_FILE
	    fi
        done
    done
    return
}
################################################################################

# BEGIN MAIN SCRIPT

#  Get the date string for desired day's date by calling offset_date.
ctdate=`offset_date $today -2`

#  Get the Julian representation of ctdate: YYYYMMDD -> YYYYjjj
julctdate=`ymd2yd $ctdate`

#  Get the subdirectory on the ftp site under which our day's data are located,
#  in the format YYYY/jjj
jdaydir=`echo $julctdate | awk '{print substr($1,1,4)"/"substr($1,5,3)}'`

#  Trim date string to use a 2-digit year, as in filename convention
yymmdd=`echo $ctdate | cut -c 3-8`

echo "Getting KWAJ CSI PR files for date $yymmdd" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "Checking whether we have an entry for this date in database."\
  | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus WHERE \
 app_id = 'wgetKWAJ' AND datestamp = '$yymmdd';" | psql -a -d gpmgv \
 | tee -a $LOG_FILE 2>&1

if [ -s ${DBTEMPFILE} ]
  then
     # We've tried to get this day's files before, check our past status.
     status=`cat ${DBTEMPFILE} | cut -f5 -d '|'`
     echo "" | tee -a $LOG_FILE
     echo "Have status=${status} from prior attempt." | tee -a $LOG_FILE
  else
     # Empty file indicates no row exists for this file datestamp, so insert one
     # now with defaults for first_attempt and ntries columns
     echo "" | tee -a $LOG_FILE
     echo "No prior attempt, initialize status in database:" | tee -a $LOG_FILE
     echo "INSERT INTO appstatus(app_id,datestamp,status) VALUES \
      ('wgetKWAJ','$yymmdd','$UNTRIED');" | psql -a -d gpmgv \
      | tee -a $LOG_FILE 2>&1
fi

echo "" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "Checking whether we have prior missing datestamps to process."\
  | tee -a $LOG_FILE

echo "Check for actual prior attempts which failed for external reasons:"\
  | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus \
      WHERE app_id = 'wgetKWAJ' \
        AND status IN ('$MISSING','$UNTRIED','$INCOMPLETE') \
        AND datestamp != '$yymmdd';" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
if [ -s ${DBTEMPFILE} ]
  then
    echo "Dates of prior MISSING:" | tee -a $LOG_FILE
    for filemsg in `cat ${DBTEMPFILE} | cut -f3 -d '|'`
      do
        echo $filemsg | tee -a $LOG_FILE
	echo "$filemsg" >> $FILES2DO
    done
  else
    echo "No prior dates with status MISSING." | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "Check for prior dates never attempted due to local problems:"\
  | tee -a $LOG_FILE
# Do so by looking for a gap in dates of >1 between last attempt registered
# in the database, and the current attempt date

STAMPLAST=`psql -q -t -d gpmgv -c "SELECT MAX(datestamp) FROM appstatus WHERE \
 app_id = 'wgetKWAJ' AND datestamp != '$yymmdd';" | sed 's/ //g'`

#echo "${STAMPLAST}" | tee -a $LOG_FILE
# set STAMPLAST to $yymmdd if NO HITS from database
if [ "${STAMPLAST}" = "" ]
  then
    STAMPLAST=$yymmdd
#    echo "setting STAMPLAST"
fi
echo "Last date previously attempted was ${STAMPLAST}" | tee -a $LOG_FILE
#echo "" | tee -a $LOG_FILE
DATELAST=`echo 20$STAMPLAST | sed 's/ //'`
#echo DATELAST=$DATELAST
DATEGAP=`grgdif $ctdate $DATELAST`
#echo DATEGAP=$DATEGAP
#exit
if [ `expr $DATEGAP \> 1` = 1 ]
  then
     while [ `expr $DATEGAP \> 1` = 1 ]
       do
         DATELAST=`offset_date $DATELAST 1`
         yymmddNever=`echo $DATELAST | cut -c 3-8`
         echo "No prior attempt of $yymmddNever, initialize status in database:"\
           | tee -a $LOG_FILE
         echo "INSERT INTO appstatus(app_id,datestamp,status) VALUES \
           ('wgetKWAJ','$yymmddNever','$UNTRIED');" | psql -a -d gpmgv \
           | tee -a $LOG_FILE 2>&1
         # add this date to the temp file, preceded by bogus '|'-delimited values
         # so the format is compatible with the MISSING dates query output
         echo "$yymmddNever" >> $FILES2DO
         DATEGAP=`grgdif $ctdate $DATELAST`
         echo "" | tee -a $LOG_FILE
     done
  else
    echo "No gaps found in dates processed."
fi

if [ -s $FILES2DO ]
  then
     echo "" | tee -a $LOG_FILE
     echo "Need to retry downloads for missing file dates below:" \
       | tee -a $LOG_FILE
     cat $FILES2DO | tee -a $LOG_FILE
  else
#     echo "" | tee -a $LOG_FILE
     echo "No missing prior dates found." | tee -a $LOG_FILE
     if [ $status = $SUCCESS ]
       then
	  echo "All KWAJ CSI acquisition seems up-to-date, exiting."\
	   | tee -a $LOG_FILE
	  exit 0
     fi
fi

if [ ${status} != $SUCCESS ]
  then
    echo "$yymmdd" >> $FILES2DO
fi

echo "" | tee -a $LOG_FILE
echo "Dates to process this run:" | tee -a $LOG_FILE
cat $FILES2DO | tee -a $LOG_FILE
#exit

# increment the ntries column in the appstatus table for $MISSING, 
# $UNTRIED, $INCOMPLETE cycles
echo "" | tee -a $LOG_FILE
echo "UPDATE appstatus SET ntries=ntries+1 WHERE app_id = 'wgetKWAJ' AND \
 status IN ('$MISSING','$UNTRIED','$INCOMPLETE');" \
# | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE

cd $TMP_KWAJ_DATA

if [ -s $FILES2DO ]
  then
    echo "Getting KWAJ CSI files." | tee -a $LOG_FILE
    for fdate in `cat $FILES2DO`
      do
        #  Get the Julian representation of date: YYYYMMDD -> YYYYjjj
        julctdate=`ymd2yd 20${fdate}`
        #  Get the subdirectory on the ftp site under which our day's data are located,
        #  in the format YYYY/jjj
        jdaydir=`echo $julctdate | awk '{print substr($1,1,4)"/"substr($1,5,3)}'`
        echo "Get files for ${jdaydir} from ftp site." | tee -a $LOG_FILE
        wgetPRtypes4date $jdaydir $TMP_KWAJ_DATA $fdate
        if [ $? -eq 4 ]
          then
            echo "Got all 4 types for $fdate"
            echo "Mark success in database:" | tee -a $LOG_FILE
            echo "" | tee -a $LOG_FILE
	    echo "UPDATE appstatus SET status = '$SUCCESS' WHERE \
	          app_id = 'wgetKWAJ' AND datestamp = '$fdate';" \
		  | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
            # Move the files into the baseline product directories
            # and catalog them in the database.
            echo "" | tee -a $LOG_FILE
            echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%" | tee -a $LOG_FILE
            PRproductsToDB $fdate $PR_BASE $LOG_DATA_FILE
            echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%" | tee -a $LOG_FILE
        else
            echo "" | tee -a $LOG_FILE
            echo "Only got $? of the 4 types for $fdate" | tee -a $LOG_FILE
            echo "Mark incomplete in database:" | tee -a $LOG_FILE
            echo "" | tee -a $LOG_FILE
	    echo "UPDATE appstatus SET status = '$INCOMPLETE' WHERE \
	          app_id = 'wgetKWAJ' AND datestamp = '$fdate';" \
		  | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
        fi
    done
fi

# set status to $FAILED in the appstatus table for $MISSING rows where ntries
# reaches 5 times.  Don't want to continue for too many days if file is missing.
echo "" | tee -a $LOG_FILE
echo "Set status to FAILED where this is the 5th failure for any downloads:"\
 | tee -a $LOG_FILE
echo "UPDATE appstatus SET status='$FAILED' WHERE app_id = 'wgetKWAJ' AND \
 status='$MISSING' AND ntries > 4;" | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1



echo "" | tee -a $LOG_FILE
echo "================== END OF RUN =====================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit
