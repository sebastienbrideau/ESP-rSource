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

C   ntmc & nwins: the number of insolation sources (i.e. external
C                 and transparent surfaces); the latter is held
C                 in common.
C   itmc & isc:   toggles for each surface, if 1 then surface is an
C                 insolation source. The latter is held
C                 in common.
      common/outin/iuout,iuin
      common/pophelp/h(60)
      common/filep/ifil

      common/g0/ctype(mcom),gversion(mcom),igupgrade
      common/g6/ssname(mcon),ssotf(mcon),ssmlcn(mcon),ssvfc(mcon),
     &          ssother(mcon,3),ssparent(mcon),ssuse(mcon,2)
      common/c2/lsnam,nccode(mcom),lproj(mcom),lgeom(mcom),
     &          lshad(mcom),lthrm(mcom),indutl(mcom),lutil(mcom)
      common/c20/nzsur(mcom),nztv(mcom)
      common/c24/izstocn(mcom,ms)
      common/precz/zname(mcom),zdesc(mcom)
      common/mtfile/ltrns,multic,mons,monf
      common/shdfil/ishadf
      common/contr/mon,isc(ms),iyd
      common/tmc/itmc(ms),nwins
      common/sif1/insrts,insrti
      common/ract/paction
      common/ishdirec/iaplic(mcom,2),nsurfcalc(mcom),
     &       lstsfcalc(mcom,ms),nsurfinso(mcom),isurfinso(mcom,ms)

      dimension month(12),iavdec(12),iva(ms)
      character zname*12,ctype*4
      character ssname*12,ssotf*32,ssmlcn*32,ssvfc*4,ssother*24,
     &          ssparent*12,ssuse*8
      character paction*16
      character*72 lsnam,lproj,lgeom,lshad,lthrm,lutil,h
      character month*3,outs*124,tbase*72,ltrns*72,act*1,zdesc*64
      logical ok,dok,xst
      logical newgeo  ! to use for testing if new/old geometry file.

C Day of average solar declination in each month.
      data iavdec/17,15,16,15,15,11,17,16,16,16,15,11/
      data month/'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug',
     &            'Sep','Oct','Nov','Dec'/

      iunit=ifil
      iuf=ifiL+1
      newgeo=.false.  ! Assume older format geometry.

C Read in the geometry file for the current zone to refresh /g1/.
C If newgeo is true then the geometry file can include values
C for /ishdirec/.
      call eclose(gversion(icomp),1.1,0.01,newgeo)
      if(act.eq.'s')then
         if(newgeo)then
            call georead(iuf,lgeom(icomp),icomp,1,0,iuout,ier)
         else
            call egomin(iuf,lgeom(icomp),icomp,1,0,iuout,ier)
         endif
      else
         if(newgeo)then
            call georead(iuf,lgeom(icomp),icomp,1,1,iuout,ier)
         else
            call egomin(iuf,lgeom(icomp),icomp,1,1,iuout,ier)
         endif
      endif
      if(ier.ne.0)then
        call edisp(iuout,'Problem detected while trying to read zone')
        call edisp(iuout,'geometry file - respecify via menu.')
        return
      endif
      ishadf=0

C Establish if any of the surfaces are TMCs.
    4 ntmc=0
      nwins=0

C If new format geometry and iaplic(icomp,2) equals 1 then
C all applicable surfaces were set in the geometry file.
C iaplic(i,2): assessment toggle where 1 means consider all
C              applicable surfaces and 0 means manual selection
C              of surfaces.
C nsurfinso:   number of insolation sources;
C isurfinso:   list of these sources.
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
               iva(I)=0
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
               call usrmsg('No insolation source surfaces found!',
     &                         ' ','W')
               return
            endif
            iaplic(icomp,2)=1
         else
            call edisp(iuout,' ')
            call edisp(iuout,'Select external transparent surfaces')
            call edisp(iuout,'(i.e. light sources) to include in the')
            call edisp(iuout,'intra-zone insolation calculation.')
            call pickssur(icomp,ntmc,'i',iva,ier)
            if(ier.ne.0)return
            if(ntmc.eq.0)goto 11
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

