#!/usr/bin/perl -w

use strict;

#
# Notes: compute-1-1 was actually used as the head node. Is this still the
# case?
#
my @node_nums = (1..13);

my $cmd = shift;

unless ($cmd) {
    die "No command to run on nodes specified\n";
}

my $out;
foreach my $node_num (@node_nums) {
    my $node = "compute-1-$node_num.local";

    $out = `exec 2>&1; ssh $node $cmd`;

    if ($out) {
        print "$node: $cmd - $out\n";
    }
}
