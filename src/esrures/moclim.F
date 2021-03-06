C This file is part of the ESP-r system.
C Copyright Energy Systems Research Unit, University of
C Strathclyde, Glasgow Scotland, 2001.

C ESP-r is free software.  You can redistribute it and/or
C modify it under the terms of the GNU General Public
C License as published by the Free Software Foundation 
C (version 2 or later).

C ESP-r is distributed in the hope that it will be useful
C but WITHOUT ANY WARRANTY; without even the implied
C warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
C PURPOSE. See the GNU General Public License for more
C details.

C You should have received a copy of the GNU General Public
C License along with ESP-r. If not, write to the Free
C Software Foundation, Inc., 59 Temple Place, Suite 330,
C Boston, MA 02111-1307 USA.

C This file contains the following routine:
C      MOCLIM

C ******************** MOCLIM ********************

C MOCLIM sets up the climatic parameters relating to each
C simulation time step. This is done by recovering the
C hourly values from the climate file and interpolating
C for between hour time-steps.  Also returns requested value
C in GVAL and VAL3.

C The interpolation formula is:

C X = X1 + ((T - T1) * (X2 - X1)) / (T2 - T1)

C where:

C     X = interpolated value at time T (T1<=T<=T2)
C     X1= value of climatic parameter at time T1
C     X2= value of climatic parameter at time T2

      SUBROUTINE MOCLIM(ID,icget)
#include "building.h"
#include "net_flow.h"
#include "tdf2.h"

      COMMON/OUTIN/IUOUT,IUIN
      COMMON/FILEP/IFIL

      COMMON/SIMPIK/ISIM,ISTADD,ID1,IM1,ID2,IM2,ISDS,ISDF,NTS,ISAVE
      COMMON/SET1/IYEAR,IBDOY,IEDOY,IFDAY,IFTIME
      COMMON/GET1/VAL1(MZS,MTS),VAL2(MZS,MTS),VAL3(MZRL,MTS)
      COMMON/GET2/XDUM(MTS),XDUM1(MTS),GVAL(MTS)
      COMMON/AVRAGE/IDAVER
      COMMON/DNORGH/IRTYPE

C Treatment of solar radiation data in weather file
C ESP-r operates on hourly-centered data. That is, the amount of solar
C irradiance at the recorded hour is the instantaneous irradiance at the
C hour. In Canadian Weather for Energy Calculations (CWEC) files, solar
C radiation is integrated over the previous hour. To account for 
C the half hour shift, a flag has been implemented to indicate
C whether solar radiation data in the weather file is hour-centered
C (default) or half-hour centered.
C The flag can be set in the .cfg file or within bps in the 
C 'simulation toggles' menu.
      common/CWEC_SOL/iSlr_half_hr_flg
      integer iSlr_half_hr_flg     !- flag indicating if solar radiation data in weather file
                                   !- is hour-centered (default) or half-hour centered.
                                   !- 0 = hour-centered; 1 = half-hour centered.

      integer idif_next, idnr_next !- diffuse and direct normal radiation, respectively
                                   !- for first hour of the next day.


      DIMENSION IDIF(MT),ITMP(MT),IDNR(MT),IVEL(MT),IDIR(MT),IHUM(MT)
      DIMENSION VAL(MBITS+2)
      CHARACTER OUTS*124
      LOGICAL OK

C Access climate file to recover climatic data for requested
C day plus previous midnight values.
      IUNITC=IFIL+5
      IREC=ID-1
      IF(IREC.EQ.0)IREC=365
      READ(IUNITC,REC=IREC,IOSTAT=ISTAT,ERR=1000)(IDIF(J),ITMP(J),
     &IDNR(J),IVEL(J),IDIR(J),IHUM(J),J=1,24)
      IDIFL=IDIF(24)
      ITMPL=ITMP(24)
      IDNRL=IDNR(24)
      IVELL=IVEL(24)
      IDIRL=IDIR(24)
      IHUML=IHUM(24)

