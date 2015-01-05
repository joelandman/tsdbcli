all:	install

INSTPATH?=/opt/scalable/influxdb-cli


SUDO 		?= /usr/bin/sudo
INSTALL 	?= ${SUDO} /usr/bin/install

install: deps
		# make directory tree if needed
		$(INSTALL) -d ${INSTPATH}
		$(INSTALL) -d ${INSTPATH}/lib/Scalable
		# install binary and package files
		$(INSTALL) --backup=numbered influxdb-cli.pl ${INSTPATH}
		$(INSTALL) --mode=0644 --backup=numbered ABOUT README.md TODO WARRANTY LICENSE ${INSTPATH}
		# install library
		$(INSTALL) --backup=numbered lib/Scalable/TSDB.pm ${INSTPATH}/lib/Scalable
		echo "please run 'sudo ln -s ${INSTPATH}/influxdb-cli.pl /usr/local/bin' if you wish to avoid using the full path ${INSTPATH}/influxdb-cli.pl"
		touch install

deps:
		$(SUDO) cpan Term::ReadLine Term::ReadLine::Gnu Text::ASCIITable Getopt::Lucid JSON::PP LWP::UserAgent
		touch deps		


clean:	
		rm -f install deps