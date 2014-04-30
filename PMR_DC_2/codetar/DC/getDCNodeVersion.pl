#!/usr/bin/perl

# Fetch node version and patch level information once daily.

use strict;
use POSIX qw(strftime);

BEGIN{
  push @INC, "$ENV{BASEPATH}/DC";
}

my $script_name = [split(/\//, $0)]->[-1];

##############
# An option to execute site specific PM scripts.
# The site specific script has to have the same filename as the default script,
# and stored in path DC/<CLLI Name>/$0

if (-f "$ENV{BASEPATH}/DC/$ENV{CLLI}/$script_name") {
  print `$ENV{BASEPATH}/DC/$ENV{CLLI}/$script_name`;
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

# Print software version #
foreach my $app (keys %$appVSip) {
  foreach my $ip (@{$appVSip->{$app}}) {

    # Get Node Version and Patch level
    my $version_cmd = "$ENV{SSH} $ip \" $ENV{CLI}  \'show version'\" 2>/dev/null | grep -i \"Product release\"";
    my $version_cmd_out = '';
    $version_cmd_out = `$version_cmd 2>/dev/null`;
    my $version = '';

    map {
      my @row = split(/\:/, $_);
      $version = $row[1];
      chomp $version;
      $version =~ s/^\s+//g ;
    } split(/\n/, $version_cmd_out);

    $version="" if($version !~ /\w+/);

    my $host_cmd="grep \"$ip\" \'/etc/hosts\' | awk \'{print \$NF}\'";
    my $host=`$host_cmd`; chomp $host;
    my $siteCLLI = $1 if($host =~ /(\w+)-.+$/);
    $siteCLLI =~ s/NSA$//;

    # Restrict length to 50 characters.
    if ( length($version) > 50 ) {
	$version= substr($version,0,50);

    }
    print "$TIMESTAMP, $siteCLLI, $host, SW_version, $version\n";
  }
}

# Print software patches #
foreach my $app (keys %$appVSip) {
  foreach my $ip (@{$appVSip->{$app}}) {

    # Get Node Version and Patch level
    my $patch_cmd = "$ENV{SSH} $ip \" $ENV{PMX} subshell patch show all patches \" 2>/dev/null | egrep -vi \'Already|No\' | sort | grep [^A-Za-z]";
    my $patch_cmd_out = '';
    $patch_cmd_out = `$patch_cmd 2>/dev/null`;
    my $patch = '';
    my $patches;
    map {
      $_ =~ s/^\s+//g;
      $patch = $_;
      chomp $patch;
      $patches.="$patch " if($patch);
    } split(/\n/, $patch_cmd_out);
    $patches="" if ($patches !~ /\w+/);

    my $host_cmd="grep \"$ip\" \'/etc/hosts\' | awk \'{print \$NF}\'";
    my $host=`$host_cmd`; chomp $host;
    my $siteCLLI = $1 if($host =~ /(\w+)-.+$/);
    $siteCLLI =~ s/NSA$//;

    # Restrict length to 50 characters.
    if ( length($patches) > 50 ) {
        $patches = substr($patches,0,50);

    }

    print "$TIMESTAMP, $siteCLLI, $host, SW_patches, $patches\n";
  }
}

sub write_log {
  my $msg = shift;

  open(LOGF, ">>$ENV{LOGFILE}") or print "Unable to write to $ENV{LOGFILE}\n";
  print LOGF "$TIMESTAMP [$script_name] $msg\n";
  close(LOGF);
}
