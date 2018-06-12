
PROJECT=`grep '^Package: ' debian/control | cut -d' ' -f2`
REVISION=`grep '^Version: ' debian/control | cut -d' ' -f2`
ARCH=`grep '^Architecture: ' debian/control | cut -d' ' -f2`
SRCURL=https://github.com/PoC-Consortium/burstcoin/releases/download/2.2.1
SRCFILE=burstcoin-2.2.1.zip
DESTDIR=/tmp/$(PROJECT)_$(REVISION)_$(ARCH)
TMPDIR=/tmp/burstcoin
SHAREDIR=$(DESTDIR)/usr/share/$(PROJECT)
ETCDIR=$(DESTDIR)/etc/$(PROJECT)
BINDIR=$(DESTDIR)/usr/bin

.SILENT:

all:  reminder  /tmp/burstcoin  /tmp/burstcoincg_2.2.1_amd64.deb

reminder:
	echo Run this target as fakeroot otherwise the files will be owned by you

/tmp/burstcoin:
	echo Downloading $(SRCFILE)
	cd /tmp/
	wget --quiet  $(SRCURL)/$(SRCFILE)
	mkdir  $(TMPDIR)
	unzip -q  $(SRCFILE) -d $(TMPDIR)
	rm  $(SRCFILE)

/tmp/burstcoincg_2.2.1_amd64.deb:
	install --directory  $(SHAREDIR)
	cp --archive  $(TMPDIR)/*  $(SHAREDIR)
	install --directory  $(BINDIR)
	install --mode=0755 --preserve-timestamps  bin/burst  $(BINDIR)
	install --directory  $(ETCDIR)
	install --mode=0644 --preserve-timestamps  $(TMPDIR)/conf/*  $(ETCDIR)
	install --directory  $(DESTDIR)/lib/systemd
	install --directory  $(DESTDIR)/lib/systemd/system
	install --mode=0644 --preserve-timestamps  systemd/$(PROJECT).service  $(DESTDIR)/lib/systemd/system
	install --directory  $(DESTDIR)/DEBIAN
	install  debian/*  $(DESTDIR)/DEBIAN
	dpkg --build  $(DESTDIR)
	rm -Rf  $(DESTDIR)

clean:
	rm -Rf  $(DESTDIR).deb
	rm -Rf  $(TMPDIR)