C Check that at least one surface has been selected.
   11 icont=0
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
            h(1)='Surfaces that are sources of sunlight must be'
            h(2)='identified.'
            call askok('No surfaces specified!','Re-specify?',ok,dok,2)
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
         h(1)='An integer value between 1 and 12. For each month a'
         h(2)='24 hour calculation of internal surface insolation'
         h(3)='distribution will be undertaken for the day of average'
         h(4)='solar declination.'
         call easki(mons,' ','Start month number?',
     &              1,'F',12,'F',1,'start month',ier,0)
         if(ier.ne.0)return
         call easki(monf,' ','End month number?',
     &              mons,'F',12,'F',1,'end month',ier,0)
         if(ier.ne.0)return
         mon=mons
      endif

C Convert start month day of average solar declination to a year
C day number.
  81  iday=iavdec(mon)
      call eday(iday,mon,iyd)

C Attempt to open the relevant zone transitional shading file 
C for this month. If unknown call igeoms to set up grid.
      write(ltrns,'(a)')zname(icomp)(1:lnblnk(zname(icomp)))
      write(tbase,'(a,a3)')ltrns(:lnblnk(ltrns)),month(mon)
      call erpfree(iunit,istat)
      call findfil(tbase,xst)

C Allow for number of surfaces within the zone transitional shading
C file.
      irecw=ms+5
      if(xst)then
         call efopran(iunit,tbase,irecw,1,ier)

C Since this file exists, there must have been a matching
C obstruction file and therefore the data in common /GS6/
C can be used.
         ishadf=1
      else
         ishadf=0
         if(mon.eq.mons)call igeoms
      endif

C Commence computation for each specified month and allow user to
C update the zone shading & insolation db.
      write(outs,'(a3,a)')month(mon),' calculation commenced.'
      if(paction(1:13).ne.'update_silent')then
         call usrmsg(outs,' ','-')
      endif
      call insolc(icomp)
      icstat=1
      insrti=0
      call isave(ier)
      mon=mon+1
      if(mon.le.monf)goto 81

      return
      end

C ********** IGEOMS **********
C Establishes the surface grid if a zone transitional shading
C file does not exist.

      subroutine igeoms
#include "building.h"

      common/pophelp/h(60)
      common/g1/x(mtv),y(mtv),z(mtv),nsur,jvn(ms,mv),nver(ms),ntv
      common/gs6/nox,noz,ngx,ngz,blkname(mb),blkmat(mb)
      common/tmc/itmc(ms),nwins
      character blkname*8,blkmat*12,H*72

C Set default grid. Note ngx and ngz relate to old style default
C windows and are no longer used.
      ngx=10
      ngz=10
      nox=20
      noz=20

C Prompt user for opaque grid size because not previously set.
      nwins=0
      do 10 i=1,nsur
        if(itmc(i).ne.0)nwins=nwins+1
   10 continue
      if(nwins.eq.0)return

C Surface X grid density. 
      h(1)='In order to determine the insolation distribution'
      h(2)='a grid is superimposed on each surface. The grid'
      h(3)='resolution must lie between 4 and 50 cells in the'
      h(4)='the X and Z directions.'
      call easki(nox,'Opaque grid:',
     &     'X direction divisions?',
     &     4,'F',50,'F',20,'surf X grid',ier,4)

C Surface Z grid density. 
      call easki(noz,'Opaque grid:',
     &     'Z direction divisions?',
     &     4,'F',50,'F',20,'surf Z grid',ier,4)

      return
      end

