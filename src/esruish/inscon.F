C This file is part of the ESP-r system.
C Copyright Energy Systems Research Unit, University of
C Strathclyde, Glasgow Scotland, 2001.

C ESP-r is free software.  You can redistribute it and/or
C modify it under the terms of the GNU General Public
C License as published by the Free Software Foundation 
C (version 2 orlater).

C ESP-r is distributed in the hope that it will be useful
C but WITHOUT ANY WARRANTY; without even the implied
C warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
C PURPOSE. See the GNU General Public License for more
C details.

C You should have received a copy of the GNU General Public
C License along with ESP-r. If not, write to the Free
C Software Foundation, Inc., 59 Temple Place, Suite 330,
C Boston, MA 02111-1307 USA.

C File 'inscon.F' comprises:
C  INSCON - readies the insolation computation and calls INSOLC.
C  findtmc- searches for which surfaces are insolation sources:
C  IGEOMS - establishes the surface grid.
C  INWSHD - reads the zone transitional shading file to extract
C           insolation source shading information.
C  INSOLC - controls the insolation computation.
C  INCAI  - computes areas and angles.
C  INSORT - sets up mesh points for transparent surfaces.
C  TRANSP - transforms a point on a surface to 3D coordinate space.

C ********** INSCON **********
C Controls the internal surface insolation calculation:
C   icomp  - the zone index;
C   icstat - computation status (1 if data exists);
C   act    - 's' for silent mode, '-' for user interaction mode.

      subroutine inscon(icomp,icstat,act)
#include "building.h"

C geometry.h provides commons G0/G2/c20/precz.
#include "geometry.h"
      
      integer lnblnk  ! function definition

C   ntmc & nwins: the number of insolation sources (i.e. external
C                 and transparent surfaces); the latter is held
C                 in common. CFCs count as transparent surfaces for
C                 shading analysis
C   itmc & isc:   toggles for each surface, if 1 then surface is an
C                 insolation source. The latter is held
C                 in common.
      common/outin/iuout,iuin
      common/filep/ifil

      character ltrns*72
      integer multic,mons,monf
      common/mtfile/ltrns,multic,mons,monf
      common/shdfil/ishadf
      integer mon,isc,iyd
      common/contr/mon,isc(ms),iyd
      common/ract/paction

      dimension month(12),iavdec(12)
      character paction*16
      character month*3,outs*124,tbase*72,act*1
      logical ok,dok,xst
      logical newgeo  ! Used to test for new/old geometry file.
      integer nboftmc ! equivalent of ntmc returned from findtmc
      integer ier

C For help messages
      character helpinsub*24 ! subroutine name
      character helptopic*24 ! string (unique) for topic
      integer nbhelp     ! number of help lines found

C Day of average solar declination in each month.
      data iavdec/17,15,16,15,15,11,17,16,16,16,15,11/
      data month/'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug',
     &            'Sep','Oct','Nov','Dec'/

      helpinsub='inscon'  ! set for subroutine
      newgeo=.false.  ! Assume older format geometry.
      iunit=ifil
      
C Fill the itmc and isc arrays.
  4   call findtmc(icomp,act,nboftmc)
      ntmc=nboftmc

C If no insolation sources return from inscon. Do not pause
C for warning if update_silent or useupdate_silent.
      if(ntmc.eq.0)then
        if(paction(1:13).eq.'update_silent'.or.
     &     paction(1:16).eq.'useupdate_silent')then
         return
        else
          call usrmsg('No insolation source surfaces found!',' ','W')
          return
        endif
      endif

C Make up help text for following dialogs.
      helptopic='inscon_actions'
      call gethelptext(helpinsub,helptopic,nbhelp)
    
C Check that at least one surface has been chosen or gleaned
C from the zone geometry file.
      icont=0
      do 70 i=1,nzsur(icomp)
         if(isc(i).eq.1)icont=1
   70 continue
      if(icont.eq.0)then
         if(newgeo)then
            call edisp(iuout,' ')
            call edisp(iuout,
     &      'No insolation sources noted in geometry file - skipping!')
            return
         else
            if(act.eq.'s')then
               call edisp(iuout,'No insolation sources - skipping!')
               return
            else
               dok=.true.
               call askok('No surfaces specified!','Re-specify?',
     &           ok,dok,nbhelp)
     
