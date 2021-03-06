;===============================================================================
;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; extract_site_soundings_from_grib.pro -- Morris/SAIC/GPM_GV  May 2012
;
; DESCRIPTION
; -----------
; Reads isobaric temperature, relative humidity (RH), and u- and v-wind speeds
; from a user-selected North American Mesoscale Analysis (NAMANL) model analysis
; GRIB format data file, and extracts model soundings at locations defined by
; the input latitude and longitude arrays (lat_arr and lon_arr).
;
; Requires IDL Version 8.1 or greater, with built-in GRIB read/write utilities.
;
; PARAMETERS
; ----------
; gribfiles - string array, holding fully qualified path/names of the NAM/NAMANL
;             GRIB files to read.  First file is the soundings data, 2nd file is
;             the 6h precip accumulation forecast from 6 hours prior to the
;             soundings analysis, and 3rd file is the 3h precip forecast from 6
;             hours prior to the soundings analysis.  The 0-3h forecast is only
;             needed when the 6h forecast is from the 06Z or 18Z cycle, which
;             only gives a 3-6h precipitation accumulation forecast.  The 6h
;             forecast from the 00Z and 12Z cycles gives the full 0-6h precip.
; site_arr  - array of strings holding the IDs of the sites where soundings are
;             to be computed
; lat_arr   - array of latitudes for the sites in site_arr, decimal degrees N
; lon_arr   - array of longitudes for the sites in site_arr, decimal degrees E
; savefile  - pathname to file containing the gridpoint latitude, longitude, and
;             wind rotation angle variables (IDL "SAVE" file)
; verbose   - binary parameter, enables the output of diagnostic information
;             when set
;
; NON-SYSTEM ROUTINES CALLED
; --------------------------
; - find_alt_filename()
; - get_6h_precip()
; - grib_get_record()   (from Mark Piper's IDL GRIB webinar example code)
; - uncomp_file()
;
; HISTORY
; -------
; 05/03/12 - Morris, GPM GV, SAIC
; - Created.
; 05/07/12 - Morris, GPM GV, SAIC
; - Extracting surface soil temperature and moisture and adding scalar variables
;   for them to the site_sounding structures.
; 05/15/12 - Morris, GPM GV, SAIC
; - Reading Latitude, Longitude, and Rotation fields from static IDL SAVE file.
;   Got these by running a NAM GRIB file through ncl_convert2nc, reading them
;   from the resulting netCDF file, and saving the variables to a file.  See
;   read_nam_netcdf.pro.
; - Converting u and v from grid-relative to earth-relative when Rotation field
;   is available from the static SAVE file.  Added grid-/earth-relative flag to
;   site sounding structure.
; 05/23/12 - Morris, GPM GV, SAIC
; - Changed gribfile parameter to an array of strings with multiple filenames to
;   be read so that the 6h precip accumulation can be calculated from the
;   NAM forecast GRIB files, when available.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

function extract_site_soundings_from_grib, gribfiles, site_arr, lat_arr, lon_arr, $
                                           SAVEFILE=savefile, VERBOSE=verbose

printem = KEYWORD_SET(verbose)

; first grab the previous 6 hours' precip accumulation field from the NAM
; forecast GRIB files
precip_miss = 9999.0   ; initial guess
period = 0             ; accumulation period length, hours
precip = get_6h_precip(gribfiles, precip_miss, period, VERBOSE=verbose)

; i,j offsets for computing 4 points around radar site i,j's
offsets=FLTARR(2,4)
offsets[*,0]=[-0.5,-0.5]
offsets[*,1]=[-0.5, 0.5]
offsets[*,2]=[ 0.5, -0.5]
offsets[*,3]=[ 0.5, 0.5]

nsites = N_ELEMENTS(site_arr)

havefile = find_alt_filename( gribfiles[0], gribfile )
if ( havefile ) then begin
;  Get an uncompressed copy of the found file
   cpstatus = uncomp_file( gribfile, file_2do )
   if (cpstatus eq 'OK') then begin
;      parmlist = grib_print_parameternames( file_2do )
;      print, parmlist
     ; read one grib message in file into a structure, and get grid definition parms
     ; -- for now, assume we only have/are interested in NCEP Lambert Conformal parms.
      ptr_gribrec = ptr_new(/allocate_heap)
      *ptr_gribrec = grib_get_record( file_2do, 1, /structure )
      if *ptr_gribrec eq !null then message, "Error reading GRIB file: "+gribfile
      GridDefNum = (*ptr_gribrec).GRIDDEFINITION
         IF (printem) THEN print, "GridDefNum: ",GridDefNum
      map_proj = (*ptr_gribrec).GRIDTYPE
         IF (printem) THEN print, "map_proj: ",map_proj
      EarthRad_m = (*ptr_gribrec).RADIUS
         IF (printem) THEN print, "EarthRad_m: ",EarthRad_m
      alignLon = (*ptr_gribrec).LOVINDEGREES
         IF (printem) THEN print, "alignLon: ",alignLon
      LatInDeg1 = (*ptr_gribrec).LATIN1INDEGREES
         IF (printem) THEN print, "LatInDeg1: ",LatInDeg1
      LatInDeg2 = (*ptr_gribrec).LATIN2INDEGREES
         IF (printem) THEN print, "LatInDeg2: ",LatInDeg2
      NX = (*ptr_gribrec).NX
         IF (printem) THEN print, "NX: ",NX
      NY = (*ptr_gribrec).NY
         IF (printem) THEN print, "NY: ",NY
      DX_m = (*ptr_gribrec).DXINMETRES
         IF (printem) THEN print, "DX_m: ",DX_m
      DY_m = (*ptr_gribrec).DYINMETRES
         IF (printem) THEN print, "DY_m: ",DY_m
      LatTrue = (*ptr_gribrec).LaDInDegrees
         IF (printem) THEN print, "LatTrue: ",LatTrue
      Lat_1_1Deg = (*ptr_gribrec).LATITUDEOFFIRSTGRIDPOINTINDEGREES
         IF (printem) THEN print, "Lat_1_1Deg: ",Lat_1_1Deg
      Lon_1_1Deg = (*ptr_gribrec).LONGITUDEOFFIRSTGRIDPOINTINDEGREES
         IF (printem) THEN print, "Lon_1_1Deg: ",Lon_1_1Deg
      ptr_free, ptr_gribrec

      map_proj_grib2idl = HASH()   ; To Do -- define all these in an include file
      map_proj_grib2idl['lambert'] = 'Lambert Conic'

     ; set up the IDL map transformation
      mymap = map_proj_init( map_proj_grib2idl[map_proj], $
                             sphere_radius = EarthRad_m,  $
                             center_latitude = LatTrue,   $
                             center_longitude = alignLon, $
                             STANDARD_PAR1 = LatInDeg1,   $
                             STANDARD_PAR2 = LatInDeg2 )

     ; get x and y of first (lower left) gridpoint [(1,1) in GRIB-speak]
      xy_1_1 = map_proj_forward(map=mymap, Lon_1_1Deg, Lat_1_1Deg)

     ; get the x and y map coordinate values of the radar sites
      xy_arr = map_proj_forward(map=mymap, lon_arr, lat_arr)

     ; get the grid (i,j) coordinates of each site, where (0,0) is the first
     ; gridpoint in IDL array world
      ij_arr = xy_arr                    ; size it the same as xy
      ij_arr[*,*] = 0.0                  ; init to zeroes, just because
      for isite = 0, nsites-1 do begin
         ij_arr[*,isite] = (xy_arr[*,isite]-xy_1_1)/DX_m  ;dx=dy for NAM 218, etc.
      endfor

      file_id = grib_open( file_2do )
      n_records = grib_count( file_2do )
      if n_records lt 1 then begin
         msg = 'No GRIB messages found in file: '+gribfile
         message, msg, /informational
         return, !null
      endif
     ; Container for handle of each record in the file. Note this array is zero-based.
      h_record = lonarr(n_records)
      i_record = 0
      parameter_index = list()
      parm_indicator = list()
      leveltype_ind = list()
      leveltype = list()
      levelvalue = list()
      
      ; Loop over records in file.
      while (i_record lt n_records) do begin
   
         h = grib_new_from_file(file_id)
         h_record[i_record] = h  ; store handle in array for later
         iter = grib_keys_iterator_new(h, /all)
      
         ; Loop over keys in record, looking for the parameter key. (See also 
         ; note above.)
         while grib_keys_iterator_next(iter) do begin
            key = grib_keys_iterator_get_name(iter)
            CASE key OF
               'parameterName' : parameter_index.add, grib_get(h, key)
               'indicatorOfParameter' : parm_indicator.add, grib_get(h, key)
               'indicatorOfTypeOfLevel' : leveltype_ind.add, grib_get(h, key)
               'typeOfLevel' : leveltype.add, grib_get(h, key)
               'level' : levelvalue.add, grib_get(h, key)
               'levels' : levelvalue.add, grib_get(h, key)
               ELSE : break
            ENDCASE
         endwhile ; loop over keys in record

         grib_keys_iterator_delete, iter
         ;grib_release, h
         i_record++
      
      endwhile ; loop over records in file

     ; find the records with data on isobaric surfaces
      isobar_lev_idx=where(LEVELTYPE_IND EQ 'pl', countisolevs)
      if countisolevs eq 0 then begin
         msg = 'No isobaric level GRIB messages found in file: '+gribfile
         GOTO, errorExit
      endif

     ; find the records with isobaric temperature, RH, u, and v, respectively
      iso_temp_idx=WHERE(PARM_INDICATOR[isobar_lev_idx] EQ 11, countisotemp)
      if countisotemp eq 0 then begin
         msg = 'No isobaric level temperature GRIB messages found in file: '+gribfile
         GOTO, errorExit
      endif
      iso_temp_msgs = h_record[isobar_lev_idx[iso_temp_idx]]
      temp_miss = grib_get(iso_temp_msgs[0], 'missingValue')
;      IF (printem) THEN BEGIN
;      foreach h, iso_temp_msgs do begin
;         print, 'Name, level, missing: ', grib_get(h, 'parameterName'), ', ', $
;                STRTRIM(STRING(grib_get(h, 'level')),2), ', ', $
;                STRTRIM(STRING(grib_get(h, 'missingValue')),2)
;      endforeach
;      ENDIF

      iso_rh_idx=WHERE(PARM_INDICATOR[isobar_lev_idx] EQ 52, countisorh)
      if countisorh eq 0 then begin
         msg = 'No isobaric level Relative Humidity GRIB messages found in file: '+gribfile
         GOTO, errorExit
      endif
      if countisorh ne countisotemp then begin
         msg = 'Different number of isobaric Temperature and RH levels in file: '+gribfile
         GOTO, errorExit
      endif
      iso_rh_msgs = h_record[isobar_lev_idx[iso_rh_idx]]
      rh_miss = grib_get(iso_rh_msgs[0], 'missingValue')
;      IF (printem) THEN BEGIN
;      foreach h, iso_rh_msgs do begin
;         print, 'Name, level, missing: ', grib_get(h, 'parameterName'), ', ', $
;                STRTRIM(STRING(grib_get(h, 'level')),2), ', ', $
;                STRTRIM(STRING(grib_get(h, 'missingValue')),2)
;      endforeach
;      ENDIF

      iso_uwind_idx=WHERE(PARM_INDICATOR[isobar_lev_idx] EQ 33, countisouwind)
      if countisouwind eq 0 then begin
         msg = 'No isobaric level U-wind GRIB messages found in file: '+gribfile
         GOTO, errorExit
      endif
      if countisouwind ne countisotemp then begin
         msg = 'Different number of isobaric Temperature and U-wind levels in file: '+gribfile
         GOTO, errorExit
      endif
      iso_uwind_msgs = h_record[isobar_lev_idx[iso_uwind_idx]]
      uwind_miss = grib_get(iso_uwind_msgs[0], 'missingValue')
;      IF (printem) THEN BEGIN
;      foreach h, iso_uwind_msgs do begin
;         print, 'Name, level, missing: ', grib_get(h, 'parameterName'), ', ', $
;                STRTRIM(STRING(grib_get(h, 'level')),2), ', ', $
;                STRTRIM(STRING(grib_get(h, 'missingValue')),2)
;      endforeach
;      ENDIF

      iso_vwind_idx=WHERE(PARM_INDICATOR[isobar_lev_idx] EQ 34, countisovwind)
      if countisovwind eq 0 then begin
         msg = 'No isobaric level V-wind GRIB messages found in file: '+gribfile
         GOTO, errorExit
      endif
      if countisovwind ne countisotemp then begin
         msg = 'Different number of isobaric Temperature and V-wind levels in file: '+gribfile
         GOTO, errorExit
      endif
      iso_vwind_msgs = h_record[isobar_lev_idx[iso_vwind_idx]]
      vwind_miss = grib_get(iso_vwind_msgs[0], 'missingValue')
;      IF (printem) THEN BEGIN
;      foreach h, iso_vwind_msgs do begin
;         print, 'Name, level, missing: ', grib_get(h, 'parameterName'), ', ', $
;                STRTRIM(STRING(grib_get(h, 'level')),2), ', ', $
;                STRTRIM(STRING(grib_get(h, 'missingValue')),2)
;      endforeach
      print, ''
;      ENDIF

     ; find the record with surface soil temperature data ("skin" temperature)
      soilt_idx=where(PARM_INDICATOR EQ 85, countsoilt)
      if countsoilt eq 0 then begin
         msg = 'No surface soil temperature GRIB message found in file: '+gribfile
         GOTO, errorExit
      endif
      soilt_msg = h_record[soilt_idx[0]]  ; take 1st if > 1
      soilt_miss = grib_get(soilt_msg, 'missingValue')

     ; find the record with surface soil moisture data (volumetric fraction)
      soilmoist_idx=where(PARM_INDICATOR EQ 144, countsoilmoist)
      if countsoilmoist eq 0 then begin
         msg = 'No surface soil moisture GRIB message found in file: '+gribfile
         GOTO, errorExit
      endif
      soilmoist_msg = h_record[soilmoist_idx[0]]  ; take 1st if > 1
      soilmoist_miss = grib_get(soilmoist_msg, 'missingValue')

;print, "soilt_idx=", soilt_idx, "   soilt_miss=", soilt_miss
;print, "soilmoist_idx=", soilmoist_idx, "   soilmoist_miss=", soilmoist_miss

; -------------------------------------------------------------------

     ; set up structures to hold the site soundings, loop through
     ; the site/lat/lon arrays, and extract site soundings

      tempsnd = make_array(countisotemp, /FLOAT, VALUE=temp_miss)
      rhsnd = make_array(countisotemp, /FLOAT, VALUE=rh_miss)
      uwindsnd = make_array(countisotemp, /FLOAT, VALUE=uwind_miss)
      vwindsnd = make_array(countisotemp, /FLOAT, VALUE=vwind_miss)
      sndlevel = make_array(countisotemp, /FLOAT, VALUE=9999.)

      site_snd = { site_sounding, $
                   site : 'UNDEFINED', $
                   latitude : -999., $
                   longitude : -999., $
                   earth_relative_winds : 0, $
                   n_levels : countisotemp, $
                   levels : sndlevel, $
                   temperatures : tempsnd, $
                   RH : rhsnd, $
                   uwind : uwindsnd, $
                   vwind : vwindsnd, $
                   soiltemp : FLOAT(soilt_miss), $
                   soilmoist : FLOAT(soilmoist_miss), $
                   precip6h : FLOAT(precip_miss) }

      nsites = N_ELEMENTS( site_arr )
      site_snd_list = replicate( {site_sounding}, nsites )
     ; container for the 1-D indexes of each site's gridpoints to average
      siteptsidx_all = LONARR(4, nsites)
      ngoodpts = INTARR(nsites)

     ; compute the site geometries and write site data to structures
     ; TODO: find gridpoints within "X" km of site for averaging of precipitation,
     ;       rather than just averaging 4 surrounding gridpoints. X is TBD.
      for isite = 0, nsites-1 do begin
         this_snd = site_snd   ; make copy of "initialized" structure
         this_snd.site = site_arr[isite]  &  IF (printem) THEN print, "site: ",this_snd.site
         this_snd.latitude = lat_arr[isite]  &  IF (printem) THEN print, "latitude: ",this_snd.latitude
         this_snd.longitude = lon_arr[isite]  &  IF (printem) THEN print, "longitude: ",this_snd.longitude
        ; overwrite "empty" structure in array with update of "initialized" copy
         site_snd_list[isite] = this_snd

        ; determine the 4 gridpoints around the site, in IDL 2-D array coords.
         sitepts2d=LONARR(2,4)
         siteptsidx = LONARR(4)  ; container for the 1-D indexes of sitepts2d
         siteptsidx[*] = -1L
         goodpts = INTARR(4)     ; track whether gridpoints are within grid boundaries
         ngoodpts[isite] = 0
         for corner=0,3 do begin
             tempsitepts=FLOAT(ij_arr[*,isite])+offsets[*,corner]
            ; is corner within the grid domain?
             IF tempsitepts[0] GE 0.0 && tempsitepts[0] LE (NX-1) $
             && tempsitepts[1] GE 0.0 && tempsitepts[1] LE (NY-1) THEN BEGIN
                goodpts[corner] = 1
                sitepts2d[*,corner] = LONG(tempsitepts)
                siteptsidx[corner] = sitepts2d[1,corner]*NX + sitepts2d[0,corner]
                ngoodpts[isite]++
             ENDIF ELSE sitepts2d[*,corner] = [-1L, -1L]
         endfor
         siteptsidx_all[*,isite] = siteptsidx
         IF (printem) THEN BEGIN
            print, ''
            print, 'Site i,j coordinates (0-based):'
            print, ij_arr[*,isite]
            print, 'Surrounding gridpoint i,j values:'
            print, sitepts2d
;            print, 'Surrounding gridpoint array indices:'
;            print, siteptsidx
            print, ''
         ENDIF
      endfor

;      IF (printem) THEN BEGIN
;         print, 'Surrounding gridpoint array indices, all sites.'
;         print, siteptsidx_all
;      ENDIF

     ; get the temperature values near the sites, and the isolevel values
      levelidx=0
      foreach h, iso_temp_msgs do begin
         if levelidx GT (this_snd.n_levels-1) then begin
            msg = "Too many temperature messages for structure allocation."
            print, "levelidx, this_snd.n_levels-1: ",levelidx, this_snd.n_levels-1
            GOTO, errorExit
         endif

        ; get the pressure value of this isobaric level and tally in structure variable
         (site_snd_list)[*].levels[levelidx]=FLOAT(grib_get(h, 'level'))
        ; get the gridded data itself
         t_grid = grib_get_values(h)

         for isite = 0, nsites-1 do begin
           ; if we have any gridpoints around the site location, get their values,
           ; average the non-missing ones, and rewrite "temperatures" structure variables
            if ngoodpts[isite] GT 0 THEN BEGIN
               temp_near = t_grid[siteptsidx_all[*,isite]]
               idx2avg = where( temp_near ne temp_miss, count2avg )
               if count2avg gt 0 then (site_snd_list)[isite].temperatures[levelidx]=mean(temp_near[idx2avg])
            endif
         endfor
         levelidx++
      endforeach

     ; check the order/uniqueness of the levels, resort/pare if needed
      trimflag = 0
      uniqpresidx = UNIQ( (site_snd_list)[0].levels )
      numuniqpres = N_ELEMENTS(uniqpresidx)
      if numuniqpres NE countisotemp then begin
         PRINT, 'Duplicates in GRIB pressure levels for temperature! Trimming data.'
         trimflag = 1
         (site_snd_list)[*].n_levels = numuniqpres
      endif
     ; extract the unique levels, regardless of duplicate status
      tempo = (site_snd_list)[0].levels[uniqpresidx]
     ; check the ordering of the unique levels
      sortpresidx = SORT(tempo)
      ascorder = INDGEN(numuniqpres)
      sortflag=0
      IF TOTAL( ABS(sortpresidx-ascorder) ) NE 0 THEN BEGIN
         PRINT, 'GRIB pressure levels for temperature not in order! Resorting data.'
         sortflag=1
      ENDIF
      if trimflag EQ 1 then begin
         tempovals = (site_snd_list)[0].temperatures[uniqpresidx]
        ; reset the level/temperature values for the trimmed-off levels
         (site_snd_list)[*].levels[numuniqpres:countisotemp-1] = 9999.
         (site_snd_list)[*].temperatures[numuniqpres:countisotemp-1] = temp_miss
        ; rewrite the level values for the reordered levels
         (site_snd_list)[*].levels[0] = tempo[sortpresidx]
         (site_snd_list)[*].temperatures[0] = tempovals[sortpresidx]
      endif

      if TOTAL(ngoodpts) GT 0 THEN BEGIN
        ; get isobaric RH, U, and V; surface soil temperature; and 6h precip.
         levelidx=0
         foreach h, iso_rh_msgs do begin
            if levelidx GT ( (site_snd_list)[0].n_levels-1 ) then begin
               msg = "Too many RH messages for structure allocation."
               print, "levelidx, n_levels-1: ",levelidx, (site_snd_list)[0].n_levels-1
               GOTO, errorExit
            endif

            rhlev=grib_get(h, 'level')
           ; make sure these levels are in the same order as for temperatures
            idxthislev = where( (site_snd_list)[0].levels EQ rhlev, countlevfound )
            if countlevfound eq 1 then begin
               rh_grid = grib_get_values(h)
               for isite = 0, nsites-1 do begin
                 ; if we have any gridpoints around the site location, get their values,
                 ; average the non-missing ones, and rewrite "RH" structure variables
                  if ngoodpts[isite] GT 0 THEN BEGIN
                     rh_near = rh_grid[siteptsidx_all[*,isite]]
                     idx2avg = where( rh_near ne rh_miss, count2avg )
                     if count2avg gt 0 then (site_snd_list)[isite].rh[idxthislev]=mean(rh_near[idx2avg])
                  endif
               endfor
            endif else begin
               msg = "RH pressure level "+STRING(rhlev, FORMAT='(F0.1)')+ $
                     " not found in temperature levels list:"
               print, (site_snd_list)[0].levels
               GOTO, errorExit
            endelse
            levelidx++
         endforeach

         levelidx=0
         foreach h, iso_uwind_msgs do begin
            if levelidx GT ( (site_snd_list)[0].n_levels-1 ) then begin
               msg = "Too many u-wind messages for structure allocation."
               print, "levelidx, n_levels-1: ",levelidx, (site_snd_list)[0].n_levels-1
               GOTO, errorExit
            endif

            uwindlev=grib_get(h, 'level')
           ; make sure these levels are in the same order as for temperatures
            idxthislev = where( (site_snd_list)[0].levels EQ uwindlev, countlevfound)
            if countlevfound eq 1 then begin
               u_grid = grib_get_values(h)
               for isite = 0, nsites-1 do begin
                 ; if we have any gridpoints around the site location, get their values,
                 ; average the non-missing ones, and rewrite "uwind" structure variables
                  if ngoodpts[isite] GT 0 THEN BEGIN
                     uwind_near = u_grid[siteptsidx_all[*,isite]]
                     idx2avg = where( uwind_near ne uwind_miss, count2avg )
                     if count2avg gt 0 then (site_snd_list)[isite].uwind[idxthislev]=mean(uwind_near[idx2avg])
                  endif
               endfor
            endif else begin
               msg = "U-wind pressure level "+STRING(uwindlev, FORMAT='(F0.1)')+ $
                     " not found in temperature levels list:"
               print, (site_snd_list)[0].levels
               GOTO, errorExit
            endelse
            levelidx++
         endforeach

         levelidx=0
         foreach h, iso_vwind_msgs do begin
            if levelidx GT ( (site_snd_list)[0].n_levels-1 ) then begin
               msg = "Too many v-wind messages for structure allocation."
               print, "levelidx, n_levels-1: ",levelidx, (site_snd_list)[0].n_levels-1
               GOTO, errorExit
            endif

            vwindlev=grib_get(h, 'level')
           ; make sure these levels are in the same order as for temperatures
            idxthislev = where( (site_snd_list)[0].levels EQ vwindlev, countlevfound)
            if countlevfound eq 1 then begin
               v_grid = grib_get_values(h)
               for isite = 0, nsites-1 do begin
                 ; if we have any gridpoints around the site location, get their values,
                 ; average the non-missing ones, and rewrite "uwind" structure variables
                  if ngoodpts[isite] GT 0 THEN BEGIN
                     vwind_near = v_grid[siteptsidx_all[*,isite]]
                     idx2avg = where( vwind_near ne vwind_miss, count2avg )
                     if count2avg gt 0 then (site_snd_list)[isite].vwind[idxthislev]=mean(vwind_near[idx2avg])
                  endif
               endfor
            endif else begin
               msg = "V-wind pressure level "+STRING(vwindlev, FORMAT='(F0.1)')+ $
                     " not found in temperature levels list:"
               print, (site_snd_list)[0].levels
               GOTO, errorExit
            endelse
            levelidx++
         endforeach

        ; get the u/v rotation grid from the save file
         rotate=0
         IF N_ELEMENTS(savefile) GT 0 THEN BEGIN
            restore, savefile
            rotsize = SIZE(rot)
            IF rotsize[0] EQ 2 && rotsize[1] EQ NX && rotsize[2] EQ NY THEN BEGIN
               ij4rot = FIX(ij_arr)  ; get rotation angles from nearest gridpoint only
               for isite = 0, nsites-1 do begin
                  (site_snd_list)[isite].earth_relative_winds = 1
;;print, ij_arr[*,isite]
;;print, ij4rot[*,isite]
;print, rot[ij4rot[0,isite],ij4rot[1,isite]]*180./!pi
;print, 270.-atan((site_snd_list)[isite].vwind,(site_snd_list)[isite].uwind)*180./!pi
                  cosrot = cos(rot[ij4rot[0,isite],ij4rot[1,isite]])
                  sinrot = sin(rot[ij4rot[0,isite],ij4rot[1,isite]])
                  Vearth = cosrot*(site_snd_list)[isite].vwind $
                           - sinrot*(site_snd_list)[isite].uwind
                  Uearth = sinrot*(site_snd_list)[isite].vwind $
                           + cosrot*(site_snd_list)[isite].uwind
                  (site_snd_list)[isite].vwind = Vearth
                  (site_snd_list)[isite].uwind = Uearth
;print, 270.-atan((site_snd_list)[isite].vwind,(site_snd_list)[isite].uwind)*180./!pi
               endfor
            ENDIF ELSE BEGIN
               msg = "Variable rot not found in savefile "+savefile+", or dimensions wrong."
               help, rot
               GOTO, errorExit
            ENDELSE
         ENDIF

        ; get surface soil T and moisture
         soilt_grid = grib_get_values(soilt_msg)
         for isite = 0, nsites-1 do begin
           ; if we have any gridpoints around the site location, get their values,
           ; average the non-missing ones, and rewrite "soiltemp" structure variables
            if ngoodpts[isite] GT 0 THEN BEGIN
               soilt_near = soilt_grid[siteptsidx_all[*,isite]]
               idx2avg = where( soilt_near ne soilt_miss, count2avg )
               if count2avg gt 0 then (site_snd_list)[isite].soiltemp=mean(soilt_near[idx2avg])
            endif
         endfor

         soilmoist_grid = grib_get_values(soilmoist_msg)
         for isite = 0, nsites-1 do begin
           ; if we have any gridpoints around the site location, get their values,
           ; average the non-missing ones, and rewrite "soilmoist" structure variables
            if ngoodpts[isite] GT 0 THEN BEGIN
               soilmoist_near = soilmoist_grid[siteptsidx_all[*,isite]]
               idx2avg = where( soilmoist_near ne soilmoist_miss, count2avg )
               if count2avg gt 0 then (site_snd_list)[isite].soilmoist=mean(soilmoist_near[idx2avg])
            endif
         endfor

         IF (printem) THEN BEGIN
            idx2chek=where( soilmoist_grid ne soilmoist_miss, count2chk )
            print, ''
            print, "Max soil moist: ", MAX(soilmoist_grid[idx2chek])
            print, "Site soil moistures: ", (site_snd_list)[*].soilmoist
         ENDIF

        ; process the 6-h precipitation accumulation grid
         IF precip NE !null THEN BEGIN

           ; check the dimensions of the precip grid against the prior file's grids
            IF TOTAL(SIZE(precip, /DIMENSIONS) NE SIZE(soilmoist_grid, /DIMENSIONS)) NE 0 THEN BEGIN
               msg = "Precip accumulation grid and sounding grids dimensions do not match!"
               print, "SIZE(precip) = ", SIZE(precip, /DIMENSIONS)
               print, "SIZE(soilmoist_grid) = ", SIZE(soilmoist_grid, /DIMENSIONS)
               goto, errorExit
            ENDIF

            for isite = 0, nsites-1 do begin
              ; if we have any gridpoints around the site location, get their values,
              ; average the non-missing ones, and rewrite "precip6h" structure variables
               if ngoodpts[isite] GT 0 THEN BEGIN
                  precip_near = precip[siteptsidx_all[*,isite]]
                  idx2avg = where( precip_near ne precip_miss, count2avg )
                  if count2avg gt 0 then (site_snd_list)[isite].precip6h=mean(precip_near[idx2avg])
               endif
            endfor

            IF (printem) THEN BEGIN
               idx2chek=where( precip ne precip_miss, count2chk )
               print, ''
               print, "Max precip. accum.: ", MAX(precip[idx2chek])
               print, "Site precip. accums.: ", (site_snd_list)[*].precip6h
            ENDIF
            
         ENDIF  ;precip NE !null

      endif     ;TOTAL(ngoodpts) GT 0

; -------------------------------------------------------------------

      errorExit:

     ; Release all the handles and close the file.
      foreach h, h_record do grib_release, h
      grib_close, file_id
      
     ; Remove the temporary file copy
      command = "rm -v " + file_2do
      spawn,command

     ; if we hit a fatal error, report it and return error indicator to caller
      IF N_ELEMENTS(msg) NE 0 THEN BEGIN
         message, msg, /INFORMATIONAL
         return, -1
      ENDIF

   endif else begin
      print, cpstatus
      return, -1
   endelse
endif else begin
   print, "Cannot find regular/compressed file " + gribfile
   return, -1
endelse

return, site_snd_list
end