C ********** INSOLC **********
C Controls the insolation computation.
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

      common/c20/nzsur(mcom),nztv(mcom)
      common/g1/x(mtv),y(mtv),z(mtv),nsur,jvn(ms,mv),nver(ms),ntv
      common/sunhr/isunhr
      common/gs6/nox,noz,ngx,ngz,blkname(mb),blkmat(mb)
      common/tshd/ioshd(mox,moz)
      common/grid11/xop(mox,moz),zop(mox,moz)
      common/shad1/isunup
      common/cai/caii(ms),caie(ms)
      common/contr/mon,isc(ms),iyd
      common/proji/xp,yp,zp
      common/inswin/igins(mox,moz)
      common/pinsol/ins(ms),pins(ms),pinw(ms),pcshad
      common/stins/insst(mgt,24,misur),pinsst(mgt,24,misur),
     &             shadst(mgt,24)
      common/ract/paction
     
C ical = 0 indicates that no insolation calculations have been
C performed and is set to 1 when they have.
      common/data1/ical
      common/sangl1/sazi1,salt1
      common/tmc/itmc(ms),nwins
      common/icflag/ic
      common/shdinf/noshad
      common/prec8/slat,slon

      dimension xf(mtv),yf(mtv),zf(mtv),ydist(mox,moz)
      character blkname*8,blkmat*12,outs*124,paction*16
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
      do 20 i=1,nwins
         modes=1

C 'noshad' = 0 means that there is no zone transitional shading file
C and 1 if there is but there is no shading information for surface i.
         noshad=0
         if(paction(1:13).ne.'update_silent')then
            call usrmsg(' ',' ','-')
         endif

C Transform and grid the insolation source surface.
         call trnsf1i(i)
         call mesh(i)

C Calculate hour-by-hour.
         do 30 j=1,24
            stime=float(j)
            call eazalts(stime,iyd,slat,slon,isunup,sazi,salt)
            if(isunup.eq.0)goto 1
            sazi1=sazi
            salt1=salt
            if(isunhr.eq.0)isunhr=j
            call incai(j)

C Check whether the grid point falls within the surface.
            do 40 mmm=1,nox
               do 50 nnn=1,noz
                  igins(mmm,nnn)=0
                  ydist(mmm,nnn)=0.0
   50          continue
   40       continue

C Take zone transitional shading file information into account.
            call inwshd(i,j,modes)
            modes=3

C If caie is positive then source surface can be considered.
            if(caie(i).le.0.0)then
               do 60 mmm=1,nox
                  do 70 nnn=1,noz
                     if(igins(mmm,nnn).ne.-200)igins(mmm,nnn)=-100
   70             continue
   60          continue
               goto 2
            endif

C Examine each internal surface for insolation.
            do 80 l=1,nzsur(icomp)

C Exclude a surface that cannot see the source.
               if(i.eq.l.or.caii(l).le.0.0)goto 80

C Derive the transformation equations for this surface.
               call trnsf1i(l)

C Compute new solar angles relative to local surface coordinate system.
               call trnsf2i(j)

C Set up point-by-point analysis.
               do 90 m=1,nox
                  do 100 n=1,noz
                     if(ioshd(m,n).eq.1)then
                        igins(m,n)=-100
                        goto 100
                     endif

C For each undefined point.
                     do 110 inv=1,nver(i)
                        xf(inv)=x(jvn(i,inv))
                        yf(inv)=y(jvn(i,inv))
                        zf(inv)=z(jvn(i,inv))
  110                continue

C Convert local source surface grid point coordinates back
C to global coordinates before initiating projection.
                     call transp(nver(i),xf,yf,zf,xop(m,n),zop(m,n),
     &                           xxw,yyw,zzw)
                     call trnsf3i(xxw,yyw,zzw)
                     if(yp.lt.0.0)goto 100

C Call point containment test; ians is 1 if point is within the
C receiving surface and striking the side opposite the surface
C normal.
                     call point1(l,xp,zp,ians)
                     if(ians.eq.0)goto 100

C Use crowxyz to check real distance between source point (xxw,yyw,zzw)
C and intersection point (xp,yp,zp). Use the nearest intersection
C for igins (not implmented).
                     chkdis=crowxyz(xxw,yyw,zzw,xp,yp,zp)
                     ydist(m,n)=chkdis
                     igins(m,n)=l
  100             continue
   90          continue
   80       continue