C Use a 2nd call to findtmc to allow the user to select different surfaces.
               if(ok)goto 4
               call edisp(iuout,'Insolation computation abandoned!')
               return
            endif
         endif
      endif

C Establish calculation period.
      if(act.eq.'s')then
         mons=1
         monf=12
         mon=mons
      else
         if(mons.gt.12) mons=1  ! if mons was clobbered reset
         call easki(mons,' ','Start month number?',
     &     1,'F',12,'F',1,'start month',ier,nbhelp)
         if(ier.ne.0)return
         if(monf.gt.12) monf=12  ! if monf was clobbered reset
         call easki(monf,' ','End month number?',
     &     mons,'F',12,'F',1,'end month',ier,nbhelp)
         if(ier.ne.0)return
         mon=mons
      endif

C Convert start month day of average solar declination to a year
C day number.
  81  iday=iavdec(mon)
      call eday(iday,mon,iyd)

C Attempt to open the relevant zone transitional shading file 
C for this month. If unknown call igeoms to set up grid.
      write(ltrns,'(a)')zname(icomp)(1:lnzname(icomp))
      write(tbase,'(a,a3)')ltrns(:lnblnk(ltrns)),month(mon)
      call erpfree(iunit,istat)
      call findfil(tbase,xst)

C Allow for number of surfaces within the zone transitional shading
C file.
      irecw=ms+5
      if(xst)then
         ier=0
         call efopran(iunit,tbase,irecw,1,ier)

C Since this file exists, there must have been a matching
C obstruction file and therefore the data in common /GS6/
C can be used.
         ishadf=1
      else
         ishadf=0
         if(mon.eq.mons)call igeoms(icomp)
      endif

C Commence computation for each specified month and allow user to
C update the zone shading & insolation db.
      write(outs,'(a3,a)')month(mon),' calculation commenced.'
      if(paction(1:13).ne.'update_silent')then
         call usrmsg(outs,' ','-')
      endif
      call insolc(icomp)
      icstat=1
      call isave(icomp,ier)
      mon=mon+1
      if(mon.le.monf)goto 81

      return
      end

C ********** findtmc **********
C findtmc searches for which surfaces are insolation sources:
C   icomp  - the zone index;
C   act    - 's' for silent mode, '-' for user interaction mode.
c   ntmc   - how many insolation sources were found
      subroutine findtmc(icomp,act,ntmc)
#include "building.h"
#include "geometry.h"

C   ntmc & nwins: the number of insolation sources (i.e. external
C                 and transparent surfaces); the latter is held
C                 in common.
C   itmc & isc:   toggles for each surface, if 1 then surface is an
C                 insolation source. The latter is held
C                 in common.
      common/outin/iuout,iuin

      integer izstocn
      common/c24/izstocn(mcom,ms)
      common/shdfil/ishadf
      integer mon,isc,iyd
      common/contr/mon,isc(ms),iyd
      common/tmc/itmc(ms),nwins
      common/ract/paction

C iaplic(1) toggle for shading;
C iaplic(2) toggle for insolation;
C           where 1 means consider all applicable surfaces and 0
C           means manual selection of surfaces.
C iaplic(3) toggle for assessment where:
C         1 is 'all_applicable',
C         0 is manual selection of surfaces.
C nsurfcalc is number of shaded surfaces.
C lstsfcalc list of applicable surfaces.
C nsurfinso number of insolation sources.
C isurfinso list of insolation sources.
      common/ishdirec/iaplic(mcom,2),nsurfcalc(mcom),
     &       lstsfcalc(mcom,ms),nsurfinso(mcom),isurfinso(mcom,ms)

      dimension iva(ms)
      character paction*16
      character act*1

      logical newgeo  ! Used to test for new/old geometry file.

      newgeo=.false.  ! Assume older format geometry.

      ishadf=0

C Establish if any of the surfaces are TMCs or CFCs.
      ntmc=0
      nwins=0

