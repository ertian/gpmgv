;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_event_series_stacked_color_n_sd.pro
;
; This procedure plots time series of average PR-GV site reflectivity difference
; for each configured GV site in a separate panel.  The time series data are in
; the file specified as the mandatory input parameter, and are precomputed and
; resident in the gpmgv database in the dbzdiff_stats_by_dist_geo table.  SQL in
; file "dbzdiff_stats_by_dist.sql" has the SQL command needed to generate the
; input file in the necessary format.  Output is to a Postscript file whose name
; is derived from the name of the input data file, and is written to the '/tmp'
; directory by default.  This version of the program also expects that the
; standard deviation of the reflectivity differences is present in the 5th
; column of data in the input file if there are more than 4 columns of data.
;
; The individual event biases for each site are plotted as color-filled circles
; connected by lines, where the color is dependent on the number of data samples
; in the event.  The standard deviations are plotted as vertical lines through
; the circles of extend equal to the SD value in dBZ.
; 
; The optional parameter 'nsmooth' is an integer which specifies the number of
; points over which the time series plots are smoothed by the IDL smooth()
; function.  Default is to not smooth the plots.  The optional parameter
; 'gr_minus_pr' indicates whether to reverse the sign of the Z difference values
; to plot GR-PR mean differences instead of PR-GR.  By default the time series
; plots [D]PR-GR differences, which is the convention for the values defined in
; query that creates the input data file.  The optional parameter
; 'min_samples' specifies a lower limit on the number of samples in the events
; eligible to be included in the time series.  Site events with fewer than this
; number of samples are excluded from the plots.  The YMAX parameter controls
; the range, in dBZ, of the y-axis in the plots.
;
; By default, the program will only plot time series for stations defined in the
; fixed list 'station_names', an array of 25 radar IDs that represents the
; legacy list of southeastern U.S. sites in the Validation Network prototype
; within coverage of the TRMM PR.  To make the procedure plot the stations
; defined in the input file it is necessary to set the binary keyword option
; READ_STATIONS to 1, or specify /READ_STATIONS, in the input parameters.
;
; A vertical red line is plotted on the time series at the date of the site's
; conversion to dual-polarimetric capability.  These dates are contained in the
; external file "/data/tmp/dualpol_conversion.txt".  These conversions all
; happened prior to the GPM era, the lines will not appear unless plotting bias
; for old TRMM PR matchup data.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO plot_event_series_stacked_color_n_sd, file, NSMOOTH=nsmooth, $
                                          GR_MINUS_PR=gr_minus_pr, $
                                          MIN_SAMPLES=min_samples, $
                                          READ_STATIONS=read_stations, $
                                          YMAX=ymax

On_IOError, IO_bailout ;  bailout if there is an error reading or writing a file

IF keyword_set(read_stations) THEN BEGIN
   command = "cat "+file+" | cut -f1 -d '|' | sort -u"
   spawn, command, station_names, COUNT=nstations
ENDIF ELSE BEGIN
   station_names = ['KAMX','KBMX','KBRO','KBYX','KCLX','KCRP','KDGX','KEVX',$
                    'KFWS','KGRK','KHGX','KHTX','KJAX','KJGX','KLCH','KLIX',$
                    'KMLB','KMOB','KSHV','KTBW','KTLH','KWAJ']
   nstations = N_ELEMENTS( station_names )
ENDELSE
print, nstations, station_names

;STOP  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

IF ( KEYWORD_SET(gr_minus_pr) ) THEN zsign = -1 ELSE zsign = 1
IF N_ELEMENTS(ymax) NE 1 THEN yrange=[-4.5,4.5] $
ELSE yrange=[-1*ymax,ymax]
print, "YRANGE: ", yrange