C Sort the insolation passing through each insolation source surface.
    2       call insort(icomp,i,j)

C Store for each source and hour.
            do 120 m=1,misur
               insst(i,j,m)=ins(m)
               pinsst(i,j,m)=pins(m)
  120       continue
            shadst(i,j)=pcshad
            kind=kind+1
            calcom=float(kind)/float(kt)
            write(outs,'(a,a3,a)')'`',month(mon),
     &                         '` insolation calculation commenced:'
            if(calcom.ge.0.95)then
               if(indcom.eq.4)goto 30
               indcom=indcom+1
               if(paction(1:13).ne.'update_silent')then
                  call usrmsg(outs,' complete.','P')
               endif
            elseif(calcom.ge.0.75)then
               if(indcom.eq.3)goto 30
               indcom=indcom+1
               if(paction(1:13).ne.'update_silent')then
                  call usrmsg(outs,' 75% complete.','P')
               endif
            elseif(calcom.ge.0.50)then
               if(indcom.eq.2)goto 30
               indcom=indcom+1
               if(paction(1:13).ne.'update_silent')then
                  call usrmsg(outs,' 50% complete.','P')
               endif
            elseif(calcom.ge.0.25)then
               if(indcom.eq.1)goto 30
               indcom=indcom+1
               if(paction(1:13).ne.'update_silent')then
                  call usrmsg(outs,' 25% complete.','P')
               endif
            endif
            goto 30

C Sun not up.
    1       do 130 m=1,misur
               insst(i,j,m)=-1
               pinsst(i,j,m)=0.0
  130       continue
            if(isunup.eq.1)modes=2
   30    continue	! end of hour loop
   20 continue		! end of tmc loop
      ical=1
      return
      end

C ********** inwshd **********
C Reads the transitional shading file if one exists and extracts
C surface shading information.

      subroutine inwshd(isur,ihr,modes)
#include "building.h"

      common/outin/iuout,iuin
      common/filep/ifil
      common/gs6/nox,noz,ngx,ngz,blkname(mb),blkmat(mb)
      common/tshd/ioshd(mox,moz)
      common/sunhr/isunhr
      common/shdfil/ishadf
      common/shdinf/noshad
      common/recshd/irecx

      dimension irecs(ms)
      character blkname*8,blkmat*12,outs*124

      iushd=ifil

      if(ishadf.eq.0.or.noshad.eq.1)goto 1
      goto (2,3,4)modes

C Only transfer here for the first hour every day when sun is up.
    2 irec=1
      read(iushd,rec=irec,iostat=istat,err=1000)(irecs(i),i=1,isur)
      irecn=irecs(isur)
      if(irecn.eq.0)then
          noshad=1
          goto 1
      endif
C Skip records written when sun not up.
      irecx=irecn+2+(isunhr-1)

C Transfer here at all other sun-up hours.
    3 read(iushd,rec=irecx,iostat=istat,err=1000)isunup
C Sun not up must be an error!
      if(isunup.eq.0)goto 1000
      irec=irecx+1
      read(iushd,rec=irec,iostat=istat,err=1000)ians
      irec=irec+1
      if(ians.eq.-2)goto 1
      if(ians.eq.-1)goto 5

C Read surface shading information.
      do 10 i=1,nox
         read(iushd,rec=irec,iostat=istat,err=1000)(ioshd(i,j),j=1,noz)
         irec=irec+1
   10 continue

C Increment irec to skip record holding pso & psof
      irec=irec+1
      goto 4

C Surface is not shaded.
    1 do 20 i=1,nox
         do 30 j=1,noz
            ioshd(i,j)=0
   30    continue
   20 continue
      goto 4

C Surface is fully shaded.
    5 do 40 i=1,nox
         do 50 j=1,noz
            ioshd(i,j)=1
   50    continue
   40 continue

    4 irecx=irec
      return

 1000 write(outs,1001)irec,ihr
 1001 format('INWSHD: Zone Transitional Shading file error, record',i6,
     &       ', hour ',i3)
      call edisp(iuout,outs)
      return
      end

