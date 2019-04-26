PRO agu_nexrad_bias_maps_dpr, DPR_diffs_file, outfile_base, new_version, old_version, PSNAMEADD=psNameAdd

; this IDL program plots the locations and identifiers of the
; nexrad radars in the GPM GV validation network, along with the
; old and new version mean GR-DPR bias, Ku-adjusted if indicated
;

;***************CONFIGURABLE PARAMETERS**********************
lon_sym_offset = -0.42 ; offset the RADAR NAME annotation by this amount
lat_sym_offset = 0.03 ; same deal with the RADAR NAME latitude
lon_bias_offset = -0.45 ; offset the BIAS annotation by this amount
lat_bias_offset = -0.3 ; same deal with the BIAS latitude
;************************************************************

timedate =  SYSTIME(0)
timedate = STRMID(timedate,4,STRLEN(timedate)) ; time & date will be added to
STRPUT, timedate, 'h', 6                       ; the output file name
STRPUT, timedate, 'm', 9
STRPUT, timedate, 's', 12
STRPUT, timedate, 'y', 15
timedate = STRCOMPRESS(timedate, /remove_all)  ; remove all blanks

IF N_ELEMENTS(psNameAdd) EQ 1 THEN nameAdd='_'+psNameAdd ELSE nameAdd=''
;outfile = '/home/tberendes/bulk_stats/maps/map_v4_ITE109'+nameAdd+'.ps'
;outfile = '/home/tberendes/bulk_stats/maps/map_' + old_version + '_'+ new_version + nameAdd+'.ps'
outfile = outfile_base + old_version + '_'+ new_version + nameAdd+'.ps'

; get the basename of the .ps file and substitute .pdf for .ps
outbase = FILE_BASENAME(outfile)
idxps = STRPOS(outbase, '.ps', /REVERSE_SEARCH)
outbasePDF = STRMID(OUTBASE,0,IDXPS)+'.pdf'
; get the current working directory so we can switch back to it at the end
cd, CURRENT=cur_dir
; get the path to the Postscript file and make it the working directory
; -- this will then be the directory where the PDF file will be written
pdfpath = FILE_DIRNAME(outfile, /MARK_DIRECTORY)
cd, pdfpath
outfilePDF = pdfpath + outbasePDF

; create color table
Red = [25, 27, 28, 30, 31, 33, 34, 36, 37, 39, 40, 42, 43, 45, 46, 48, 49, 51, $
53, 54, 56, 57, 59, 60, 62, 63, 65, 66, 68, 69, 71, 72, 74, 75, 77, 79, 80, 82, $
83, 85, 86, 88, 89, 91, 92, 94, 95, 97, 98, 100, 102, 103, 105, 106, 108, 109, $
111, 112, 114, 115, 117, 118, 120, 121, 123, 124, 126, 128, 129, 131, 132, $
134, 135, 137, 138, 140, 141, 143, 144, 146, 147, 149, 150, 152, 154, 155, $
157, 158, 160, 161, 163, 164, 166, 167, 169, 170, 172, 173, 175, 176, 178, $
180, 181, 183, 184, 186, 187, 189, 190, 192, 193, 195, 196, 198, 199, 201, $
202, 204, 206, 207, 209, 210, 212, 213, 215, 216, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255]

