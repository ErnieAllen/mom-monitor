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
use POSIX;
use Filesys::DfPortable;
use File::Slurp;

use qpid_proton;

$Getopt::Std::STANDARD_HELP_VERSION = 1;
my $msg;

sub construct_messages {
    my @messages;

    # get the percent disk full
    push(@messages, get_disk_info());

    # get the virus / malware scan info
    push(@messages, get_scan_info());

    # get the percent backup disk full
    push(@messages, get_backup_info());

    return @messages;
}

# send a message containing a hash with the system's disk info
sub get_disk_info {
    $msg = new qpid::proton::Message();

    my $ref = dfportable("C:/", 1024);  # output is 1K blocks

    if (defined($ref)) {
        $msg->set_body({"disk" => {"size" => $ref->{blocks}, "used" => $ref->{used}}}, qpid::proton::MAP);
    } else {
        $msg->set_body({"disk" => {"size" => "", "used" => "", "error" => "Error getting disk info"}}, qpid::proton::MAP);
    }
    # each datum has its own version in case the format changes
    $msg->get_annotations->{"version"} = 0.1;
    return $msg;
} 

# send a message containing a hash with the contents of a file
sub get_scan_info {
    $msg = new qpid::proton::Message();

    # location of log file on Vista
    # TODO: read the file name from a config file
    my $log_file = "/home/ernie/scan/results.txt";
    my $scan_file_contents = read_file($log_file, err_mode => 'quiet' ); 
    if ($scan_file_contents) {
        $msg->set_body({"scan" => {"date" => strftime("%Y-%m-%d %H:%M:%S", localtime(time)), "results" => $scan_file_contents}}, qpid::proton::MAP);
    } else {
        $msg->set_body({"scan" => {"date" => strftime("%Y-%m-%d %H:%M:%S", localtime(time)), "results" => "", "error" => "error reading file"}}, qpid::proton::MAP);
 
    }
    $msg->get_annotations->{"version"} = 0.1;
    return $msg;
}

# send a message containing a hash with the system's disk info
sub get_backup_info {
    $msg = new qpid::proton::Message();

    my $ref = dfportable("D:/", 1024);  # output is 1K blocks

    if (defined($ref)) {
        $msg->set_body({"backup" => {"size" => $ref->{blocks}, "used" => $ref->{used}}}, qpid::proton::MAP);
    } else {
        $msg->set_body({"backup" => {"size" => "", "used" => "", error => "Error getting backup drive info"}}, qpid::proton::MAP);
    }
    # each datum has its own version in case the format changes
    $msg->get_annotations->{"version"} = 0.1;
    return $msg;
} 

sub VERSION_MESSAGE() {
}

sub HELP_MESSAGE() {
    print "Usage: monitor.pl [OPTIONS] -a <ADDRESS>\n";
    print "Options:\n";
    print "\t-c        - Config file (\$HOME/.config/monitor/monitor.conf)\n";
    print "\t-d        - Disk to check for size (C:/)\n";
    print "\t-b        - Backup disk to check for size (D:/)\n";
    print "\t-s        - Scan file to return (\$HOME/scan/results.txt)\n";
    print "\t-h        - this help message\n";
    print "\t<ADDRESS> - amqp://<domain>[/<name>]\n";
    exit(0);
}

my %options = ();
getopts("a:C:s:h:", \%options) or HELP_MESSAGE();

my $address = $options{a} || "amqp://0.0.0.0";
my $subject = "Computer status messages";

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