C ********** INCAI **********

      subroutine incai(ihour)
#include "building.h"

      common/g1/x(mtv),y(mtv),z(mtv),nsur,jvn(ms,mv),nver(ms),ntv
      common/traceout/icout
      common/cai/caii(ms),caie(ms)
      common/tc/itc,icnt
      common/sangl1/sazi1,salt1

      dimension pazi(ms),pelv(ms)
      dimension xsum(ms),ysum(ms),zsum(ms)
      character outs*124
      logical ok

      r=atan(1.0)/45.0
      do 10 i=1,nsur
         xs=0.
         ys=0.
         zs=0.
         nv=nver(i)

C Gross surface area.
         do 20 j=1,nv
            k=j+1
            if(j.eq.nv)k=1
            ip1=jvn(i,j)
            ip2=jvn(i,k)
            xs=xs+y(ip1)*z(ip2)-z(ip1)*y(ip2)
            ys=ys+z(ip1)*x(ip2)-x(ip1)*z(ip2)
            zs=zs+x(ip1)*y(ip2)-y(ip1)*x(ip2)
   20    continue
         xsum(i)=xs
         ysum(i)=ys
         zsum(i)=zs
   10 continue

C Azimuth and elevation angles.
      do 30 i=1,nsur
         pazi(i)=90.0
         if(abs(xsum(i)).lt.0.00001)pazi(i)=0.0
         if(xsum(i).lt.0.0)pazi(i)=-90.0
         pelv(i)=90.0
         if(abs(zsum(i)).lt.0.00001)pelv(i)=0.0
         if(zsum(i).lt.0.0)pelv(i)=-90.0
         if(abs(ysum(i)).lt.0.00001)goto 1
         pazi(i)=atan2(xsum(i),ysum(i))
         pazi(i)=pazi(i)/r
    1    srx2y2=sqrt(xsum(i)*xsum(i)+ysum(i)*ysum(i))
         if(pazi(i).lt.0.0)pazi(i)=pazi(i)+360.0
         if(abs(srx2y2).lt.0.00001)goto 30
         pelv(i)=atan2(zsum(i),srx2y2)
         pelv(i)=pelv(i)/r
   30 continue

C  Cosine of the angle of incidence and surface-solar azimuth angle.
      do 40 i=1,nsur
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

C  Trace output.
      if(itc.eq.0)return
      ok=.false.
      if(itc.eq.2)ok=.true.
      if(.not.ok)return

      call edisp(icout,' ')
      write(outs,'(a,i3)')'*** INCAI: Hour',ihour
      call edisp(icout,outs)
      call edisp(icout,
     &' Surface    Internal    External    Azimuth    Elevation')

      do 50 i=1,nsur
         write(outs,2)i,caii(i),caie(i),pazi(i),pelv(i)
    2    format(i5,8x,f6.4,6x,f6.4,7x,f5.1,6x,f5.1)
         call edisp(icout,outs)
   50 continue
      return
      end

C ********** INSORT **********
C Parameters passed are: ii, the current TMC being processed in inscon
C at hour jj.

      subroutine insort(icomp,ii,jj)