;Green
blue = [82, 84, 85, 86, 87, 88, 89, 90, 92, 93, 94, 95, 96, 97, 98, 100, 101, $
102, 103, 104, 105, 106, 108, 109, 110, 111, 112, 113, 115, 116, 117, 118, $
119, 120, 121, 123, 124, 125, 126, 127, 128, 129, 131, 132, 133, 134, 135, $
136, 137, 139, 140, 141, 142, 143, 144, 145, 147, 148, 149, 150, 151, 152, $
154, 155, 156, 157, 158, 159, 160, 162, 163, 164, 165, 166, 167, 168, 170, $
171, 172, 173, 174, 175, 176, 178, 179, 180, 181, 182, 183, 185, 186, 187, $
188, 189, 190, 191, 193, 194, 195, 196, 197, 198, 199, 201, 202, 203, 204, $
205, 206, 207, 209, 210, 211, 212, 213, 214, 215, 217, 218, 219, 220, 221, $
222, 224, 225, 226, 216, 215, 213, 212, 210, 209, 207, 206, 204, 202, 201, $
199, 198, 196, 195, 193, 192, 190, 189, 187, 186, 184, 183, 181, 180, 178, $
176, 175, 173, 172, 170, 169, 167, 166, 164, 163, 161, 160, 158, 157, 155, $
154, 152, 150, 149, 147, 146, 144, 143, 141, 140, 138, 137, 135, 134, 132, $
131, 129, 128, 126, 124, 123, 121, 120, 118, 117, 115, 114, 112, 111, 109, $
108, 106, 105, 103, 101, 100, 98, 97, 95, 94, 92, 91, 89, 88, 86, 85, 83, 82, $
80, 79, 77, 75, 74, 72, 71, 69, 68, 66, 65, 63, 62, 60, 59, 57, 56, 54, 53, 51, $
49, 48, 46, 45, 43, 42, 40, 39, 37, 36, 34, 33, 31, 30, 28, 27, 25]

;Blue
green = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, $
255, 255, 255, 255, 255, 255, 255, 216, 215, 213, 212, 210, 209, 207, 206, $
204, 202, 201, 199, 198, 196, 195, 193, 192, 190, 189, 187, 186, 184, 183, $
181, 180, 178, 176, 175, 173, 172, 170, 169, 167, 166, 164, 163, 161, 160, $
158, 157, 155, 154, 152, 150, 149, 147, 146, 144, 143, 141, 140, 138, 137, $
135, 134, 132, 131, 129, 128, 126, 124, 123, 121, 120, 118, 117, 115, 114, $
112, 111, 109, 108, 106, 105, 103, 101, 100, 98, 97, 95, 94, 92, 91, 89, 88, $
86, 85, 83, 82, 80, 79, 77, 75, 74, 72, 71, 69, 68, 66, 65, 63, 62, 60, 59, 57, $
56, 54, 53, 51, 49, 48, 46, 45, 43, 42, 40, 39, 37, 36, 34, 33, 31, 30, 28, 27, $
25]


PRINT, N_ELEMENTS(Red), N_ELEMENTS(Green), N_ELEMENTS(Blue)
add_fac = N_ELEMENTS(Red)/2

; latitude, longitude, bias, etc., sorted alphabetically by sym 
lat = [25.6111, 33.1722, 25.9161, 24.5975, 32.6556, 27.7842, 32.3178, 30.5644, $
       32.5731, 30.7219, 29.4719, 34.9306, 30.4847, 32.6753, 30.1253, $
       30.3367, 28.1133, 30.6794, 32.4508, 27.7056, 30.3975]
lon = [-80.4128, -86.7697, -97.4189, -81.7031, -81.0422, -97.5111, -89.9842, $
       -85.9214, -97.3031, -97.3831, -95.0792, -86.0833, -81.7019, $
       -83.3511, -93.2158, -89.8256, -80.6542, -88.2397, -93.8414, $
       -82.4017, -84.3289]
sym = ['KAMX', 'KBMX', 'KBRO', 'KBYX', 'KCLX', 'KCRP', 'KDGX', 'KEVX', $
       'KFWS', 'KGRK', 'KHGX', 'KHTX', 'KJAX', 'KJGX', 'KLCH', 'KLIX', $
       'KMLB', 'KMOB', 'KSHV', 'KTBW', 'KTLH']

; find out how many lines are in the input differences file
nrads = FILE_LINES( DPR_diffs_file )
radar_names_array = STRARR(nrads)
V3diffs = FLTARR(nrads)
V4diffs = FLTARR(nrads)
diffchg = FLTARR(nrads)

; determine whether the file has radar lat and lon positions in the data by
; looking at the number of columns (5=No lat/lon, 7=Has lat/lon)