; generate the filename for postscript output
plot_dir=FILE_DIRNAME(file)   ;'/tmp'
outfile_name = FILE_BASENAME(file, '.txt')
IF ( N_ELEMENTS(nsmooth) NE 1 ) THEN addtext='_unsmoothed' $
ELSE addtext='_smoothed_by_' + STRING(nsmooth, FORMAT='(I0)')
IF ( KEYWORD_SET(gr_minus_pr) ) THEN addtext=addtext+"_GR-PR"
psoutname = plot_dir+'/'+outfile_name+addtext+'.ps'
print, psoutname

 entry_device = !d.name
 SET_PLOT, 'PS'
 DEVICE, /portrait, FILENAME=psoutname, COLOR=1, BITS_PER_PIXEL=8, $
         xsize=7, ysize=9.5, xoffset=0.75, yoffset=0.75, /inches
; !P.COLOR=0 ; make the title and axis annotation black
; !X.THICK=4 ; make the ticks thicker
; !Y.THICK=4 ; ditto
 !P.FONT=0 ; use the device fonts supplied by postscript

a_line = ' '
event_ID   = ' '
site_name  = ' '
event_date = ' '
num_events = 0
total_stations = 0
yrstart = 3000
yrend = 0
event_data = ''

OPENR, r_lun, file, /GET_LUN, ERROR=err
PRINT, 'error code', err
PRINT, ' '
PRINT, 'reading from file:', file
WHILE (EOF(r_lun) NE 1) DO BEGIN  ; *****loop through all records*****
  READF, r_lun, event_data
  num_events = num_events+1
ENDWHILE
PRINT, 'total number of events = ', num_events
FREE_LUN, r_lun

parsed = strsplit( event_data, '|', /extract )
IF N_ELEMENTS(parsed) GT 4 THEN BEGIN
   haveSD=1
   print, "StdDevs present in time series data, will plot error bars."
;   STOP
ENDIF ELSE haveSD=0

OPENR, r_lun, file, /GET_LUN, ERROR=err

site_arr   = STRARR(num_events)
x_date_arr = FLTARR(num_events)
y_mean_arr = FLTARR(num_events)
num_samples_arr = LONARR(num_events)
IF haveSD THEN y_stddev_array = FLTARR(num_events)
x_range    = LONARR(2) ; index0 is min index1 is max
y_range    = FLTARR (2) ; index0 is min index1 is max

FOR i=1,num_events DO BEGIN
  READF, r_lun, event_data
  parsed = strsplit( event_data, '|', /extract )
   site_name = parsed[0]
   event_date = parsed[1]
   e_mean = float(parsed[2])
   num_samples = long( parsed[3] )
   IF haveSD THEN e_stddev = float(parsed[4])

  i_month = FIX(STRMID(event_date,5,2))
  i_day   = FIX(STRMID(event_date,8,2))
  i_year  = FIX(STRMID(event_date,0,4))

  num_samples_arr[i-1] = num_samples
  site_arr[i-1]   = site_name  
  y_mean_arr[i-1] = e_mean*zsign
  x_date_arr[i-1] = JULDAY(i_month,i_day,i_year)
 ; define the location of the mean +/- one Std Dev if we have Std Dev data
  IF haveSD THEN y_stddev_array[i-1] = e_stddev

  IF (i EQ 1) THEN BEGIN ; find the bounds for the plot axes
    x_range[0] = x_date_arr[i-1]
    y_range[0] = y_mean_arr[i-1]
    x_range[1] = x_date_arr[i-1]
    y_range[1] = y_mean_arr[i-1]
  ENDIF ELSE BEGIN
    IF (x_date_arr[i-1] GT x_range[1]) THEN x_range[1] = x_date_arr[i-1]
    IF (x_date_arr[i-1] LT x_range[0]) THEN x_range[0] = x_date_arr[i-1]
    IF (y_mean_arr[i-1] GT y_range[1]) THEN y_range[1] = y_mean_arr[i-1]
    IF (y_mean_arr[i-1] LT y_range[0]) THEN y_range[0] = y_mean_arr[i-1]
  ENDELSE
ENDFOR

FREE_LUN, r_lun

IF N_ELEMENTS( min_samples ) EQ 1 THEN BEGIN
   IF MAX(num_samples_arr) LT min_samples THEN BEGIN
      print, "No cases meet the min_samples criterion, max = ", MAX(num_samples_arr)
      goto, skipto
   ENDIF
   idxenuff = WHERE( num_samples_arr GE min_samples )
   num_samples_arr = num_samples_arr[idxenuff]
   site_arr = site_arr[idxenuff]
   y_mean_arr = y_mean_arr[idxenuff]
   x_date_arr = x_date_arr[idxenuff]
   IF haveSD THEN y_stddev_array = y_stddev_array[idxenuff]