#include "building.h"

      common/inswin/igins(mox,moz)
      common/pinsol/ins(ms),pins(ms),pinw(ms),pcshad
      common/g1/x(mtv),y(mtv),z(mtv),nsur,jvn(ms,mv),nver(ms),ntv
      common/g6/ssname(mcon),ssotf(mcon),ssmlcn(mcon),ssvfc(mcon),
     &          ssother(mcon,3),ssparent(mcon),ssuse(mcon,2)
      common/gs6/nox,noz,ngx,ngz,blkname(mb),blkmat(mb)
      common/outin/iuout,iuin
      common/c24/izstocn(mcom,ms)

      dimension icounts(ms+4),icountw(ms+4),icountt(ms+4)
      character blkname*8,blkmat*12,outs*124
      character ssname*12,ssotf*32,ssmlcn*32,ssvfc*4,ssother*24,
     &          ssparent*12,ssuse*8

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
      do 20 i=1,nox
         do 21 j=1,noz
            if(igins(i,j).eq.-200)then
               icountt(nsur+3)=icountt(nsur+3)+1
            elseif(igins(i,j).eq.-100)then
               icountt(nsur+1)=icountt(nsur+1)+1
            elseif(igins(i,j).ge.1.and.igins(i,j).le.nsur)then
               icounts(igins(i,j))=icounts(igins(i,j))+1
               icountt(igins(i,j))=icountt(igins(i,j))+1
               ihit=ihit+1
            elseif(igins(i,j).le.-1.and.igins(i,j).ge.(-nsur))then
               icountw(abs(igins(i,j)))=icountw(abs(igins(i,j)))+1
               icountt(abs(igins(i,j)))=icountt(abs(igins(i,j)))+1
               ihit=ihit+1
            else
               icountt(nsur+2)=icountt(nsur+2)+1
            endif
   21    continue
   20 continue

C Initialise insolated surfaces.
      do 30 i=1,nsur
         ins(i)=i
   30 continue

C Bubble sort to give highest count to ins(1) etc.
C Sort based on total hits on surface (i.e. icountt).
      do 40 i=1,nsur-1
         do 41 j=1,nsur-1 
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

C Set insolated planes to zero if there are no hits, i.e. total shading.
      if(ihit.eq.0)then
         do 45 i=1,nsur
            ins(i)=0
            pins(i)=0.0
            pinw(i)=0.0
   45    continue
         pcshad=1.0
         return
      endif   

C Calculate surface insolation proportion of total zone insolation
C (i.e. all insolated surfaces add to 1).
      do 50 i=1,nsur
         pins(i)=real(icounts(i))/(real(ihit))
         pinw(i)=real(icountw(i))/(real(ihit))
   50 continue

C pcshad is the percentage of grid points shaded and is reported
C in the synopsis.
      pcshad=real(icountt(nsur+1))/(real(ihit+icountt(nsur+1)))

C Re-allocate proportions for surfaces greater than the maximum 
C number of insolated surfaces ('misur').
      do 60 i=(misur+1),nsur
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
C     1 - Find equation of surface (eqn(4)) and centre of 
C         gravity (vp(3)) via pleqn().
C     2 - Set up eye point normal to plane at centre of gravity
C         (ep(3)) and use eyemat() to establish matrix and 
C         reverse matrix that transform surface to normal view.
C     3 - Use orttrn() to find co-ordinates of origin (first
C         surface vertex) when transformed to normal view and
C         apply reverse transformation to give vertices in
C         global co-ordinates.

      subroutine  transp(n,x,y,z,dx,dz,xxw,yyw,zzw)
#include "building.h"

      dimension x(mtv),y(mtv),z(mtv)
      dimension tmat(4,4),rmat(4,4)
      dimension vp(3),ep(3),eqn(4)

C Get center of surface and surface equation.
      call pleqn(x,y,z,n,vp,eqn,ier)
      if(ier.lt.0)return

C Find transformation matrices that normalise face.
      do 10 j=1,3
         ep(j)=vp(j)+eqn(j)
   10 continue
      call eyemat(ep,vp,1.0,tmat,rmat)

C Transform first 2 surface vertices.
      call orttrn(x(1),y(1),z(1),tmat,x1,y1,zzz,ierr)
      call orttrn(x(2),y(2),z(2),tmat,x2,y2,zzz,ierr)
      alpha=atan2((y2-y1),(x2-x1))
      beta=atan2(dz,dx)
      d=sqrt(dx*dx+dz*dz)
      xxw=x1+d*cos(alpha+beta)
      yyw=y1+d*sin(alpha+beta)

C Take each grid point and apply transformation.
      call orttrn(xxw,yyw,zzz,rmat,xx,yy,zz,ierr)
      xxw=xx
      yyw=yy
      zzw=zz
      return
      end