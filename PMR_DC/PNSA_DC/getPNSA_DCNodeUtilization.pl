#!/usr/bin/perl

# Fetch SAR data for CPU and Memory utilization for the current hour at 5 minute interval

use strict;
use POSIX qw(strftime);

BEGIN{
  push @INC, "$ENV{BASEPATH}/PNSA_DC";
}

my $script_name = [split(/\//, $0)]->[-1];

##############
# An option to execute site specific PM scripts.
# The site specific script has to have the same filename as the default script,
# and stored in path PNSA_DC/<CLLI Name>/$0

if (-f "$ENV{BASEPATH}/PNSA_DC/$ENV{CLLI}/$script_name") {
  print `$ENV{BASEPATH}/PNSA_DC/$ENV{CLLI}/$script_name`;
  exit(0);
}
##############

my $TIMESTAMP = `$ENV{DATE} "+%Y%m%d-%H%M"`; chomp($TIMESTAMP);

#writelog
write_log("Executing version:$ENV{VERSION}-default");

use IPmap;
use Data::Dumper;

# Get Application host and ICN-IP mapping
my $AppIPmap = new AppIPmap();
my $appVSip = $AppIPmap->getAppICNMaping();

my $START     = `$ENV{DATE} +"%H:50:00" -d "1 hour ago"`; chomp($START);
my $END       = `$ENV{DATE} +"%H:59:00"`; chomp($END);

foreach my $app (keys %$appVSip) {
  foreach my $ip (@{$appVSip->{$app}}) {
    
    # Get CPU Utilization and interpolate for 5 minute
    my $CPU_util_cmd = "$ENV{SSH} $ip \"$ENV{SADF} -D -s $START -e $END\" | grep -v 'hostname;interval;timestamp'";
    my $CPU_util_cmd_out = `$CPU_util_cmd`;

    map {
      my @row = split(/\;/, $_);
      my $siteCLLI = $1 if($row[0] =~ /(\w+)NSA-A.+/);

      # sar sometimes gives a null output i.e epoch zero. filter it out.
      if(defined $row[2]) {
        printf "%s, %s, %s, CPU_utilization, %0.2f\n", strftime("%Y%m%d-%H%M",localtime($row[2])), $siteCLLI, $row[0], 100-$row[-1];
        printf "%s, %s, %s, CPU_utilization, %0.2f\n", strftime("%Y%m%d-%H%M",localtime($row[2]+300)), $siteCLLI, $row[0], 100-$row[-1];
      }

    } split(/\n/, $CPU_util_cmd_out);


    # Get Mem Utilization and interpolate for 5 minute
    my $Mem_util_cmd = "$ENV{SSH} $ip \"$ENV{SADF} -D -s $START -e $END -- -r \" | grep -v 'hostname;interval;timestamp'";
    my $Mem_util_cmd_out = `$Mem_util_cmd`;

    map {
      my @row = split(/\;/, $_);
      my $siteCLLI = $1 if($row[0] =~ /(\w+)NSA-A.+/);

      # sar sometimes gives a null output i.e epoch zero. filter it out.
      if(defined $row[2]) {
        printf "%s, %s, %s, Memory_utilization, %0.2f\n", strftime("%Y%m%d-%H%M",localtime($row[2])), $siteCLLI, $row[0], $row[5];
        printf "%s, %s, %s, Memory_Utilization, %0.2f\n", strftime("%Y%m%d-%H%M",localtime($row[2]+300)), $siteCLLI, $row[0], $row[5];
      }

    } split(/\n/, $Mem_util_cmd_out);

  }
}

sub write_log {
  my $msg = shift;

  open(LOGF, ">>$ENV{LOGFILE}") or print "Unable to write to $ENV{LOGFILE}\n";
  print LOGF "$TIMESTAMP [$script_name] $msg\n";
  close(LOGF);
}