OPENR, unit, DPR_diffs_file, /GET_LUN
filestr = ''
READF, unit, filestr
parsed = STRSPLIT(filestr, '|', /EXTRACT)
ncols=N_ELEMENTS(parsed)
havell = 0
CASE ncols OF
        5 : POINT_LUN, unit, 0     ; just rewind file to read IDs and biases
        7 : BEGIN
              havell = 1           ; set up to override hard-coded lat/lon/sym arrays
              lat = FLTARR(nrads)
              lon = lat
              sym = STRARR(nrads)
              POINT_LUN, unit, 0
            END
     ELSE : message, "Illegal number of columns in file: "+STRING(ncols, FORMAT='(I0)')
ENDCASE   

; read the site bias file, parse the fields, and assign to arrays
; File format is like:
; RADAR_ID|V3bias|numV3|V4bias|numV4|radarLatitude|radarLongitude

num = 0
WHILE ~ EOF(unit) DO BEGIN
   READF, unit, filestr
   parsed = STRSPLIT(filestr, '|', /EXTRACT)
   IF N_ELEMENTS(parsed[0]) GT 1 THEN BEGIN        ; check if radar ID has other "stuff" following it
      parsed2 = STRSPLIT(parsed[0], ' ', /EXTRACT)
      radar_names_array[num] = parsed2[0]          ; grab just the first "word" as radar ID
   ENDIF ELSE radar_names_array[num] = parsed[0]   ; else radarID is the only thing in the substring
;   V3diffs[num] = FLOAT(parsed[1])
;   V4diffs[num] = FLOAT(parsed[3])
   V3diffs[num] = FLOAT(parsed[3])
   V4diffs[num] = FLOAT(parsed[1])
   diffchg[num] = V4diffs[num]-V3diffs[num]
   IF havell THEN BEGIN
      ; read lat,lon,siteID from file
      lat[num] = FLOAT(parsed[5])
      lon[num] = FLOAT(parsed[6])
      sym[num] = radar_names_array[num]
   ENDIF
   num++
ENDWHILE

sym_string_pre = STRCOMPRESS(STRING(V3diffs),/REMOVE_ALL)
sym_string_post = STRCOMPRESS(STRING(V4diffs),/REMOVE_ALL)
sym_string_chg = STRCOMPRESS(STRING(diffchg),/REMOVE_ALL)

max_sym = (MAX(ABS(V3diffs)) > MAX(ABS(V4diffs))) > MAX(ABS(diffchg)) + 0.05
print, 'max_sym: ', max_sym
;scale_factor  = (N_ELEMENTS(Red)-1)/(2*max_sym)
;PRINT, 'scale factor ', scale_factor
max_label = ((FIX(max_sym*10)+5)/5)*0.5
PRINT, 'max_label: ', max_label
scale_factor  = (N_ELEMENTS(Red)-1)/(2*max_label)
PRINT, 'scale factor ', scale_factor

n = 1.5
device, decomposed=0
tvlct, 0B, 255B, 0B, 1 ; set color #1 to green
tvlct, 0B, 0B, 255B, 2 ; set color #2 to blue
tvlct, 0B, 0B, 0B,   3 ; set color #3 to black
tvlct, 255B, 0B, 0B, 4 ; set color #4 to red
tvlct, 255B,255B,255B, 5 ; color #5 is white
USERSYM, [-3*n,3.2*n,3.2*n,-3*n], [n,n,-1.2*n,-1.2*n], color=5, /FILL
device, decomposed=0 ; select indexed color mode
;
npts = 30
pi = 2. * acos(0.0)
c_fact = 360./(2. * pi)
d = sqrt(2) * 50000./6378206.4 ; 50,000m (50km) for 100km radius circle
p_lat = fltarr(npts)
p_lon = fltarr(npts)
;
PRINT, '****mapping to screen ', !d.name

