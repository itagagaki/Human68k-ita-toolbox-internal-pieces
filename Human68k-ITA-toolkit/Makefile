#! A:/bin/MAKE.X -f
# Makefile for ITA TOOLKIT

AS	= \usr\pds\HAS.X -l -i $(INCLUDE)
LK	= \usr\pds\hlk.x -x
CV      = -\bin\CV.X -r
INSTALL = copy
BACKUP  = A:\bin\COPYALL.X -t
CP      = copy
RM      = -\usr\local\bin\rm -f

INCLUDE = ../fish/include

DESTDIR   = A:\usr\local\bin
BACKUPDIR = B:\toolkit

EXTLIB = $(HOME)/fish/lib/ita.l

###

PROGRAMS = \
	cat.x \
	cbreak.r \
	cdate.r \
	ctime.r \
	cverify.r \
	df.r \
	head.x \
	humanver.r \
	lock.r \
	login.x \
	mf.x \
	mkdir.x \
	pause.r \
	rmdir.x \
	screen.r \
	tee.x \
	vol.r \
	wc.x \
	yow.x

###

.PHONY: all clean clobber install backup

.TERMINAL: *.h *.s

%.r : %.x	; $(CV) $<
%.x : %.o	; $(LK) $< $(EXTLIB)
%.o : %.s	; $(AS) $<

###

all:: $(PROGRAMS)

clean::

clobber:: clean
	$(RM) *.bak *.$$* *.o *.x

###

$(PROGRAMS) : $(INCLUDE)/doscall.h $(INCLUDE)/chrcode.h $(EXTLIB)
vol.r : filemode.h

install::
	$(INSTALL) cat.x $(DESTDIR)
	$(INSTALL) head.x $(DESTDIR)
	$(INSTALL) lock.r $(DESTDIR)
	$(INSTALL) login.x $(DESTDIR)
	$(INSTALL) mkdir.x $(DESTDIR)
	$(INSTALL) rmdir.x $(DESTDIR)
	$(INSTALL) tee.x $(DESTDIR)
	$(INSTALL) wc.x $(DESTDIR)

backup::
	$(BACKUP) *.* $(BACKUPDIR)

clean::
	$(RM) $(PROGRAMS)

###