C If new format geometry and iaplic(icomp,2) equals 1 then
C all applicable surfaces were set in the zone geometry file.
      if(newgeo)then
         if(iaplic(icomp,2).eq.1)then
            nwins=nsurfinso(icomp)
            do 41 j=1,nwins
               iva(j)=isurfinso(icomp,j)
  41        continue

C Set up itmc and isc arrays and total number of sources in zone.
            do 42 i=1,nzsur(icomp)
               itmc(i)=0
               isc(i)=0 
               do 43  j=1,nwins
                  if(i.eq.iva(j))then
                    itmc(i)=1
                    isc(i)=1
                    ntmc=ntmc+1  ! update the parameter passed back
                  endif
  43           continue
  42         continue

C If iaplic(icomp,2) is 0 and nsurfinso is non-zero then user
C has manually selected surfaces so fill arrays. If both 0 then
C the user effectively said no insolation should be calculated
C so just clear itmc() and isc() arrays.
         elseif(iaplic(icomp,2).eq.0)then
            nwins=nsurfinso(icomp)
            if(nwins.eq.0)then
               do 44 i=1,nzsur(icomp)
                  itmc(i)=0
                  isc(i)=0 
  44           continue
            else
               do 45 j=1,nwins
                  iva(j)=isurfinso(icomp,j)
  45           continue

C Set up itmc and isc arrays and total number of sources in zone.
               do 46 I=1,nzsur(icomp)
                  itmc(i)=0
                  isc(i)=0 
                  do 47 j=1,nwins
                     if(i.eq.iva(j))then
                        itmc(i)=1
                        isc(i)=1
                        ntmc=ntmc+1  ! update the parameter passed back
                     endif
  47              continue
  46           continue
            endif
         endif

      else

C Older geometry file, user is required to set preferences for
C surfaces to include or, in the case of silent action, just
C do 'all applicable' surfaces.
         if(act.eq.'s'.or.paction(1:11).eq.'recalculate')then

C Clear return array and select all applicable surfaces.
            do 14 i=1,nzsur(icomp)
               iva(i)=0
  14        continue
            do 13 i=1,nzsur(icomp)
               icn=izstocn(icomp,i)
               if(ssother(icn,1)(1:5).eq.'EXTER'.and.
     &            ssotf(icn)(1:4).ne.'OPAQ')then
                  ntmc=ntmc+1
                  iva(ntmc)=i
               endif
  13        continue
            if(ntmc.eq.0)then
              if(paction(1:13).eq.'update_silent'.or.
     &           paction(1:16).eq.'useupdate_silent')then
               return
              else
                call usrmsg('No insolation source surfaces found!',
     &            ' ','W')
                return
              endif
            endif
            iaplic(icomp,2)=1
         else
            call edisp(iuout,' ')
            call edisp(iuout,'Select external transparent surfaces')
            call edisp(iuout,'(i.e. light sources) to include in the')
            call edisp(iuout,'intra-zone insolation calculation.')
            call pickssur(icomp,ntmc,'i',iva,ier)
            if(ier.ne.0)return
            if(ntmc.eq.0) return
         endif

C Set up itmc and isc arrays and total number of sources, nwins, 
C in zone.
         do 110 i=1,nzsur(icomp)
            itmc(i)=0
            isc(i)=0 
            do 120 j=1,ntmc
               if(i.eq.iva(j))then
                  itmc(i)=1
                  isc(i)=1
                  nwins=nwins+1
               endif
  120       continue
  110    continue

C Fill ishdirec array.
         nsurfinso(icomp)=nwins
         do 121 j=1,nwins
            isurfinso(icomp,j)=iva(j)
  121    continue
      endif

      return
      end
      
C ********** IGEOMS **********
C Establishes the source surface grid if a zone transitional shading
C file does not exist.

      subroutine igeoms(izone)
#include "building.h"
#include "geometry.h"

C Parameter
      integer izone  ! index of zone

      common/tmc/itmc(ms),nwins