; PLOT ALL THREE MAP TYPES TO SCREEN (GR-PR bias, GR-DPR bias, DPRbias-PRbias change)
for isource = 0,2 do begin
   CASE isource OF
      0 : begin
          sym2 = sym_string_pre
          print, "Plotting PR bias"
          end
      1 : begin
          sym2 = sym_string_post
          print, "Plotting DPR bias"
          end
      2 : begin
          sym2 = sym_string_chg
          print, "Plotting PR-DPR bias change"
          end
   ENDCASE

   IF havell THEN BEGIN
      mapctrlat=MEAN(lat)
      mapctrlon=MEAN(lon)
      maxlat = MAX(lat, MIN=minlat)
      maxlon = MAX(lon, MIN=minlon)
      map_set,mapctrlat,mapctrlon,/lambert,limit=[minlat-0.5,minlon-2.5, $
                                                  maxlat+0.5,maxlon+2.5]
      help, mapctrlat,mapctrlon,minlat-2.5,minlon-2.5,maxlat+2.5,maxlon+2.5
   ENDIF ELSE map_set,27.5,-82.0,/lambert,limit=[24.0,-99.0,35.0,-79.0]
   map_continents, /usa, mlinethick=2, mlinestyle=0
   map_grid,label=1,latlab=-98, lonlab=24
   OPLOT, lon, lat, psym=8 ; use the USERSYM symbol

   FOR j=0,nrads-1 DO BEGIN
     ; find the file-order radar ID location in the sym array
      rad_index = WHERE( sym EQ radar_names_array[j], countrads)
      if countrads NE 1 THEN message, "radar ID "+radar_names_array[j]+' not in "sym" array'
      lat1 = lat[rad_index]/c_fact
      lon1 = - lon[rad_index]/c_fact ; note sign reversal
        FOR i=0,npts-1 DO BEGIN
          tc = 2.*pi*float(i)/float(npts-1) - pi/4.
          p_lat[i] = asin(sin(lat1)*cos(d) + cos(lat1)*sin(d)*cos(tc))
          p_lon[i] = lon1 - asin(sin(tc)*sin(d)/cos(lat1)) + pi
          p_lon[i] = (p_lon[i] MOD (2.*pi)) - pi
        ENDFOR
      p_lat = p_lat * c_fact
      p_lon = -p_lon * c_fact
      table_index   = FIX(FLOAT(sym2[j]) * scale_factor) + add_fac
     ; set the plotted test color to contrast with circle fill colors
      IF ABS(FLOAT(sym2[j])) GE 1.5 THEN txtcolor = 5 ELSE txtcolor = 3
;      PRINT, sym2[j], table_index
      TVLCT, Red[table_index], Green[table_index], Blue[table_index], 99 ; set color #99 to proper shade of red
;      PRINT, sym2[j], ' ', Red[table_index], Green[table_index], Blue[table_index]
      POLYFILL, p_lon, p_lat, color=99
      alon = lon[rad_index] + lon_sym_offset ; offset the longitude for locating the RADAR NAME annotations
      alat = lat[rad_index] + lat_sym_offset ; offset the latitude too, see configurable parameters
      XYOUTS, alon, alat, sym[rad_index], color=txtcolor, charthick=2, charsize=1.5
      alon = lon[rad_index] + lon_bias_offset ; offset the longitude for locating the BIAS annotations
      alat = lat[rad_index] + lat_bias_offset ; offset the latitude too, see configurable parameters
      XYOUTS, alon, alat, STRMID(sym2[j],0,5), color=txtcolor, charthick=2, charsize=1.5
   ENDFOR

   doodah = ""
   READ, doodah, PROMPT='Hit Return to do next plot, Q to Quit and skip Postscript/PDF output: '
   IF doodah EQ 'Q' OR doodah EQ 'q' THEN BEGIN
      WDELETE
      GOTO, skip
   ENDIF
endfor


print, '****mapping to file named ', outfile
entry_device=!d.name
set_plot,'PS'
device, filename=outfile, /color, /landscape, /helvetica
IF havell THEN BEGIN
   lon_sym_offset = lon_sym_offset * 1.5
   lat_sym_offset = lat_sym_offset * 1.5
   lon_bias_offset = lon_bias_offset * 1.5
   lat_bias_offset = lat_bias_offset * 1.5
ENDIF

TVLCT, Red, Green, Blue
tvlct, 0B, 255B, 0B, 1 ; set color #1 to green
tvlct, 0B, 0B, 255B, 2 ; set color #2 to blue
tvlct, 0B, 0B, 0B,   3 ; set color #3 to black
tvlct, 255B, 0B, 0B, 4 ; set color #4 to red
tvlct, 255B,255B,255B, 5 ; color #5 is white

