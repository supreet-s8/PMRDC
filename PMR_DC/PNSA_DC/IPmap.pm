package AppIPmap;

sub new {
  my $class = shift;
  my %params = @_;

  my $self = {};

  bless $self, $class;
  return $self;
}

sub getAppICNMaping {

  my $self = shift;

  # Find the client and compute ICN-IP
  my $show_hadoop_cmd = '/opt/tps/bin/pmx.py "show hadoop"';

  my $show_hadoop_cmd_out = `$show_hadoop_cmd`;

  my %appVSip;
  map {
     my $row = $_;
     $row =~ s/\s+/ /g;

     if($row =~ /(client|slave)\s:\s(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {
       push @{$appVSip{$1}}, $2;
     }
  } split(/\n/, $show_hadoop_cmd_out);

  return \%appVSip;
}

1;