ENDIF

CALDAT, x_range[0], monthstart, daystart, yrstart
;monthstart = 12 & daystart = 31 & yrstart = 2009

CALDAT, x_range[1], monthend, dayend, yrend

; round start date of plots to beginning of quarter
CASE (monthstart-1)/3 OF
    0 : monthstart = 1
    1 : monthstart = 4
    2 : monthstart = 7
    3 : monthstart = 10
ENDCASE
x_range[0] = JULDAY(monthstart,1,yrstart)
print, monthstart,yrstart

CASE (monthend-1)/3 OF
   0 : monthend = 4
   1 : monthend = 7
   2 : monthend = 10
   3 : BEGIN
          yrend = yrend+1
          monthend = 1
       END
ENDCASE
x_range[1] = JULDAY(monthend,1,yrend)
print, monthend,yrend


rgb24=[ $
[255,255,255], $  ;white
;[105,105,105], $  ;dim gray
[90,90,90], $  ;black
[211,211,211], $  ;light gray
[255,255,212],$  ;butter
[255,160,122],$  ;light salmon
[205,92,92],$  ;indian red
[255,0,0],$  ;red
[139,0,0],$  ;dark red
[255,192,203],$  ;pink
[255,105,180],$  ;hot pink
[255,20,147],$  ;deep pink
[216,191,216],$  ;thistle
[153,50,204],$  ; dark orchid
[128,0,128], $  ;purple
[255,140,0],$  ;dark orange
[255,215,0],$  ;gold
[173,255,47],$  ;SpringGreen
[152,251,152],$  ;pale green
[0,80,0],$  ;green
[128,128,0],$  ;olive
[176,196,222],$  ;light steel blue
[0,139,139],$  ;dark cyan
[0,255,255],$  ;cyan
[173,216,230],$  ;powder blue
[65,105,225],$  ;royal blue
[0,0,255] $  ;blue
]

red=rgb24[0,*]
grn=rgb24[1,*]
blu=rgb24[2,*]


red = [  0, 255,   0, 255,   0, 255,   0, 255,   0, 127, 219, $
       255, 255, 112, 219, 127,   0, 255, 255,   0, 112, 219]
grn = [  0,  0, 208, 255, 255,   0,   0, 0,   0, 219,   0, $
       187, 127, 219, 112, 127, 166, 171, 171, 112, 255,   0]
blu = [  0, 191, 255,   0,   0,   0, 255, 171, 255, 219, 115, $
         0, 127, 147, 219, 127, 255, 127, 219,   0 ,  0, 255]
tvlct, red, grn, blu, 0


; ******************************************************************
; **** this logic assumes 21 stations in the array station_names ***
; ******************************************************************

i_plot = 0
i_station = 0

NVERT = 6 ;(NSTATIONS/2) < 6
NEXTPAGE = NVERT  ;*2

!P.MULTI = [0,1,NVERT] ;[0,2,NVERT]  ;!P.MULTI = [0,2,nstations/2]

; set the margins, in characters, around each individual plot
!Y.MARGIN = [2,1]
!X.MARGIN = [3,2]
; set the margins for the outside borders of the multiplot area
!Y.OMARGIN = [1,0]
!X.OMARGIN = [2,0]

!Y.MARGIN = [4,2]
!X.MARGIN = [4,4]
!Y.OMARGIN = [4,4]
!X.OMARGIN = [4,20]

; --- Define symbol as filled circle
A = FINDGEN(17) * (!PI*2/16.)
USERSYM, COS(A), SIN(A), /FILL