C Set default surface grid.
      if(nox(izone).eq.0) nox(izone)=20
      if(noz(izone).eq.0) noz(izone)=20
      nwins=0
      do 10 i=1,nzsur(izone)
        if(itmc(i).ne.0)nwins=nwins+1
   10 continue
      return
      end

C ********** INSOLC **********
C Calculates intra-zone solar insolation. Called from inscon.
C insst()       - 0 if the entire surface is shaded, -1 if the sun
C                 is not up; otherwise the index of the surface being
C                 insolated.
C pinsst(i,j,k) - irradiance proportion to kth internal insolated
C                 surface received from insolation source i at hour j.
C N.B The proportions correspond to the situation after source shading has
C been imposed with igins() holding information for each source surface
C grid point as follows. 
C        0 - undefined; 
C     -100 - point is shaded;
C     -200 - point is outwith the source surface;
C       k  - indicates that point projects to the kth internal surface
C            in the misur list.

      subroutine insolc(icomp)
#include "building.h"
#include "geometry.h"

      integer izstocn
      common/c24/izstocn(mcom,ms)
      common/sunhr/isunhr
      common/tshd/ioshd(mox,moz)
      common/grid11/xop(mox,moz),zop(mox,moz)
      common/shad1/isunup
      common/cai/caii(ms),caie(ms)
      integer mon,isc,iyd
      common/contr/mon,isc(ms),iyd
      common/proji/xp,yp,zp
      common/inswin/igins(mox,moz)
      common/pinsol/ins(ms),pins(ms),pinw(ms),pcshad
      common/stins/insst(mgt,24,misur),pinsst(mgt,24,misur),
     &             shadst(mgt,24)
      common/ract/paction
      common/sangl1/sazi1,salt1
      common/tmc/itmc(ms),nwins
      common/icflag/ic
      common/shdinf/noshad
      common/prec8/slat,slon

C ical = 0 indicates that no insolation calculations have been
C performed and is set to 1 when they have.
      common/data1/ical,idifc,init

      dimension xf(mtv),yf(mtv),zf(mtv),ydist(mox,moz)
      character outs*124,paction*16
      character*3 month(12)

      data month/'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug',
     &            'Sep','Oct','Nov','Dec'/

C Set initial values.
      ical=0
      ic=0
      kind=0
      indcom=0
      isunhr=0
      ksu=0

C Determine number of sun-up hours.
      do 10 i=1,24
         stime=float(i)
         call eazalts(stime,iyd,slat,slon,isunup,sazi,salt)
         if(isunup.eq.1)ksu=ksu+1
   10 continue

C Estimate simulaton extent (source-hours) to support the
C progress report.         
      kt=nwins*ksu

C Loop through surfaces and for each insolation source perform
C calculations.
      iwin=0
      do 20 i=1,nzsur(icomp)

C Get the current connection for surface isrc
         isrc=i
         iccisrc=izstocn(icomp,isrc)
         if(itmc(isrc).eq.0)goto 20
         iwin=iwin+1
         modes=1

C 'noshad' = 1 indicates that there is no shading information for
C              surface i in the zone transitional shading file.
         noshad=0
         if(paction(1:13).ne.'update_silent')then
            call usrmsg(' ',' ','-')
         endif

C Partially derive transformation equations by computing time
C independent part of equation coefficients - equivalent to
C translation plus three-dimensional plane rotation.
         call trnsf1i(icomp,isrc)

C Grid the insolation source surface.
         call mesh(icomp,isrc)

C Proceed hour-by-hour.
         do 30 j=1,24
            ihr=j
            stime=float(ihr)

C Determine the solar azimuth and altitude angles relative to the
C original coordinate system.
            call eazalts(stime,iyd,slat,slon,isunup,sazi1,salt1)

C Abandon calculation for this hour if before sunrise or after sunset.
            if(isunup.eq.0)goto 1

C Record first sun-up hour.
            if(isunhr.eq.0)isunhr=j

C Determine angles for all external and internal surfaces.
            call incai(icomp,ihr)

C Initiallise igins, the array of source grid points holding
C the insolated surface numbers.
            do 40 m=1,nox(icomp)
               do 50 n=1,noz(icomp)
                  call point1(icomp,isrc,xop(m,n),zop(m,n),ians)
                  if(ians.eq.0)then
