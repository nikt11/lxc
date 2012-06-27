#!/usr/bin/perl
#
# Apache2 & Nginx init script
# Rootnode, http://rootnode.net
#
# Copyright (C) 2012 Marcin Hlybin
# All rights reserved.
#

use warnings;
use strict;
use Readonly;
use File::Basename qw(basename);
use Smart::Comments;

Readonly my $NGINX_BIN      => '/usr/local/nginx/sbin/nginx';
Readonly my $APACHE2_BIN    => '/usr/sbin/apache2';
Readonly my $APACHE2CTL_BIN => '/usr/sbin/apache2ctl';
Readonly my $PKILL_BIN      => '/usr/bin/pkill';
Readonly my $PGREP_BIN      => '/usr/bin/pgrep';
Readonly my %COMMAND => {
	# Start web server
	start => {
		apache2 => "$APACHE2CTL_BIN start",
		nginx   => "$NGINX_BIN",
	},
	# Stop web server
	stop => {
		apache2 => "$APACHE2CTL_BIN stop",
		nginx   => "$PKILL_BIN -f $NGINX_BIN",
	},
	# Kill web server processes
	kill => {
		apache2 => "$PKILL_BIN -9 -f $APACHE2_BIN",
		nginx   => "$PKILL_BIN -9 -f $NGINX_BIN",
	},
	# Test configuration
	test => {
	        apache2 => "$APACHE2CTL_BIN -t 2>&1",
		nginx   => "$NGINX_BIN -t 2>&1",
	},
	# Check server processes
	check => {
		apache2 => "$PGREP_BIN -c -f $APACHE2_BIN",
		nginx   => "$PGREP_BIN -c -f $NGINX_BIN",
	},
};
Readonly my $BASENAME => basename($0);
Readonly my $USAGE => <<END_OF_USAGE;
Apache2 & Nginx init script
\033[1mUsage:\033[0m 
	apache2 start, stop, restart, status, test
	nginx   start, stop, restart, status, test

END_OF_USAGE

# Check system binaries
-f $NGINX_BIN      or die "\$NGINX_BIN ($NGINX_BIN) not found. Cannot proceed.\n";
-f $APACHE2_BIN    or die "\$APACHE2_BIN ($APACHE2_BIN) not found. Cannot proceed.\n";
-f $APACHE2CTL_BIN or die "\$APACHE2CTL_BIN ($APACHE2CTL_BIN) not found. Cannot proceed.\n";
-f $PKILL_BIN      or die "\$PKILL_BIN ($PKILL_BIN) not found. Cannot proceed.\n";
-f $PGREP_BIN      or die "\$PGREP_BIN ($PGREP_BIN) not found. Cannot proceed.\n";

# Get service name (apache2 or nginx)
my $server_type = $BASENAME;
if ($server_type ne 'apache2' and $server_type ne 'nginx') {
	die "Unknown service name '$server_type'.\nSymlink to this script binary should be named apache2 or nginx.\n";
}

# Get command name from command line
my $command_name = shift or usage();
   $command_name eq 'help' and usage();

if (not defined $main::{$command_name}) {
        die "Command '$command_name' not found. See '$BASENAME help'.\n";
}

# Run subroutine
eval "$command_name(\$server_type)";
die $@ if $@;
exit;

sub start {
	my ($server_type) = @_;
		
	# Print information
	print "Starting $server_type... ";

	# Check web server process
	my $server_is_running = check_procs($server_type);
	if ($server_is_running) {
		die "already running\n";
	}

	# Check configuration
	my $test_result = test_config($server_type);
	if (defined $test_result) {
		print "failed!\n";
		die "$test_result\n";
	}

	# Start web server
	my $start_command = $COMMAND{start}->{$server_type};
	system($start_command);
	if ($?) {
		print "failed!\n";
		die "$!\n";
	}

	print "done\n";
	return;
}

sub stop {
	my ($server_type) = @_;
	
	# Print information
	print "Stopping $server_type... ";

	# Check web server process
	my $server_is_running = check_procs($server_type);
	if (! $server_is_running) {
		die "not running\n";
	}

	# Stop web server
	my $stop_command = $COMMAND{stop}->{$server_type};
	system($stop_command);
	if ($?) {
		
		print "failed!\n";
		die "$!\n";
	}
	sleep 5;

	# Check if server stopped
	my $server_still_running = check_procs($server_type);
	if ($server_still_running) {
		my $kill_command = $COMMAND{kill}->{$server_type};
		system($kill_command);
		die "cannot stop, server killed with kill -9\n";
	}
	
	print "done\n";
	return;
}

sub restart {
	# Run stop and start
	my ($server_type) = @_;

	# Stop server
	eval { stop($server_type) };
	print $@ if $@;

	# Start server
	eval { start($server_type) }; 
	print $@ if $@;

	return;
}

sub status {
	# Show server status
	my ($server_type) = @_;
	my $server_is_running = check_procs($server_type);
	if ($server_is_running) {
		print "$server_type is running.\n";
	}
	else { 
		die "$server_type is NOT running.\n";
	}
	
	return;
}

sub test {
	# Test server configuration
	my ($server_type) = @_;
	my $test_result = test_config($server_type);
	
	# Test failed
	die "$test_result\n" if defined $test_result;

	# Test OK
	print "OK\n";
	return;
}

sub check_procs {
	my ($server_type) = @_;

	# Get number of running processes
	my $number_of_procs = `$COMMAND{check}->{$server_type}`;
	chomp $number_of_procs;

	return $number_of_procs;
}

sub test_config {
	my ($server_type) = @_;

	# Test configuration
	my $test_result = `$COMMAND{test}->{$server_type}`;
	chomp $test_result;
	
	# Return results if test failed
	return $test_result if $?;
	return;
}

sub usage {
	print $USAGE;
	exit;
}