; Set up color table
;
common colors, r_orig, g_orig, b_orig, r_curr, g_curr, b_curr ;load color table
loadct,33, /SILENT
ncolor=!d.table_size-1
ncolor=255
bgcolor=ncolor-1  ; background color around "expanded" scatter points
red=bytarr(256) & green=bytarr(256) & blue=bytarr(256)
red=r_curr & green=g_curr & blue=b_curr
red(0)=0 & green(0)=0 & blue(0)=0
red(bgcolor)=150 & green(bgcolor)=150 & blue(bgcolor)=150  ;gray background
red(ncolor)=0 & green(ncolor)=0 & blue(ncolor)=0 
tvlct,red,green,blue

nplotted=0
FOR i=0,nstations-1 DO BEGIN
  index = WHERE(station_names[i] EQ site_arr[*])
  print, station_names[i], index[0]  ; beginning data record for this station
  IF (index[0] LT 0) THEN GOTO, skip_p  

  IF I GT 0 AND (nplotted MOD NEXTPAGE) EQ 0 THEN ERASE  ; START NEW PAGE IN PS FILE

; find the date of dual-pol conversion from file /data/tmp/dualpol_conversion.txt
command = "grep "+station_names[i]+" /data/tmp/dualpol_conversion.txt"
spawn, command, result, errout, COUNT=hits
help, result
IF hits EQ 1 THEN BEGIN
parsed = STRSPLIT(result, '|', /EXTRACT)
;print, "Dual-pol date: ", parsed[1]
dpdate=STRSPLIT(parsed[1], '-', /EXTRACT)
ENDIF ELSE dpdate=['1970','01','01']
print, "Dual-pol date: ", dpdate

PLOT, x_date_arr, y_mean_arr, XRANGE=x_range, YRANGE=yrange, XSTYLE=1, ystyle = 1, $
      /nodata, BACKGROUND='FFFFFF'XL, COLOR='000000'XL, $
      ycharsize=1.25, xcharsize=0.1, xticks=1, xtickformat='(I1)'
; plot the zero-bias line
OPLOT, [x_range[0],x_range[1]], [0,0], COLOR=0, linestyle=1
; plot the +/- 1dBZ lines in red
OPLOT, [x_range[0],x_range[1]], [-1,-1], COLOR=5, linestyle=0
OPLOT, [x_range[0],x_range[1]], [1,1], COLOR=5, linestyle=0

; plot either smoothed or raw biases - lines plus black symbols
IF ( N_ELEMENTS(nsmooth) NE 1 ) THEN $
    OPLOT, x_date_arr[index], y_mean_arr[index], COLOR=0, thick=2, $
           PSYM=-8, SYMSIZE=0.7  $
ELSE BEGIN
    ysmoothed = smooth(y_mean_arr[index],nsmooth)
    OPLOT, x_date_arr[index], ysmoothed, $
           COLOR=0, thick=2, PSYM=-8, SYMSIZE=0.7 ;0.53
ENDELSE

IF haveSD THEN BEGIN
  ; plot the +/- std dev value pairs as a vertical line through the symbol
   IF ( N_ELEMENTS(nsmooth) NE 1 ) THEN ybase=y_mean_arr[index] $
   ELSE ybase=ysmoothed
   xbase=x_date_arr[index]
   yoffsd=y_stddev_array[index]
   FOR isd = 0, N_ELEMENTS(index)-1 DO BEGIN
       OPLOT, [xbase[isd],xbase[isd]], [ybase[isd]-yoffsd[isd],ybase[isd]+yoffsd[isd]], $
           COLOR=0, thick=1
   ENDFOR
ENDIF

; now overplot smaller symbols inside the black ones,
; color-coded by the number of samples
;increment=10
thresh=[1,5,10,15,25,50,75,100,150,200,300,400,500,1000,2000]
IF N_ELEMENTS(min_samples) EQ 1 THEN thresh=thresh[WHERE(thresh GE min_samples)]
numColorCats = N_ELEMENTS(thresh)
increment=250/numColorCats