C Outwith source surface.
                     igins(m,n)=-200
                  else
C Not yet defined.
                     igins(m,n)=0
                     ydist(m,n)=1.E+10
                  endif
   50          continue
   40       continue

C Take zone transitional shading file information into account.
C modes=1 indicates that call is for first sun-up hour; 2 otherwise.
            call inwshd(icomp,isrc,ihr,modes)
            modes=2

C If caie is positive then source surface can be considered.
            if(caie(isrc).le.0.0)then
               do 60 m=1,nox(icomp)
                  do 70 n=1,noz(icomp)
                     if(igins(m,n).ne.-200)igins(m,n)=-100
   70             continue
   60          continue
               goto 2
            endif

C Examine each internal surface for insolation.
            do 80 l=1,nzsur(icomp)
               intsur=l

C Exclude a surface that cannot see the source.
               if(intsur.eq.isrc.or.caii(l).le.0.0)goto 80

C Derive the transformation equations for current internal surface.
               call trnsf1i(icomp,intsur)

C Compute new solar angles relative to internal surface coordinate
C system.
               call trnsf2i(ihr)

C Set up source surface global coordinates.
               do 90 inv=1,nznver(iccisrc)
                 iwhich=nzjvn(iccisrc,inv)
                 xf(inv)=vcoord(icomp,iwhich,1)
                 yf(inv)=vcoord(icomp,iwhich,2)
                 zf(inv)=vcoord(icomp,iwhich,3)
   90          continue

C Initiate source surface grid point-by-point analysis.
               ipass=0
               do 100 m=1,nox(icomp)
                  do 110 n=1,noz(icomp)
                     if(igins(m,n).eq.-200)goto 110
                     if(ioshd(m,n).eq.1)then
                        igins(m,n)=-100
                        goto 110
                     endif

C Convert source surface grid point coordinates back to global
C coordinates before initiating projection.
                     call transp(iccisrc,xf,yf,zf,xop(m,n),
     &                 zop(m,n),xgp,ygp,zgp)
                     call trnsf3i(ihr,icomp,intsur,ipass,xgp,ygp,zgp)
                     ipass=1
                     if(yp.lt.0.0)goto 110

C Call point containment test; ians is 1 if point is within the
C receiving surface and striking the side opposite the surface
C normal.
                     call point1(icomp,intsur,xp,zp,ians)
                     if(ians.eq.0)goto 110

C Use crowxyz to check real distance between source point (xgp,ygp,zgp)
C and intersection point (xp,yp,zp). Use the nearest intersection
C for igins (not implmented).
                     chkdis=crowxyz(xgp,ygp,zgp,xp,yp,zp)
                     if(chkdis.lt.ydist(m,n))then
                        igins(m,n)=intsur
                        ydist(m,n)=chkdis
                     endif
  110             continue
  100          continue
   80       continue

C Sort the insolation passing through each insolation source surface.
    2       call insort(icomp,isrc,ihr)

C Store for each source and hour.
            do 120 m=1,misur
               insst(iwin,ihr,m)=ins(m)
               pinsst(iwin,ihr,m)=pins(m)
  120       continue
            shadst(iwin,ihr)=pcshad
            kind=kind+1
            calcom=float(kind)/float(kt)
            write(outs,'(a,a3,a)')'`',month(mon),
     &                         '` insolation calculation commenced:'
            if(calcom.ge.0.95)then
               if(indcom.eq.4)goto 30
               indcom=indcom+1
               if(paction(1:13).ne.'update_silent')then
                  call usrmsg(outs,' complete.','-')
               endif
            elseif(calcom.ge.0.75)then
               if(indcom.eq.3)goto 30
               indcom=indcom+1
               if(paction(1:13).ne.'update_silent')then
                  call usrmsg(outs,' 75% complete.','-')
               endif
            elseif(calcom.ge.0.50)then
               if(indcom.eq.2)goto 30
               indcom=indcom+1
               if(paction(1:13).ne.'update_silent')then
                  call usrmsg(outs,' 50% complete.','-')
               endif
            elseif(calcom.ge.0.25)then
               if(indcom.eq.1)goto 30
               indcom=indcom+1
               if(paction(1:13).ne.'update_silent')then
                  call usrmsg(outs,' 25% complete.','-')
               endif
            endif
            goto 30

