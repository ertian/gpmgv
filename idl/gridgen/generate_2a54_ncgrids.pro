;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION
;       Reads rain type grids from a 2A-54 GV radar file, resamples the
;       2 km resolution grid to 4 km, and writes the 4km grid to the supplied
;       GV netCDF file.  Also writes the GV site ID and lat/lon location
;       to the netCDF file.
;
; AUTHOR:
;       Bob Morris, NASA/GSFC, GPM GV (SAIC)
;
; HISTORY:
;       6/2007 by Bob Morris, GPM GV (SAIC)
;       - Created from generate_2a55_ncgrids.pro routine
;       12/2009 by Bob Morris, GPM GV (SAIC)
;       - Modified parsing of file name to accommodate prefix prepended onto the
;         2A54 file copy.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro generate_2a54_ncgrids, file_2A54, ncgvfile

common groundSite, event_num, siteID, siteLong, siteLat
common time,       event_time, volscantime, orbit

; 'Include' file for grid dimensions, spacings
@grid_def.inc

; We need the following to prepare analyzed output for REBINing to NX x NY grid.
; Must have a grid whose dimensions are even multiples of NX and NY.
x_cut = (NX * REDUCFAC) - 1  ; upper x array index to extract from hi-res grid
                             ; prior to REBINning to NX x NY grid
y_cut = (NY * REDUCFAC) - 1  ; as for x_cut, but upper y array index


;
; Open the netcdf file for writing, and fill passed/common parameters
;
ncid = NCDF_OPEN( ncgvfile, /WRITE )
NCDF_VARPUT, ncid, 'site_ID', siteID
NCDF_VARPUT, ncid, 'site_lat', siteLat
NCDF_VARPUT, ncid, 'site_lon', siteLong

convStratFlag=intarr(151,151,20)  ; just define with any value and dimension 
;
; Read 2a54 raintype and volume scan times
; and parse date information from input 2a54 file name
;
read_2a54, file_2a54, STORMTYPE=convStratFlag, hour, minute, second

;help, convStratFlag

; -- Re-gridding 2a54 to 4x4 km^2 using nearest neighbor (/SAMPLE) option.
; -- Extract an even number of horizontal points (150) for REBINning to 75x75

; CURRENT GPM GV VALIDATION NETWORK 2A54 FILE IS LIMITED TO ONE VOLUME.
; OTHERWISE, WE WOULD HAVE TO WORK THRU THE VOLUME SCAN TIMES HERE TO FIND THE
; ONE COINCIDENT WITH THE PR OVERPASS TIME, WHICH WOULD HAVE TO BE PASSED INTO
; THIS ROUTINE. OTHER POSSIBILITIES ARE TO OBTAIN THE COINCIDENT VOLUME FROM
; THE 2A-52 PRODUCT, OR FROM MATCHING THE VOS TIME METADATA IN THE gpmgv
; DATABASE TO THE SITE OVERPASS TIME AND INCLUDING THE CORRESPONDING VOLUME
; NUMBER IN THE CONTROL FILE INFORMATION

nvol = 0

convStratFlag_new = convStratFlag[0:x_cut,0:y_cut,nvol]
convStratFlag_new = REBIN(convStratFlag_new, NX, NY,/SAMPLE)

NCDF_VARPUT, ncid, 'convStratFlag', convStratFlag_new  ; grid data
NCDF_VARPUT, ncid, 'have_convStratFlag', DATA_PRESENT  ; data presence flag

; -- get the yr (yy), mon, day of the volscan from the filename
file_only_2a54 =  file_basename(file_2a54)
len_file_only_2a54 = STRLEN(file_only_2a54)
startpos = strpos(file_only_2a54,'2A54.')+6
file_fields2get = STRMID(file_only_2a54,startpos,len_file_only_2a54-startpos)

void = ' '
site = ' '
year = ' '  
month = 0  & day = 0

reads, file_fields2get, year, month, day, site, $
       format='(i2,i2,i2,3x,a4)'

; -- get the hr, min, and sec fields of our volume scan = nvol
hrs = hour[nvol]
min = minute[nvol]
sec = second[nvol]

  if hrs ne -99 then begin
    dtimestring = fmtdatetime(year, month, day, hrs, min, sec)
    print, file_only_2a54,"|",dtimestring,"+00"
  endif else begin
    dtimestring = '1970-01-01 00:00:00'
    print, file_only_2a54,"|",dtimestring,"+00"
  endelse

dateparts = strsplit(dtimestring, '-', /extract)
yyyy = dateparts[0]
;print, "yr mo day hrs min sec: ", yyyy, month, day, hrs, min, sec

voltimeticks = unixtime(long(yyyy), long(month), long(day), hrs, min, sec)
volscantime = voltimeticks
;print, "UNIX time ticks at volscan begin = ", voltimeticks
;NCDF_VARPUT, ncid, 'beginTimeOfVolumeScan', voltimeticks
;NCDF_VARPUT, ncid, 'abeginTimeOfVolumeScan', dtimestring

NCDF_CLOSE, ncid

end

@read_2a54.pro
@unixtime.pro