FOR icolor=0, numColorCats-2 DO BEGIN
    idxthisn = WHERE(num_samples_arr[index] GE thresh[icolor] AND $
                     num_samples_arr[index] LT thresh[icolor+1], nthisn)
    if nthisn GT 0 THEN BEGIN
       IF ( N_ELEMENTS(nsmooth) NE 1 ) THEN $
          OPLOT, x_date_arr[index[idxthisn]], y_mean_arr[index[idxthisn]], $
                 COLOR=icolor*increment, thick=2, PSYM=8, SYMSIZE=0.6 $
       ELSE $
          OPLOT, x_date_arr[index[idxthisn]], ysmoothed[idxthisn], $
                 COLOR=icolor*increment, thick=2, PSYM=8, SYMSIZE=0.6 ;0.53
    endif
   ; add count/color labels if first time writing to page
    IF (nplotted MOD NEXTPAGE) EQ 0 THEN BEGIN
       lbltxt=STRING(thresh[icolor],FORMAT='(I0)')+'-'+STRING(thresh[icolor+1]-1,FORMAT='(I0)')
       xyouts, 0.88-0.0001, 0.4+0.0125*icolor-0.0001, lbltxt, charsize=0.75, $
               color=0, alignment=0, /normal
       xyouts, 0.88+0.0001, 0.4+0.0125*icolor+0.0001, lbltxt, charsize=0.75, $
               color=0, alignment=0, /normal
       xyouts, 0.88, 0.4+0.0125*icolor, lbltxt, charsize=0.75, $
               color=icolor*increment, alignment=0, /normal
    ENDIF
ENDFOR
PRINT, '***plotted ', station_names[i]
; plot the station ID inside the plot box
xval = x_range[0] +  (x_range[1] - x_range[0])*7/8  
;XYOUTS, xval, 2.0, station_names[i], COLOR=0, $
XYOUTS, xval, yrange[1]*0.75, station_names[i], COLOR=0, $
        charsiz=0.6, charthick=1, /data  ; using data coordinates
i_plot = i_plot + 1 ; counter for printing station names

; how many months are in plot x-range?
monthrange = (1 + 12 - monthstart) + (yrend-yrstart-1 > 0)*12 + monthend
;print, monthrange
; we have room for about 10 labels for month of year, what is the step?
step = (((monthrange-1)/5)/3)*3
;print, step
months=['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC']
  months1=['J','F','M','A','M','J','J','A','S','O','N','D']
yrlast = yrstart
quote = "'"
; FOR mm = 0, monthrange, step DO BEGIN
  FOR mm = 0, monthrange-1 DO BEGIN
    plotmonth = ((monthstart+mm-1) MOD 12) + 1
    plotyr = yrstart + (monthstart+mm-1)/12
    x_loc_mm = JULDAY(plotmonth,1,plotyr)
;    XYOUTS, x_loc_mm, -6.75, months1[plotmonth-1], $
    XYOUTS, x_loc_mm, yrange[0]-1.0, months1[plotmonth-1], $
            COLOR=0, charsiz=0.4, charthick=1
    IF ( plotyr NE yrlast AND mm LT (monthrange-1) ) THEN BEGIN
      ; plot a vertical dotted line at the year break
       x_loc_yy = JULDAY(1,1,plotyr)
       OPLOT, [x_loc_yy,x_loc_yy], yrange, COLOR=0, linestyle=1
;       XYOUTS, x_loc_yy, -6.7, STRING(plotyr,FORMAT='("|  ",i4)'), COLOR=0, charsiz=0.6, charthick=1
       XYOUTS, x_loc_yy+20, yrange[0]+0.5, STRING(plotyr,FORMAT='(i4)'), COLOR=0, charsiz=0.5, charthick=1
       yrlast = plotyr
    ENDIF
ENDFOR

; plot a verical line at the dual-pol conversion break
x_loc_dp = JULDAY(FIX(dpdate[1]), FIX(dpdate[2]), FIX(dpdate[0]))
OPLOT, [x_loc_dp,x_loc_dp], yrange, COLOR=1, linestyle=0, thick=3

nplotted++

GOTO, skip_over
skip_p: PRINT, '****no events for station '
skip_over:

ENDFOR

GOTO, skipto
IO_bailout: PRINT, '***** IO error encountered'
            PRINT, !ERROR_STATE.MSG
            PRINT, 'finished this many events: ', num_events
skipto: 

DEVICE, /CLOSE_FILE
SET_PLOT, entry_device

end_it:
PRINT, 'Finished, see PS file: ' + psoutname

END
