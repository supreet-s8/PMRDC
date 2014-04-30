#!/usr/bin/perl

use strict;

BEGIN {
  push @INC, ("$ENV{BASEPATH}/DC");
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

# Site level flags
my $s_nn = 0;
my $s_Snn = 0;
my $s_dn = 0;
my $s_jt = 0;
my $s_oz = 0;

my $S_CLLI;

my $DFSUSED = 0;
my $dfs_flag = 0;

foreach my $app (keys %$appVSip) {

  # Node Status for Collector + NN Node
  if($app eq 'client') {

    foreach my $ip (@{$appVSip->{$app}}) {
      my $HADOOPSTATUS = 0;

      my $ps_cmd = "$ENV{SSH} $ip \"ps -ef\""; 

      my $ps_cmd_out = `$ps_cmd`;

      unless($ps_cmd_out =~ /^$/) {

        if(nodeIsMaster($ip)) {

          # Check Namenode process
          $HADOOPSTATUS+=$ENV{NAMENODE} unless (checkNNprocess($ps_cmd_out));
      
          # Check SecondaryNamenode process
          $HADOOPSTATUS+=$ENV{SECONDARYNN} unless (checkSecNNprocess($ps_cmd_out));

          # Check Datanode process
          $HADOOPSTATUS+=$ENV{DATANODE} unless (checkDNprocess($ps_cmd_out));
  
          # Check Jobtracker process
          $HADOOPSTATUS+=$ENV{JOBTRACKER} unless (checkJTprocess($ps_cmd_out));
  
          # Check oozie server process
          $HADOOPSTATUS+=$ENV{CATALINA} unless (checkOOZprocess($ps_cmd_out));
        }

        else { # NodeisStandby 

          # Check Datanode process
          #$HADOOPSTATUS+=$ENV{DATANODE} unless (checkDNprocess($ps_cmd_out));

        }

      }
      else { $HADOOPSTATUS = 1; }

      ################
      # Check Collector process
      ################
      my $COLLECTOR_STATUS = 0;
      my $coll_ps_cmd = "$ENV{SSH} $ip \'$ENV{CLIRAW} -t \"en\" \"show pm process collector\"\'";
      my $coll_ps_cmd_out = `$coll_ps_cmd`;
      if($coll_ps_cmd_out =~ /^$/) {
        $COLLECTOR_STATUS = 1;
      }
      else {
        $COLLECTOR_STATUS+=$ENV{COLLECTOR} unless (checkCOLLprocess($coll_ps_cmd_out));
      }

      # get the site CLLI & hostname and printf to stdout
      my ($siteCLLI, $hostname) = getHostdetails($ip, $HADOOPSTATUS);

      # Update Site CLLI
      $S_CLLI = $siteCLLI;

      #printf "%s, %s, %s, Hadoop_status, %s\n", $TIMESTAMP, $siteCLLI, $hostname, $HADOOPSTATUS;
      printf "%s, %s, %s, Node_status, %s\n", $TIMESTAMP, $siteCLLI, $hostname, $COLLECTOR_STATUS + $HADOOPSTATUS;

      
      ################
      # HDFS Utilization, compute once from either NN or SecondaryNN
      ################
      unless($DFSUSED || $dfs_flag) {
        my $dfs_used_cmd = "$ENV{SSH} $ip \"$ENV{HADOOP} dfsadmin -report\"";
        my $dfs_used_cmd_out = `$dfs_used_cmd`;
        my $DFSUSED = getDFSUsed($dfs_used_cmd_out);

        printf "%s, %s, %s, HDFS_utilization, %s\n", $TIMESTAMP, $siteCLLI, 'HDFS', $DFSUSED;
        $dfs_flag++;
      }


      ################
      # DF Utilization
      ################
      my $DFUtilization = computeDFStats($ip);    

      foreach my $vol (sort keys %$DFUtilization) {
        printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, $siteCLLI, $hostname, 'Disk_partition_size'.$vol, $DFUtilization->{$vol}->{'Disk_partition_size'};
        printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, $siteCLLI, $hostname, 'Disk_partition_utilization'.$vol, $DFUtilization->{$vol}->{'Disk_partition_utilization'};
      }


      ################
      # Collector KPIs
      ################
      my $collectorKPIs = collectorStats($ip);

      my %adaptor_statsMap = ('ipfix' => 'HTTP', 'pilotPacket' => 'PilotPacket');

      foreach my $adaptor_stats (sort keys %$collectorKPIs) {
        foreach my $statType (sort keys %{$collectorKPIs->{$adaptor_stats}}) {
          printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, $siteCLLI, $hostname, $adaptor_statsMap{$adaptor_stats}.$statType, $collectorKPIs->{$adaptor_stats}->{$statType};
        }
      }

    }
  }

  # Node Status for compute hosts
  elsif($app eq 'slave') {

    foreach my $ip (@{$appVSip->{$app}}) {
      my $HADOOPSTATUS = 0;

      my $ps_cmd = "$ENV{SSH} $ip \"ps -ef\"";

      my $ps_cmd_out = `$ps_cmd`;

      unless($ps_cmd_out =~ /^$/) {

        # Check Datanode process
        $HADOOPSTATUS+=$ENV{DATANODE} unless (checkDNprocess($ps_cmd_out));

        # Check Tasktracker process
        $HADOOPSTATUS+=$ENV{TASKTRACKER} unless (checkTTprocess($ps_cmd_out));
      }
      else { $HADOOPSTATUS = 1; }

      # get the site CLLLI & hostname and printf to stdout
      my ($siteCLLI, $hostname) = getHostdetails($ip, $HADOOPSTATUS);

      printf "%s, %s, %s, Node_status, %s\n", $TIMESTAMP, $siteCLLI, $hostname, $HADOOPSTATUS;


      ################
      # DF Utilization
      ################
      my $DFUtilization = computeDFStats($ip);

      foreach my $vol (sort keys %$DFUtilization) {
        printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, $siteCLLI, $hostname, 'Disk_partition_size'.$vol, $DFUtilization->{$vol}->{'Disk_partition_size'};
        printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, $siteCLLI, $hostname, 'Disk_partition_utilization'.$vol, $DFUtilization->{$vol}->{'Disk_partition_utilization'};
      }

    }
  }
}


# Site level Hadoop status
my $S_HADOOPSTATUS = 0;

$S_HADOOPSTATUS += $ENV{S_NAMENODE} unless($s_nn); # NameNode is down in cluster
$S_HADOOPSTATUS += $ENV{S_SECONDARYNN} unless($s_Snn); # SecondaryNameNode is down in cluster
$S_HADOOPSTATUS += $ENV{S_JOBTRACKER} unless($s_jt); # JobTracker is down in cluster
$S_HADOOPSTATUS += $ENV{S_CATALINA} unless($s_oz); #  Oozie is down in cluster

$S_HADOOPSTATUS += ($ENV{S_DATANODE} * $s_dn); # Multiply datanode bitmask with n+ datanodes that are down

printf "%s, %s, %s, Hadoop_status, %s\n", $TIMESTAMP, $S_CLLI, 'HADOOP', $S_HADOOPSTATUS; 



#----------------------------
#	functions
#----------------------------

sub getDFSUsed {
  my $dfsusedRaw = shift;

  my $dfsUsed = 0;
  foreach my $row (split(/\n/, $dfsusedRaw)) {
    if($row =~ /DFS Used\%\:\s(\d+\.?\d*)\%/) {
      $dfsUsed = $1 unless($dfsUsed);
      last;
    }
  }

  return $dfsUsed;
}

sub getHostdetails {
  my ($ip, $Hstatus) = @_;

  # Host is not reachable
  if($Hstatus == 1) {

    my $lastoctet = $1 if($ip =~ /\d{1,3}\.\d{1,3}.\d{1,3}.(\d{1,3})/);

    my $siteCLLI = $1 if($ENV{HOSTNAME} =~ /(\w+)-.+$/);
    $siteCLLI =~ s/NSA$//;

    my $hostname = $ENV{HOSTNAME};
    $hostname =~ s/(.*)\-\d+/$1-$lastoctet/g;

    return ($siteCLLI, $hostname);
  }

  # Host is reachable
  else {
    my $hostaname_cmd = "$ENV{SSH} $ip \"hostname\"";
    my $hostname_cmd_out = `$hostaname_cmd`; chomp($hostname_cmd_out);

    my $siteCLLI = $1 if($hostname_cmd_out =~ /(\w+)-.+$/);
    $siteCLLI =~ s/NSA$//;

    return($siteCLLI, $hostname_cmd_out);
  }

}

sub checkCOLLprocess {
  my $psout = shift;

  return 1 if($psout =~ m/Current status:  running/g);
  return 0;
}

sub checkNNprocess {
  my $psout = shift;

  if($psout =~ m/org.apache.hadoop.hdfs.server.namenode.NameNode/g) {
     $s_nn = 1; # Functional NameNode in cluster
     return 1 ;
  }

  return 0;
}

sub checkSecNNprocess {
  my $psout = shift;

  if($psout =~ m/org.apache.hadoop.hdfs.server.namenode.SecondaryNameNode/g) {
     $s_Snn = 1; # Functional NameNode in cluster
     return 1 ;
  }

  return 0;
}

sub checkDNprocess {
  my $psout = shift;

  return 1 if($psout =~ m/org.apache.hadoop.hdfs.server.datanode.DataNode/g);

  $s_dn++; # DataNode is down in one of the nodes, increment the flag status

  return 0;
}

sub checkJTprocess {
  my $psout = shift;

  if($psout =~ m/org.apache.hadoop.mapred.JobTracker/g) {
    $s_jt = 1; # Functional Job Tracker in cluster
    return 1;
  }
  return 0;
}

sub checkTTprocess {
  my $psout = shift;

  return 1 if($psout =~ m/org.apache.hadoop.mapred.TaskTracker/g);
  return 0;
}

sub checkOOZprocess {
  my $psout = shift;

  if($psout =~ m/org.apache.catalina.startup.Bootstrap start/g) {
    $s_oz = 1; # Functional Oozie in cluster
    return 1;
  }
  return 0;
}


sub nodeIsMaster {
  my $ip = shift;

  my $show_clus_cmd = "$ENV{SSH} $ip \'$ENV{CLIRAW} -t \"en\" \"show cluster local\" | grep \"Node Role\"\'";
  my $show_clus_cmd_out = `$show_clus_cmd`;

  return 1 if($show_clus_cmd_out =~ /Node Role:\smaster/);

  return 0;
}


sub write_log {
  my $msg = shift;

  open(LOGF, ">>$ENV{LOGFILE}") or print "Unable to write to $ENV{LOGFILE}\n";
  print LOGF "$TIMESTAMP [$script_name] $msg\n";
  close(LOGF);
}


sub collectorStats() {
  my $ip = shift;

  my $collStats = {};

  my %collStatsMapping = (
          'total-flow'   => '_record_data_volume',
          'dropped-flow' => '_dropped_record_data_volume',
          'num-files-processed' => '_files_processed',
          'num-files-with-errors' => '_files_with_errors',
          'num-files-dropped' => '_files_dropped'
  );


  foreach my $adaptor_stats (qw(ipfix pilotPacket)) {
    foreach my $stats_type ( qw(total-flow dropped-flow num-files-processed num-files-with-errors num-files-dropped) ) {

      my $coll_stats_cmd = "$ENV{SSH} $ip \'$ENV{CLIRAW} -t \"en\" \"collector stats instance-id 1 adaptor-stats $adaptor_stats $stats_type interval-type 5-min interval-count 3\"\'";

      my $coll_stats_cmd_out = `$coll_stats_cmd`;

      $collStats->{$adaptor_stats}->{$collStatsMapping{$stats_type}} = getTotalCollStats($coll_stats_cmd_out);
    }
  }

  return $collStats;
}


sub getTotalCollStats {
  my $coll_stats_cmd_out = shift;

  my $sum = 0;
  map {
   my $row = $_;
   if($row =~ /\s+\d+$/) {
     $sum += [split(/\s+/, $row)]->[-1];
   }
  } split(/\n/, $coll_stats_cmd_out);

  return $sum;
}

sub computeDFStats {
  my $ip = shift;

  my $comp_dfstats_cmd = "$ENV{SSH} $ip \'df'"; 

  my $comp_dfstats_cmd_out = `$comp_dfstats_cmd`;

  my %data;
  map {
    my $row = $_; chomp($row);
    my @row = split(/\s+/, $row);

    $row[-1] =~ s/\//_/g; $row[-1] = '_root' if($row[-1] =~ /^_$/g);
    $row[4] =~ s/\%//g;
    %{$data{$row[-1]}} = ('Disk_partition_size' => $row[1], 'Disk_partition_utilization' => $row[4]) 
                            if($row[1] =~ /^\d+$/);

  } split(/\n/, $comp_dfstats_cmd_out);

  return \%data;
}