C Sun not up.
    1       do 130 m=1,misur
               insst(iwin,ihr,m)=-1
               pinsst(iwin,ihr,m)=0.0
  130       continue
   30    continue    ! end of hour loop
   20 continue       ! end of tmc loop
      ical=1
      return
      end

C ********** inwshd **********
C Reads the transitional shading file if one exists and extracts
C surface shading information.

      subroutine inwshd(izone,isur,ihr,modes)
#include "building.h"
#include "geometry.h"

      common/outin/iuout,iuin
      common/filep/ifil
      common/tshd/ioshd(mox,moz)
      common/sunhr/isunhr
      common/shdfil/ishadf
      common/shdinf/noshad
      common/recshd/irectx

      dimension irecs(ms)
      character outs*124

      iushd=ifil

      if(ishadf.eq.0.or.noshad.eq.1)goto 1
      goto (2,3),modes

C Transfer here for the first hour every day when sun is up.
    2 irec=1
      read(iushd,rec=irec,iostat=istat,err=1000)
     &    (irecs(i),i=1,nzsur(izone))
      irecn=irecs(isur)
      if(irecn.eq.0)then
          noshad=1
          goto 1
      endif

C Skip previous records written prior to sun-rise.
      irectx=irecn+2+(isunhr-1)

C Transfer here at all other sun-up hours.
    3 irec=irectx
      read(iushd,rec=irec,iostat=istat,err=1000)isunup

C Sun not up must be an error!
      if(isunup.eq.0)goto 1000

      irec=irec+1
      read(iushd,rec=irec,iostat=istat,err=1000)ians
      irec=irec+1
      if(ians.eq.-2)goto 1
      if(ians.eq.-1)goto 5

C Read surface shading information.
      do 10 i=1,nox(izone)
         read(iushd,rec=irec,iostat=istat,err=1000)
     &     (ioshd(i,j),j=1,noz(izone))
         irec=irec+1
   10 continue
      goto 4

C Surface is not shaded.
    1 do 20 i=1,nox(izone)
         do 30 j=1,noz(izone)
            ioshd(i,j)=0
   30    continue
   20 continue
      goto 4

C Surface is fully shaded.
    5 do 40 i=1,nox(izone)
         do 50 j=1,noz(izone)
            ioshd(i,j)=1
   50    continue
   40 continue

C Increment irec to skip record holding pso & psof
    4 irectx=irec+1
      return

 1000 write(outs,1001)irec,ihr,isur
 1001 format('INWSHD: Zone Transitional Shading file error, record',i6,
     &       ', hour ',i3,' source ',i2)
      call edisp(iuout,outs)
      return
      end

C ********** INCAI **********
C Much of what is calculated in incai is available elsewhere.
c There are several opportunities to use other common blocks.
      subroutine incai(icomp,ihour)
#include "building.h"
#include "geometry.h"

      common/traceout/icout
      common/cai/caii(ms),caie(ms)
      common/tc/itc,icnt
      common/sangl1/sazi1,salt1
      common/pangl/pazi(ms),pelv(ms),ptilt(ms)

      character outs*124
      logical ok,tok

C If trace is on set tok.
      tok=.false.
      if(icout.eq.33)tok=.true.

      pi = 4.0 * atan(1.0)
      r=pi/180.

