SRCdir = `pwd`/..
BLDdir = $(SRCdir)/esrubld
COMdir = $(SRCdir)/esrucom
MFSdir = $(SRCdir)/esrumfs
LIBdir = $(SRCdir)/lib
PRJdir = $(SRCdir)/esruprj
CETCdir = $(SRCdir)/cetc
BLDdir = $(SRCdir)/esrubld
PROG = net$(EXE)

.SUFFIXES: .o .F .c
.F.o:
	$(MFC) $(FFLAGS) -c $<

OBJECTS = aim2_module.o arrow.o ascii_mat.o basesimp.o basesimp_inputs.o bscoeff.o bscoeff_extended.o \
	common3dv.o egeometry.o edatabase.o e3dviews.o emfnetw.o eroper.o \
	esru_misc.o  filelist.o icndbscn.o mfcdat.o netwedit.o network.o nwkrewr.o netwkc2f.o \
	netutil.o read3dv.o sort.o startup.o

MODULES = aim2.mod aim2_calcdata.mod aim2_h2k_dummy.mod aim2_inputdata.mod

$(PROG): $(OBJECTS) $(C_OBJ)
	$(MFC) $(LD_FLAGS) -o $(PROG) $(FFLAGS) $(CFLAGS) $(OBJECTS) $(ULIBS)

aim2_module.F:
	rm -f aim2_module.F
	ln -s $(BLDdir)/aim2_module.F .
arrow.F:
	rm -f arrow.F
	ln -s $(COMdir)/arrow.F .
ascii_mat.F:
	rm -f ascii_mat.F
	ln -s $(COMdir)/ascii_mat.F .
basesimp.F:
	rm -f basesimp.F
	ln -s $(BLDdir)/basesimp.F .
basesimp_inputs.F:
	rm -f basesimp_inputs.F
	ln -s $(PRJdir)/basesimp_inputs.F .
bscoeff.F:
	rm -f bscoeff.F
	ln -s $(BLDdir)/bscoeff.F .
bscoeff_extended.F:
	rm -f bscoeff_extended.F
	ln -s $(CETCdir)/bscoeff_extended.F .
common3dv.F:
	rm -f common3dv.F
	ln -s $(COMdir)/common3dv.F .
edatabase.F:
	rm -f edatabase.F
	ln -s $(COMdir)/edatabase.F .
egeometry.F:
	rm -f egeometry.F
	ln -s $(COMdir)/egeometry.F .
e3dviews.F:
	rm -f e3dviews.F
	ln -s $(COMdir)/e3dviews.F .
emfnetw.F:
	rm -f emfnetw.F
	ln -s $(COMdir)/emfnetw.F .
eroper.F:
	rm -f eroper.F
	ln -s $(COMdir)/eroper.F .
esru_misc.F:
	rm -f esru_misc.F
	ln -s $(COMdir)/esru_misc.F .
filelist.F:
	rm -f filelist.F
	ln -s $(COMdir)/filelist.F .
mfcdat.F:
	rm -f mfcdat.F
	ln -s $(MFSdir)/mfcdat.F .
nwkrewr.F:
	rm -f nwkrewr.F
	ln -s $(COMdir)/nwkrewr.F .
read3dv.F:
	rm -f read3dv.F
	ln -s $(PRJdir)/read3dv.F .
sort.F:
	rm -f sort.F
	ln -s $(COMdir)/sort.F .
startup.F:
	rm -f startup.F
	ln -s $(COMdir)/startup.F .

strip:
	@if [ -f $(PROG) ]; then strip $(PROG); fi

install:
	@if [ -f $(PROG) ]; then cp $(PROG) $(ESPBinDir); fi

clean:
	rm -f core $(PROG) $(PROG).exe $(OBJECTS) $(MODULES) \
	*.o aim2_module.F arrow.F ascii_mat.F basesimp.F basesimp_inputs.F bscoeff.F bscoeff_extended.F \
	common3dv.F edatabase.F egeometry.F e3dviews.F emfnetw.F eroper.F \
	esru_misc.F filelist.F nwkrewr.F read3dv.F mfcdat.F sort.F startup.F
