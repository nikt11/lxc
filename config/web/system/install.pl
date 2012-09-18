#!/usr/bin/perl
#
# OVH web server installation script
# Rootnode, http://rootnode.net
#
# Copyright (C) 2012 Marcin Hlybin
# All rights reserved.
#
# Parition settings
# Primary ext4 40960M RAID1
# Swap 16384M (2x)

use warnings;
use strict;


Readonly my $REPO_DIR => '/lxc/repo';

my $network;

GetOptions(
	netmask      => \$network->{netmask},
	network      => \$network->{network},
	broadcast    => \$network->{broadcast},
	gateway      => \$network->{gateway},
	system       => \$network->{system},
	service      => \$network->{service},
	container    => \$network->{container},
	lxc          => \$network->{lxc},
);

# Network configuration
Readonly my $NETWORK_LXC_NETMASK => '16';
foreach my $address (keys %$network) {
	defined $network->{$address} or die "Network $address not defined.";
}

# /etc/network/interfaces
-f "$REPO_DIR/config/web/etc/network/interfaces" or die "File /etc/network/interfaces not found in repo.";