C  Cosine of the angle of incidence and surface-solar azimuth angle.
      do 40 i=1,nzsur(icomp)
        if(salt1.gt.0.0)then
          psazi=abs(pazi(i)-sazi1)
          x1=cos(salt1*r)
          x2=sin((90.-pelv(i))*r)
          x3=cos(psazi*r)
          x4=sin(salt1*r)
          x5=cos((90.-pelv(i))*r)
          caie(i)=x1*x2*x3+x4*x5
          paz=pazi(i)+180.0
          if(pazi(i).gt.180.0)paz=pazi(i)-180.0
          psazi=abs(paz-sazi1)
          x3=cos(psazi*r)
          x1=cos(salt1*r)
          x2=sin((90.+pelv(i))*r)
          x3=cos(psazi*r)
          x4=sin(salt1*r)
          x5=cos((90.+pelv(i))*r)
          caii(i)=x1*x2*x3+x4*x5
        else
          caii(i)=0.0
          caie(i)=0.0
        endif
   40 continue

C Trace output, check also that user has asked for detailed trace.
      ok=.false.
      if(itc.eq.2)ok=.true.
      if(tok.and.ok)then
        call edisp(icout,' ')
        write(outs,'(a,i3,a,i3)')'*** INCAI: Hour',ihour,' zone',icomp
        call edisp(icout,outs)
        call edisp(icout,
     &  ' Surface    Internal    External    Azimuth    Elevation')

        do 50 i=1,nzsur(icomp)
          write(outs,2)i,caii(i),caie(i),pazi(i),pelv(i)
    2     format(i5,8x,f6.4,6x,f6.4,7x,f5.1,6x,f5.1)
          call edisp(icout,outs)
   50   continue
      endif
      return
      end

C ********** INSORT **********
C Parameters passed are: ii, the current TMC being processed in inscon
C at hour jj.

      subroutine insort(icomp,ii,jj)
#include "building.h"
#include "geometry.h"

      common/inswin/igins(mox,moz)
      common/pinsol/ins(ms),pins(ms),pinw(ms),pcshad
      common/outin/iuout,iuin
      integer izstocn
      common/c24/izstocn(mcom,ms)

      dimension icounts(ms+4),icountw(ms+4),icountt(ms+4)
      character outs*124

C Initialise.
      ihit=0
      pinrl=0.0
      pintot=0.0
      do 10 i=1,(ms+4)
         icounts(i)=0
         icountw(i)=0
         icountt(i)=0
   10 continue

C Count the number of grid points that project onto each surface.
      do 20 i=1,nox(icomp)
         do 21 j=1,noz(icomp)
            if(igins(i,j).eq.-200)then
               icountt(nzsur(icomp)+3)=icountt(nzsur(icomp)+3)+1
            elseif(igins(i,j).eq.-100)then
               icountt(nzsur(icomp)+1)=icountt(nzsur(icomp)+1)+1
            elseif(igins(i,j).ge.1.and.igins(i,j).le.nzsur(icomp))then
               icounts(igins(i,j))=icounts(igins(i,j))+1
               icountt(igins(i,j))=icountt(igins(i,j))+1
               ihit=ihit+1
            elseif(igins(i,j).le.-1.and.igins(i,j).ge.
     &            (-1*nzsur(icomp)))then
               icountw(abs(igins(i,j)))=icountw(abs(igins(i,j)))+1
               icountt(abs(igins(i,j)))=icountt(abs(igins(i,j)))+1
               ihit=ihit+1
            else
               icountt(nzsur(icomp)+2)=icountt(nzsur(icomp)+2)+1
            endif
   21    continue
   20 continue

C Initialise insolated surfaces.
      do 30 i=1,nzsur(icomp)
         ins(i)=i
   30 continue

C Bubble sort to give highest count to ins(1) etc.
C Sort based on total hits on surface (i.e. icountt).
      do 40 i=1,nzsur(icomp)-1
         do 41 j=1,nzsur(icomp)-1 
            if(icountt(j).lt.icountt(j+1))then
               itemp=icountt(j)
               icountt(j)=icountt(j+1)
               icountt(j+1)=itemp
               itemp=icounts(j)
               icounts(j)=icounts(j+1)
               icounts(j+1)=itemp
               itemp=icountw(j)
               icountw(j)=icountw(j+1)
               icountw(j+1)=itemp
               itemp=ins(j)
               ins(j)=ins(j+1)
               ins(j+1)=itemp
           endif
   41    continue
   40 continue

C Debug.
C      write(6,*) 'zone tmc hour ',icomp,ii,jj,'ihit is ',ihit
C      write(6,*) 'ins is ',ins