C Read values for next day to get values at first hour of next day
      irec = id +1
      if (irec .EQ. 366) irec = 1
      read(iunitc, rec=irec,iostat=istat,err=1000) (idif(j),itmp(j),
     &idnr(j),ivel(j),idir(j),ihum(j),j=1,24)
      idif_next = idif(1)
      idnr_next = idnr(1)

C Read values for requested day.
      IREC=ID
      READ(IUNITC,REC=IREC,IOSTAT=ISTAT,ERR=1000)(IDIF(J),ITMP(J),
     &IDNR(J),IVEL(J),IDIR(J),IHUM(J),J=1,24)

C Interpolate to obtain values for each computational time-step.
      IJ=0
      DO 10 I=1,24
        I1=I-1
        I2=I
        T1=FLOAT(I1)
        T2=FLOAT(I2)
        DO 20 J=1,NTS
        IJ=IJ+1
        Y1=FLOAT(J)
        Y2=FLOAT(NTS)
        T=T1+Y1/Y2
        IF(IDAVER.EQ.0)T=T-(1.0/(Y2*2.0))

C For TDF db purposes the time is equivalent to btimef in bmatsv.f.
C The past timestep C is TF = TF - 1./real(NTS). 
C TFL is is the last timestep of the previous day.
        TF = real(IJ)/Y2 
        TP = TF - (1./Y2)
        IF(ID.EQ.1)IDP=365
        IF(ID.GT.1)IDP=ID-1
        TFL=24.0-(1./real(NTS))
        LTSOD=24*NTS

C Debug...
C      WRITE(OUTS,'(A,2I3,4F7.2,I4)') 'I J T TP TF TFL ID ',
C     &         I,J,T,TP,TF,TFL,ID
C      CALL EDISP(IUOUT,OUTS)

C Diffuse radiation.
        IF(icget.EQ.25)THEN
          K=1
          IF(I1.EQ.0)goto 1

          if ( iSlr_half_hr_flg .eq. 0 ) then
             X1=FLOAT(IDIF(I1))
          else

C Solar radiation data is half-hour centered value at previous hour
C is average of previous hour and present hour.
             x1 = ( FLOAT(IDIF(I1)) + FLOAT(IDIF(I2)) ) * 0.5
          endif
          goto 2

    1     if ( iSlr_half_hr_flg .eq. 0 ) then
             X1=FLOAT(IDIFL)
          else

C Solar radiation data is half-hour centered previous hour is 
C hr 24 on previous day. take average of previous hour and present hour.
             x1 = ( FLOAT(IDIFL) + FLOAT(IDIF(I2)) ) * 0.5
          endif


    2     if ( iSlr_half_hr_flg .eq. 0 ) then
             X2=FLOAT(IDIF(I2))
          else

C Solar radiation data is half hour centered. So the
C present value is midnight.take average of value at
C present hour plus 1st hour of next day.
             if ( i2 .eq. 24 ) then
                x2 = ( FLOAT(IDIF(I2)) + FLOAT(idif_next) ) * 0.5
             else

C Otherwise take average of value at present hour and value
C at the subsequent hour.
                x2 = ( FLOAT(IDIF(I2)) + FLOAT(IDIF(I2+1)) ) * 0.5
             endif
          endif

          VAL3(K,IJ)=X1+(((T-T1)*(X2-X1))/(T2-T1))
          GVAL(IJ)=VAL3(K,IJ)

C If diffuse horizontal radiation is to be superseded by data from
C the temporal database then establish values to interpolate from.
C Loop until a db item matching this data type and day type is found.
          IFOC=0
          IF(IDIFHSL.ne.0)THEN
            itdi=IDIFHSL
            IFOC=itdi
          elseif(IALLCLM.ne.0)THEN
            itdi=IALLCLM
            IFOC=itdi
          endif
          if(IFOC.ne.0)then
            if(ij.eq.1)then
              CALL RCTDFR(0,ID,IJ,TP,VAL,ISD,IFOC,IER)
            else
              CALL RCTDFR(0,ID,IJ-1,TP,VAL,ISD,IFOC,IER)
            endif
            if(IDIFHSL.ne.0)X1=VAL(ISD)
            if(IALLCLM.ne.0)X1=VAL(ISD)
            CALL RCTDFR(0,ID,IJ,TF,VAL,ISD,IFOC,IER)
            if(IDIFHSL.ne.0)X2=VAL(ISD)
            if(IALLCLM.ne.0)X2=VAL(ISD)
            VAL3(K,IJ)=X1+(((T-TP)*(X2-X1))/(TF-TP))
            GVAL(IJ)=VAL3(K,IJ)
          endif
        elseif(icget.EQ.2)then

