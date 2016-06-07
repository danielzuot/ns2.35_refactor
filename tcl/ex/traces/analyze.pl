#! /usr/bin/perl

#
# simple perl script to graph of window size over time for specified flow id
# 

$flow_id = -1;

#######################################
# Process command line args.
while ($_ = $ARGV[0], /^-/)
{
  shift;
  if (/^-h/)      { $Usage; }
  elsif (/^-v/)   { $verbose_mode = 1;}
  elsif (/^-f/)  { if ( $ARGV[0] ne '' ) {
              $flow_id = $ARGV[0];  
                      shift; }}
  else            { warn "$_ bad option\n"; &Usage; }
}

# Now, make sure one and only one filename was specified
if (($ARGV[0] eq '') || ($ARGV[1] ne '')) {
  warn "Need to specify one and only one filename\n";
  &Usage;
}
$file = $ARGV[0];

# need to have specified max bwidth
if ($flow_id < 0) {
  warn "Need to specify flow id to analyze";
  &Usage;
}

if ($verbose_mode) {
  print "file: $file\n";
}

#######################################
# count the number of lines
$cmd = "cat $file | grep ^- | wc -l";
$lines = `$cmd`; 
chop($lines);
if ($lines == 0) {
  printf("No input lines in command:\n");
  printf("\t $cmd\n");
  printf("Exiting ...\n");
  exit(1);
}



#######################################

# print usage and quit
sub Usage {
  printf STDERR "usage: analyze.pl [flags] <filename>, where:\n";
  printf STDERR "\t-f            flow id\n";
  printf STDERR "\t-v            verbose output\n";
  printf STDERR "\t-h            this help message\n";
  exit(1);
}