C Set insolated planes to zero if there are no hits, i.e. total shading.
      if(ihit.eq.0)then
         do 45 i=1,nzsur(icomp)
            ins(i)=0
            pins(i)=0.0
            pinw(i)=0.0
   45    continue
         pcshad=1.0
         return
      endif   

C Calculate surface insolation proportion of total zone insolation
C (i.e. all insolated surfaces add to 1).
      do 50 i=1,nzsur(icomp)
         pins(i)=real(icounts(i))/(real(ihit))
         pinw(i)=real(icountw(i))/(real(ihit))
   50 continue

C pcshad is the proportion of grid points shaded.
      pcshad=real(icountt(nzsur(icomp)+1))/
     &           (real(ihit+icountt(nzsur(icomp)+1)))

C Re-allocate proportions for surfaces greater than the maximum 
C number of insolated surfaces ('misur').
      do 60 i=(misur+1),nzsur(icomp)
         pinrl=pinrl+pins(i)
         pinrl=pinrl+pinw(i)
   60 continue
      if(pinrl.gt.0.0)then
         do 70 i=1,misur
            pins(i)=pins(i)+(pins(i)*pinrl/(1.0-pinrl))
            pinw(i)=pinw(i)+(pinw(i)*pinrl/(1.0-pinrl))
   70    continue
      endif

C Checks.
      do 80 i=1,misur
         pintot=pintot+pins(i)+pinw(i)
   80 continue
      if(pintot.lt.0.99.or.pintot.gt.1.01)then
         icn=izstocn(icomp,ii)
         write(outs,'(a,f5.3,3a,i2)') 'Warning: solar split is ',
     &                   pintot,' in ',ssname(icn),' at hour ',jj
         call edisp(iuout,outs)
      endif
      return
      end

C ********** TRANSP **********
C This routine transforms a grid point defined relative to a given
C surface back to global co-ordinates.
C     1 - Recover equation of surface (eqn(4)) and centre of 
C         gravity (vp(3)) via pleqn().
C     2 - Set up eye point normal to plane at centre of gravity
C         (ep(3)) and use eyemat() to establish matrix and 
C         reverse matrix that transform surface to normal view.
C     3 - Use orttrn() to find co-ordinates of origin (first
C         surface vertex) when transformed to normal view and
C         apply reverse transformation to give vertices in
C         global co-ordinates.

      subroutine  transp(icc,xx,yy,zz,dx,dz,xxw,yyw,zzw)
#include "building.h"
#include "geometry.h"

C Parameters
      integer icc   ! the model surface connection index
      real xx,yy,zz    ! coordinates passed
      real dx,dz    ! grid location
      real xxw,yyw,zzw  ! transformed coordinate
      real xxx,yyy,zzzz ! for use in last orttrn

      dimension xx(mtv),yy(mtv),zz(mtv)
      dimension tmat(4,4),rmat(4,4)
      dimension vp(3),ep(3)

C Recover eye point and view point for eyemat.
      vp(1)=SSURCOG(icc,1)
      vp(2)=SSURCOG(icc,2)
      vp(3)=SSURCOG(icc,3)
      ep(1)=SSURVN(icc,1)
      ep(2)=SSURVN(icc,2)
      ep(3)=SSURVN(icc,3)

      call eyemat(ep,vp,1.0,tmat,rmat)

C Transform first 2 surface vertices.
      call orttrn(xx(1),yy(1),zz(1),tmat,x1,y1,zzz,ierr)
      call orttrn(xx(2),yy(2),zz(2),tmat,x2,y2,zzz,ierr)
      alpha=atan2((y2-y1),(x2-x1))
      beta=atan2(dz,dx)
      d=sqrt(dx*dx+dz*dz)
      xxw=x1+d*cos(alpha+beta)
      yyw=y1+d*sin(alpha+beta)

C Take each grid point and apply transformation.
      call orttrn(xxw,yyw,zzz,rmat,xxx,yyy,zzzz,ierr)
      xxw=xxx
      yyw=yyy
      zzw=zzzz
      return
      end
