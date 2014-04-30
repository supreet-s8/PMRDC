#!/usr/bin/perl 

use strict;

# Check if the PM scripts have to be skipped for the CLLI site
my $siteCLLI = $1 if($ENV{HOSTNAME} =~ /(\w+)-.+$/);
$siteCLLI =~ s/NSA$//;
foreach my $_clli (split(/\s/, $ENV{SKIPCLLI})) {
  if ($siteCLLI eq $_clli) {
    print 127;
    exit(0);
  }
}

# Get host type vs icn-IP mapping
my $cli_cmd = $ENV{CLI} . ' -t "en" "show cluster global brief"';
my $out = `$cli_cmd`;

my %type_ip;
map {
    my $row = $_;
    $row =~ s/\s+/ /g;
    if($row =~ /.*(master|standby).*\s(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+$/i) {
      $type_ip{lc($1)} = $2;
    }
  } split(/\n/, $out);

my $ifconfig = `/sbin/ifconfig`;

my $host_type;

foreach my $type (keys %type_ip) {
  if($ifconfig =~ m/$type_ip{$type}/) {
    $host_type = $type;
    last;
  }
}

# If master, check if the standy is alive by doing a uptime check
if($host_type eq 'master') {

  my $standby_cmd = $ENV{SSH} . " $type_ip{standby} \"uptime\"";
  my $standby_cmd_out = `$standby_cmd`;

  if($standby_cmd_out =~ /load average/) {
    print 127;
  }
  else {
    print 0;
  }
} 
elsif($host_type eq 'standby') {
  print 0;
}
else {
  print 127;
}

