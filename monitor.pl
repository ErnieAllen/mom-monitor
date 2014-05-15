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
use Getopt::Std;
use Filesys::DfPortable;
use Data::Dumper;
use File::ReadBackwards;

use qpid_proton;

$Getopt::Std::STANDARD_HELP_VERSION = 1;
sub HELP_MESSAGE() {
    print "Usage: monitor.pl [OPTIONS] -a <ADDRESS>\n";
    print "Options:\n";
#    print "\t-c        - Config file (\$HOME/.config/monitor/monitor.conf)\n";
    print "\t-d        - Directory to check for size (/)\n";
    print "\t-a        - Address amqp://<domain>[/<name>] (amqp://0.0.0.0)\n";
    print "\t-h        - This help message\n";
    exit(0);
}

my $msg;
my %options = ();
getopts("c:d:a:h:", \%options) or HELP_MESSAGE();

my $address = $options{a} || "amqp://0.0.0.0";
my $subject = "Computer status messages";
my $dir = $options{d} || "/";

sub construct_messages {
    my @messages;

    # get the percent disk full
    push(@messages, get_disk_info());

    # get the log file errors
    push(@messages, get_log_info());

    return @messages;
}

# send a message containing a hash with the system's disk info
sub get_disk_info {
    $msg = new qpid::proton::Message();

    my $ref = dfportable($dir, 1024);  # output is 1K blocks

    if (defined($ref)) {
        $msg->set_body({"disk" => {"size" => $ref->{blocks}, "used" => $ref->{bavail}}}, qpid::proton::MAP);
    } else {
        $msg->set_body({"disk" => {"size" => "", "used" => "", "error" => "Error getting disk info for $dir"}}, qpid::proton::MAP);
    }
    # each datum has its own version in case the format changes
    $msg->get_annotations->{"version"} = 0.1;
#print Dumper($msg->get_body());

    return $msg;
} 

# grep through some log files looking for the word "fail" and send the last matching lines back 
sub get_log_info {

    my $log_dir = "/var/log";
    my @log_files = qw/messages wtmp dmesg/;
	my $lim = 100; # read last 100 lines of the files

	my %fails = ();
    $msg = new qpid::proton::Message();
	foreach my $name (@log_files) {

	    my $bw = File::ReadBackwards->new( "$log_dir/$name" );
		if ( $bw ) {

			while( defined( my $line = $bw->readline ) ) {
				if ($line =~ /fail/i ) {
					push @{$fails{ $name }}, $line;
					last if --$lim <= 0;
				}
			}
		}
	}
#print Dumper(\%fails);
	$msg->set_body({"logs" => \%fails}, qpid::proton::MAP);
    $msg->get_annotations->{"version"} = 0.1;
    return $msg;

}


my $messenger = new qpid::proton::Messenger();

$messenger->start();

my @messages = construct_messages();

foreach my $msg (@messages)
{
    $msg->set_address($address);
    $msg->set_subject($subject);
    $msg->set_property("sent", "" . localtime(time));
    
    $messenger->put($msg);
}

$messenger->send();
$messenger->stop();

die $@ if ($@);
