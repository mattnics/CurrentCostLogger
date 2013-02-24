#!/usr/bin/perl -w

# Reads data from a Current Cost device via USB port and logs it to a file
# and RRDtool round-robin database.

# Forked from Jack Kelly's Perl script: https://github.com/JackKelly/CurrentCostLogger which itself was…
# Based on Paul Mutton's excellent Perl script and tutorial: http://www.jibble.org/currentcost/
# with modifications from Jamie Bennett: http://www.linuxuk.org/2008/12/currentcost-and-ubuntu/

# This module requires the Device::SerialPort Perl module.  Install this using Perl's package manager:
# At the Linux command line, type:
#    sudo perl -MCPAN -e shell
# And then type:
#    install Device::SerialPort
# Alternatively, in Debian/Ubuntu:
#    apt-get install libdevice-serialport-perl

# Also requires RRDtool: http://oss.oetiker.ch/rrdtool/
#    apt-get install rrdtool

use strict;
use Device::SerialPort qw( :PARAM :STAT 0.07 );
use POSIX qw(strftime);

use sigtrap 'handler', \&clean_exit, 'normal-signals';

my $PORT    = "/dev/ttyUSB0";
my $LOGFILE = "data.txt";
my $DUMP    = "input.xml";

print "Current Cost logger...\n";

my $ob = Device::SerialPort->new($PORT);
$ob->baudrate(57600);
$ob->write_settings;

open(SERIAL, "+>$PORT");
print "Opened serial port.\n";
print "Unix  time\tPower\tDD/MM/YEAR HH:MM:SS\tt °C\n";

open(MYFILE, ">>$LOGFILE");
open(DUMP, ">>$DUMP");
$| = 1;

# Check at most once per second
while (sleep 1) {
	while (my $line = <SERIAL>) {
		print DUMP $line;
		if ($line =~ m!<time>(\d+):(\d+):(\d+)</time><tmpr> ?([0-9.-]+)</tmpr>.*<ch1><watts>(\d+)</watts></ch1>!) {
			# For Perl regex help, see http://www.cs.tut.fi/~jkorpela/perl/regexp.html
			# For Current Cost XML details, see http://www.currentcost.com/cc128/xml.htm

			# Data from Current Cost EnviR device:
			my $hours = $1;
			my $mins  = $2;
			my $secs  = $3;
			my $temp  = $4;
			my $watts = $5;

			# Get today's date from local Linux host computer
			my $datetime = strftime('%d/%m/%Y %H:%M:%S', localtime());
			my $unixtime = strftime('%s', localtime());

			my $output = "$unixtime\t$watts\t$datetime\t$temp\n";
			print $output;

			# Update RRDtool database
			qx(rrdtool update powertemp.rrd N:$watts:$temp);

			# Log the output to file
			# Open and close on every iteration to flush it to disk every iteration
			print MYFILE $output;
		}
	}
}

sub clean_exit {
	close(MYFILE);
	close(SERIAL);
	close(DUMP);
	print "Exiting\n";
	exit 0;
}
