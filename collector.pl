#!/usr/bin/env perl
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

use strict;
use warnings;
use Data::Dumper;
use JSON;

use qpid_proton;

sub usage {
    exit(0);
}

my @addresses = @ARGV;
@addresses = ("~0.0.0.0") unless $addresses[0];

my $messenger = new qpid::proton::Messenger();
my $msg = new qpid::proton::Message();

$messenger->start();

foreach (@addresses)
{
    print "Subscribing to $_\n";
    $messenger->subscribe($_);
}

for(;;)
{
    $messenger->receive(10);

    while ($messenger->incoming() > 0)
    {
        $messenger->get($msg);
		process_msg($msg);

    }
}

sub process_msg {
	my ($m) = @_;

#	print "Address:  " . $m->get_address() . "\n";
#	print "Subject:  " . $m->get_subject() . "\n";
#	print "Body type " . $m->get_body_type() . "\n";
#	print "Body:     " . Dumper(\$m->get_body()) . "\n";
#	print "Properties:\n";
#	print "Annotations:\n";
#	my $annotations = $m->get_annotations();
#	foreach (keys $annotations) {
#		print "\t$_=" . $annotations->{$_} . "\n";
#	}


	my $annotations = $m->get_annotations();
	print "Got a " . $annotations->{type} . " message\n";
	my $b = $m->get_body();
	my %body = %{decode_json $b};
	print $body{ size } if $annotations->{ type } eq "disk";
}


die $@ if ($@);