C External temperature.
          K=2
          IF(I1.EQ.0)goto 4
          X1=FLOAT(ITMP(I1))/10.
          goto 5
    4     X1=FLOAT(ITMPL)/10.
    5     X2=FLOAT(ITMP(I2))/10.
          VAL3(K,IJ)=X1+(((T-T1)*(X2-X1))/(T2-T1))
          GVAL(IJ)=VAL3(K,IJ)

C If external temperature is to be superseded by data from the
C temporal database then establish values to interpolate from.
C Loop until a db item matching this data type and day type is found.
          IFOC=0
          if(IDBTEXT.ne.0)then
            itdi=IDBTEXT
            IFOC=itdi
          elseif(IALLCLM.ne.0)THEN
            itdi=IALLCLM
            IFOC=itdi
          endif
          if(ifoc.ne.0)then
            if(ij.eq.1)then
              CALL RCTDFR(0,ID,IJ,TP,VAL,ISD,IFOC,IER)
            else
              CALL RCTDFR(0,ID,IJ-1,TP,VAL,ISD,IFOC,IER)
            endif
            if(IDBTEXT.ne.0)X1=VAL(ISD)
            if(IALLCLM.ne.0)X1=VAL(ISD+1)
            CALL RCTDFR(0,ID,IJ,TF,VAL,ISD,IFOC,IER)
            if(IDBTEXT.ne.0)X2=VAL(ISD)
            if(IALLCLM.ne.0)X2=VAL(ISD+1)

C If the first timestep then get last profile of previous day.
            IF(IJ.EQ.1)THEN
              CALL RCTDFR(0,IDP,LTSOD,TFL,VAL,ISD,IFOC,IER)
              if(IDBTEXT.ne.0)X1=VAL(ISD)
              if(IALLCLM.ne.0)X1=VAL(ISD+1)
            ENDIF
            VAL3(K,IJ)=X1+(((T-TP)*(X2-X1))/(TF-TP))
            GVAL(IJ)=VAL3(K,IJ)
          endif
        elseif(icget.EQ.24)then

C Direct solar radiation.
          K=3
          IF(I1.EQ.0)goto 6
          if ( iSlr_half_hr_flg .eq. 0 ) then
             X1=FLOAT(IDNR(I1))
          else

C Solar radiation data is half-hour centered and the value at previous hour
C is average of previous hour and present hour.
             x1 = ( FLOAT(IDNR(I1)) + FLOAT(IDNR(I2)) ) * 0.5
          endif
          goto 7

    6     if ( iSlr_half_hr_flg .eq. 0 ) then     
             X1=FLOAT(IDNRL)
          else

C Solar radiation data is half-hour centered and the
C previous hour is hr 24 on previous day. take average
C of previous hour and present hour.
             x1 = ( FLOAT(IDNRL) + FLOAT(IDNR(I2)) ) * 0.5
          endif

    7     if ( iSlr_half_hr_flg .eq. 0 ) then
             X2=FLOAT(IDNR(I2))
          else
C Solar radiation data is half hour centered. So the
C present value is midnight.take average of value at
C present hour plus 1st hour of next day.
             if ( i2 .eq. 24 ) then
                x2 = ( FLOAT(IDNR(I2)) + FLOAT(idnr_next) ) * 0.5
             else

C Otherwise take average of value at present hour and value
C at the subsequent hour.
                x2 = ( FLOAT(IDNR(I2)) + FLOAT(IDNR(I2+1)) ) * 0.5
             endif
          endif

          VAL3(K,IJ)=X1+(((T-T1)*(X2-X1))/(T2-T1))
          GVAL(IJ)=VAL3(K,IJ)

