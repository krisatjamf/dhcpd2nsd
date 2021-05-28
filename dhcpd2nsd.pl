#!/usr/bin/perl

use DNS::ZoneParse;
use DateTime::Format::Strptime;
use Clone 'clone';
use Data::Dumper;
use Sys::Syslog;

### Config Variables ###

my $zone_file = "/var/nsd/zones/master/your.local.domain.local";

### Code ###

openlog('dhcpd2nsd', undef, 'LOG_DAEMON');
%leases = %{extract_leases()};
my $zone = DNS::ZoneParse->new($zone_file);
compare_zone_leases();

sub compare_zone_leases() {

	$zone_updated = 0;
	$zone_deleted = 0;

	my @a = @{$zone->a()};

	my %soa = %{$zone->soa};
	my $domain = '';

	my $marker_ttl = $soa{'ttl'} - 59;

	if ($soa{'origin'} =~ /\.$/) {
		$domain = $soa{'origin'};
	}
	else {
		$domain = $soa{'origin'} . $soa{'ORIGIN'};
	}

	foreach (@a) {
		my %record = %{$_};

		foreach (keys(%leases)) {
			my $lease = $_;

			if ( $leases{$lease}{'client-hostname'} eq $record{'name'} ) {
				if ( $lease == $record{'host'} ) {
					#matched hostname and IP to lease
					$leases{$lease}{'matched'} = 1;
				}
				else {
					# matched hostname but not IP
					$record{'host'} = $lease;
					$zone_updated++;
				}
			}
		}
	}
	foreach (keys(%leases)) {
		my $lease = $_;

		unless ($leases{$lease}{'matched'}) {
			$a_ref = $zone->a();
			if ($leases{$lease}{'client-hostname'}) {
				push (@$a_ref, { name => $leases{$lease}{'client-hostname'}, class => 'IN', host => $lease, ttl => $marker_ttl, ORIGIN => $soa{'ORIGIN'} } );
				$leases{$lease}{'matched'} = 1;
				$zone_updated++;
			}
		}
	}

	foreach (@a) {
		my %record = %{$_};
		if ($record{'ttl'} == $marker_ttl) {
			unless ( exists($leases{$record{'host'}}) ) {
				$_->{'ORIGIN'} = '.deleted.';
				$zone_deleted++;
			}
		}
	}

	if ($zone_updated or $zone_deleted) { 
		$zone->new_serial(1);
		$zone_string = $zone->output();
		my @lines = split(/\n/, $zone_string);
		my @new_lines;

		foreach (@lines) {
			if ( $_ =~ /^([\w-_\@\d]+)\s+(.*)$/ ) {

				$host = $1;
				$details = $2;

				if ($details =~ /^\d+/ and length($host) > 7 ) {
					push( @new_lines, "$host\t\t$details" );
				}
				elsif ($details =~ /^\d+/) {
					push( @new_lines, "$host\t\t\t$details" );
				}
				elsif ( length($host) > 7 and length($host) < 16 ) {
					push( @new_lines, "$host\t\t\t$details" );
				}
				elsif (length($host) > 15 ) {
					push( @new_lines, "$host\t$details" );
				}
				else {
					push( @new_lines, "$host\t\t\t\t$details" );
				}
			}
			else {
				push (@new_lines, $_);
			}
		}
		$new_string = join("\n", @new_lines);
		open (ZONE, ">$zone_file");
		print ZONE "$new_string\n";
		close ZONE;

		open (PID, "/var/nsd/run/nsd.pid");
		my $pid = <PID>;
		close PID;

		kill 'HUP', $pid;

		syslog('notice', "Updated NSD: added $zone_updated and deleted $zone_deleted records"); 
	}
}

sub extract_leases() {

	open( LEASE, '/var/db/dhcpd.leases' );
	my @lines = <LEASE>;
	close LEASE;

	my %leases;
	my $lease; 
	my %tmp;

	foreach (@lines) {

		if ( $_ =~ /^lease\s+(.*)\s+\{$/ ) {
			$lease = $1;
		}
		elsif ( $_ =~ /^\s*\}\s*$/ ) {
			# validate

			my $parser = DateTime::Format::Strptime->new(
  				pattern => '%Y/%m/%d %H:%M:%S %Z',
  				on_error => 'croak',
			);

			$now = time();
			$dt = $parser->parse_datetime($tmp{'ends'});

			if ( $now < $dt->epoch ) {
				$leases{$lease} = \%{clone(\%tmp)}; 
			}

			%tmp = undef;
		}
		else {
			if ($_ =~ /\s+([\w+-_]+)\s*(.*);/) {
				my $key = $1;
				my $value = $2;

				$value =~ s/[\"\']//g;

				if ($key == 'starts' or $key == 'ends') {
					$value =~ s/^\s*\d+\s+//; 
				}

				$tmp{$key} = $value;
			}
		}
	}

	open( CONF, '/etc/dhcpd.conf' );
	my @lines = <CONF>;
	close CONF;

	my $reservation;
	
	foreach (@lines) {
		my $line = $_;

		if ($line =~ /^\s+host\s([\w-_]+)\s+.*$/) {
			$reservation = $1;
		}
		elsif ($line =~ /^\s+fixed\-address\s+(.*);/) {
			$host = $1;
			$leases{$host}{'client-hostname'} = $reservation;
		}
	}

	return \%leases;
}