; IF LAT AND LON ARE PROVIDED THEN WE HAVE AN 'ALL CONUS SITES' BIAS FILE
; AND WILL ONLY PLOT THE GR-DPR BIAS TO THE POSTSCRIPT FILE ON A CUT-DOWN
; MAP REGION
;IF havell THEN BEGIN
;   src1=1  ; do DPR panel only
;   src2=1
;ENDIF ELSE BEGIN
   src1=0  ; do PR, DPR, PR-DPR
   src2=3
;ENDELSE

for isource = src1,src2 do begin
   CASE isource OF
      0 : begin
          sym2 = sym_string_pre
;          val2 = V3diffs
          val2 = V4diffs
          ;print, "Plotting ITE109 bias"
          print, "Plotting " + new_version + " bias"
          cbarTitle = 'GR-DPR ' + new_version + ' mean differences (dBZ)'
          end
      1 : begin
          sym2 = sym_string_post
;          val2 = V4diffs
          val2 = V3diffs
          ;print, "Plotting V4 bias"
          print, "Plotting " + old_version + " bias"
          cbarTitle = 'GR-DPR ' + old_version + ' mean differences (dBZ)'
          end
      2 : begin
          sym2 = sym_string_chg
          val2 = diffchg
          print, "Plotting " + new_version + "-" + old_version + " bias"
          ;print, "Plotting ITE109-V4 bias change"
          ;cbarTitle = 'GR-DPR bias change (dBZ) from ' + new_version + ' to ' + old_version
          cbarTitle = 'GR-DPR bias change (dBZ) from ' + old_version + ' to ' + new_version
          end
      3 : begin
          sym2 = sym_string_pre
;          val2 = V3diffs
          val2 = V4diffs
          print, "Plotting " + new_version + " bias"
          cbarTitle = 'GR-DPR ' + new_version + ' mean differences (dBZ)'
          ;print, "Plotting ITE109 bias"
          ;cbarTitle = 'GR-DPR ITE109 mean differences (dBZ)
          end
   ENDCASE

   ; SET UP MAP ACCORDING TO THE DATA TO BE PLOTTED (EXTENDED DPR SITE MAP OR PR/DPR AREA)
   IF havell THEN BEGIN
      mapctrlat=90. ;MEAN(lat)
      mapctrlon=MEAN(lon)
      maxlat = MAX(lat, MIN=minlat)
      maxlon = MAX(lon, MIN=minlon)
      minlon = minlon > (-107.)
      map_set,mapctrlat,mapctrlon,/lambert,limit=[minlat-0.5,minlon-2.5, $
              maxlat+0.5,maxlon+2.5], color=3, glinethick=3
      help, mapctrlat,mapctrlon,minlat-2.5,minlon-2.5,maxlat+2.5,maxlon+2.5
   ENDIF ELSE map_set,27.5,-82.0,/lambert,limit=[24.0,-99.0,35.0,-79.0], color=3, $
       glinethick=3

   ;map_set,27.5,-82.0,/lambert,limit=[24.0,-98.0,34.3,-80.0], color=3, $
   ;    glinethick=3
   map_continents,/usa, color=3, mlinethick=4, mlinestyle=0
   map_grid,label=1,latlab=-98, lonlab=24, color=3, glinethick=3
   oplot, lon, lat, psym=8 ; use the USERSYM symbol

   FOR j=0,nrads-1 DO BEGIN
     ; find the file-order radar ID location in the sym array
      rad_index = WHERE( sym EQ radar_names_array[j], countrads)
      if countrads NE 1 THEN message, "radar ID "+radar_names_array[j]+' not in "sym" array'
      lat1 = lat[rad_index]/c_fact
      lon1 = - lon[rad_index]/c_fact ; note sign reversal
        FOR i=0,npts-1 DO BEGIN
          tc = 2.*pi*float(i)/float(npts-1) - pi/4.
          p_lat[i] = asin(sin(lat1)*cos(d) + cos(lat1)*sin(d)*cos(tc))
          p_lon[i] = lon1 - asin(sin(tc)*sin(d)/cos(lat1)) + pi
          p_lon[i] = (p_lon[i] MOD (2.*pi)) - pi
        ENDFOR
      p_lat = p_lat * c_fact
      p_lon = -p_lon * c_fact
      table_index   = FIX(val2[j] * scale_factor) + add_fac
      PRINT, sym[rad_index], val2[j], table_index, FORMAT='(A0," ",F6.2," ",I0)'

     ; set the plotted text color to contrast with circle fill colors
      IF ABS( val2[j] ) GE 1.5 THEN txtcolor = 5 ELSE txtcolor = 3