C If direct normal radiation is to be superseded by data from the
C temporal database then establish values to interpolate from.
C Loop until a db item matching this data type and day type is found.
          ok=.false.
          IFOC=0
          if(IDIRSOL.ne.0)then

C Direct normal solar from temporal file.
            itdi=IDIRSOL
            IFOC=itdi
            IRTYPE=0
          elseif(IGLOHSL.ne.0)then

C Global horizontal.
            itdi=IGLOHSL
            IFOC=itdi
            IRTYPE=1
          elseif(IALLCLM.ne.0)then
            itdi=IALLCLM
            IFOC=itdi
            IACC1=ITMAR(itdi,IATDF(itdi,1))
            if(IACC1.eq.0)then
              IRTYPE=0
            elseif(IACC1.eq.123)then
              IRTYPE=1
            endif
          endif
          if(ifoc.ne.0)then
            if(ij.eq.1)then
              CALL RCTDFR(0,ID,IJ,TP,VAL,ISD,IFOC,IER)
            else
              CALL RCTDFR(0,ID,IJ-1,TP,VAL,ISD,IFOC,IER)
            endif
            if(IDIRSOL.ne.0)X1=VAL(ISD)
            if(IGLOHSL.ne.0)X1=VAL(ISD)
            if(IALLCLM.ne.0)X1=VAL(ISD+2)
            CALL RCTDFR(0,ID,IJ,TF,VAL,ISD,IFOC,IER)
            if(IDIRSOL.ne.0)X2=VAL(ISD)
            if(IGLOHSL.ne.0)X2=VAL(ISD)
            if(IALLCLM.ne.0)X2=VAL(ISD+2)
            VAL3(K,IJ)=X1+(((T-TP)*(X2-X1))/(TF-TP))
            GVAL(IJ)=VAL3(K,IJ)
          endif
        elseif(icget.EQ.26)then

C Wind speed.
          K=4
          IF(I1.EQ.0)goto 8
          X1=FLOAT(IVEL(I1))/10.
          goto 9
    8     X1=FLOAT(IVELL)/10.
    9     X2=FLOAT(IVEL(I2))/10.
          VAL3(K,IJ)=X1+(((T-T1)*(X2-X1))/(T2-T1))
          GVAL(IJ)=VAL3(K,IJ)

C If wind speed is to be superseded by data from the
C temporal database then establish values to interpolate from.
C Loop until a db item matching this data type and day type is found.
          ok=.false.
          IFOC=0
          if(IWINDVL.ne.0)then
            itdi=IWINDVL
            IFOC=itdi
          elseif(IALLCLM.ne.0)THEN
            itdi=IALLCLM
            IFOC=itdi
          endif
          if(ifoc.ne.0)then
            if(ij.eq.1)then
              CALL RCTDFR(0,ID,IJ,TP,VAL,ISD,IFOC,IER)
            else
              CALL RCTDFR(0,ID,IJ-1,TP,VAL,ISD,IFOC,IER)
            endif
            if(IWINDVL.ne.0)X1=VAL(ISD)
            if(IALLCLM.ne.0)X1=VAL(ISD+3)
            CALL RCTDFR(0,ID,IJ,TF,VAL,ISD,IFOC,IER)
            if(IWINDVL.ne.0)X2=VAL(ISD)
            if(IALLCLM.ne.0)X2=VAL(ISD+3)

C If the first timestep then get last profile of previous day.
            IF(IJ.EQ.1)THEN
              CALL RCTDFR(0,IDP,LTSOD,TFL,VAL,ISD,IFOC,IER)
              if(IWINDVL.ne.0)X1=VAL(ISD)
              if(IALLCLM.ne.0)X1=VAL(ISD+3)
            ENDIF
            VAL3(K,IJ)=X1+(((T-TP)*(X2-X1))/(TF-TP))
            GVAL(IJ)=VAL3(K,IJ)
          endif
        elseif(icget.EQ.27)then

C Wind direction.
          K=5
          IF(I1.EQ.0)goto 11
          X1=FLOAT(IDIR(I1))
          goto 12
   11     X1=FLOAT(IDIRL)
   12     X2=FLOAT(IDIR(I2))
          VAL3(K,IJ)=X1+(((T-T1)*(X2-X1))/(T2-T1))
          GVAL(IJ)=VAL3(K,IJ)

C If wind direction is to be superseded by data from the
C temporal database then establish values to interpolate from.
          IFOC=0
          if(IWINDDR.ne.0)then
            itdi=IWINDDR
            IFOC=itdi
          elseif(IALLCLM.ne.0)THEN
            itdi=IALLCLM
            IFOC=itdi
          endif
          if(ifoc.ne.0)then
            if(ij.eq.1)then
              CALL RCTDFR(0,ID,IJ,TP,VAL,ISD,IFOC,IER)
            else
              CALL RCTDFR(0,ID,IJ-1,TP,VAL,ISD,IFOC,IER)
            endif
            if(IWINDDR.ne.0)X1=VAL(ISD)
            if(IALLCLM.ne.0)X1=VAL(ISD+4)
            CALL RCTDFR(0,ID,IJ,TF,VAL,ISD,IFOC,IER)
            if(IWINDDR.ne.0)X2=VAL(ISD)
            if(IALLCLM.ne.0)X2=VAL(ISD+4)

C If the first timestep then get last profile of previous day.
            IF(IJ.EQ.1)THEN
              CALL RCTDFR(0,IDP,LTSOD,TFL,VAL,ISD,IFOC,IER)
              if(IWINDDR.ne.0)X1=VAL(ISD)
              if(IALLCLM.ne.0)X1=VAL(ISD+4)
            ENDIF
            VAL3(K,IJ)=X1+(((T-TP)*(X2-X1))/(TF-TP))
            GVAL(IJ)=VAL3(K,IJ)
          endif
        elseif(icget.EQ.28)then

C Relative humidity.
          K=6
          IF(I1.EQ.0)goto 13
          X1=FLOAT(IHUM(I1))
          goto 14
   13     X1=FLOAT(IHUML)
   14     X2=FLOAT(IHUM(I2))
          VAL3(K,IJ)=X1+(((T-T1)*(X2-X1))/(T2-T1))
          GVAL(IJ)=VAL3(K,IJ)

C If relative humidity is to be superseded by data from the
C temporal database then establish values to interpolate from.
          IFOC=0
          if(IRELHUM.ne.0)then
            itdi=IRELHUM
            IFOC=itdi
          elseif(IALLCLM.ne.0)THEN
            itdi=IALLCLM
            IFOC=itdi
          endif
          if(ifoc.ne.0)then
            if(ij.eq.1)then
              CALL RCTDFR(0,ID,IJ,TP,VAL,ISD,IFOC,IER)
            else
              CALL RCTDFR(0,ID,IJ-1,TP,VAL,ISD,IFOC,IER)
            endif
            if(IRELHUM.ne.0)X1=VAL(ISD)
            if(IALLCLM.ne.0)X1=VAL(ISD+5)
            CALL RCTDFR(0,ID,IJ,TF,VAL,ISD,IFOC,IER)
            if(IRELHUM.ne.0)X2=VAL(ISD)
            if(IALLCLM.ne.0)X2=VAL(ISD+5)

C If the first timestep then get last profile of previous day.
            IF(IJ.EQ.1)THEN
              CALL RCTDFR(0,IDP,LTSOD,TFL,VAL,ISD,IFOC,IER)
              if(IRELHUM.ne.0)X1=VAL(ISD)
              if(IALLCLM.ne.0)X1=VAL(ISD+5)
            ENDIF
            VAL3(K,IJ)=X1+(((T-TP)*(X2-X1))/(TF-TP))
            GVAL(IJ)=VAL3(K,IJ)
          endif
        ENDIF
   20   CONTINUE
   10 CONTINUE

   16 RETURN

 1000 WRITE(outs,15)IREC
   15 FORMAT(' MOCLIM: climate file error at record',I5)
      CALL edisp(iuout,outs)
      goto 16
      END