IF  havell THEN  txtcolor = 3  ; OVERRIDE AND JUST PLOT ALL TEXT IN BLACK IF CONUS-EAST MAP
txtcolor = 3  ; OVERRIDE AND JUST PLOT ALL TEXT IN BLACK for Green/Red map

   ;print, txtcolor, Red[txtcolor], Green[txtcolor], Blue[txtcolor]
      TVLCT, Red[table_index], Green[table_index], Blue[table_index], 99 ; set color #99 to proper shade of red
;      PRINT, sym2[j], ' ', Red[table_index], Green[table_index], Blue[table_index]
      POLYFILL, p_lon, p_lat, color=99
      alon = lon[rad_index] + lon_sym_offset ; offset the longitude for locating the RADAR NAME annotations
      alat = lat[rad_index] + lat_sym_offset ; offset the latitude too, see configurable parameters
      XYOUTS, alon, alat, sym[rad_index], color=txtcolor, charthick=1, FONT=0
      alon = lon[rad_index] + lon_bias_offset ; offset the longitude for locating the BIAS annotations
      alat = lat[rad_index] + lat_bias_offset ; offset the latitude too, see configurable parameters
      XYOUTS, alon, alat, STRMID(sym2[j],0,5), color=txtcolor, charthick=1, FONT=0
   ENDFOR

   ; clear out an area for the color bar
;   TVLCT,255B,255B,255B,0
IF  havell THEN BEGIN
   x1 = 0.10
   x2 = 0.12
   y1 = 0.20
   y2 = 0.80
   cbvertical=1
   xadd = .08
   yadd = .05
   POLYFILL, [x1-xadd,x1-xadd,x2+xadd/2,x2+xadd/2],[y1-yadd,y2+yadd,y2+yadd,y1-yadd],COLOR=5, /NORMAL
ENDIF ELSE BEGIN
   x1 = 0.30
   x2 = 0.70
   y1 = 0.25
   y2 = 0.30
   cbvertical=0
   xadd = .05
   yadd = .05
   POLYFILL, [x1-xadd,x1-xadd,x2+xadd,x2+xadd],[y1-yadd,y2+yadd,y2+yadd,y1-yadd],COLOR=5, /NORMAL
ENDELSE

   ; plot the color bar and annotation
   TVLCT, Red, Green, Blue
   tvlct, 0B,0B,0B, 255 ; color 255 is black for colorbar outline and labeling
   COLORBAR_COYOTE, FORMAT='(F4.1)', MAXRANGE=max_label, MINRANGE=-1.0*max_label, $
             NCOLORS=252, POSITION=[x1,y1,x2,y2], COLOR=255, Title = cbarTitle, $
             VERTICAL=cbvertical

   ; reset special color assignments for text in plot
   tvlct, 0B, 255B, 0B, 1 ; set color #1 to green
   tvlct, 0B, 0B, 255B, 2 ; set color #2 to blue
   tvlct, 0B, 0B, 0B,   3 ; set color #3 to black
   tvlct, 255B, 0B, 0B, 4 ; set color #4 to red
   tvlct, 255B,255B,255B, 5 ; color #5 is white

   if isource LT 2 then erase   ; start a new page for the next plot
endfor

device, /close_file
set_plot, entry_device

end2:
command2 = 'ps2pdf '+outfile
spawn, command2, result, errout
PRINT, 'Finished making hard-copy map.  See graphics file(s): '
PRINT, outfilePDF
PRINT, outfile
skip:
; switch back to original working directory
cd, cur_dir
END
