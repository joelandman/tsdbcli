#!/usr/bin/perl

# Copyright (c) 2002-2015 Scalable Informatics
# License:  GPL 2.0 (see the enclosed LICENSE file)

use strict;
use v5.12;
 

use POSIX qw[strftime];
use IO::File;
use URI::Escape;
use Term::ReadLine; 
use Text::ASCIITable;
use JSON::PP;
use Data::Dumper;
use Getopt::Lucid qw( :all ) ;
use FindBin;
use lib "$FindBin::Bin/lib";

use Scalable::TSDB;
use Time::HiRes qw( gettimeofday tv_interval );

# from SI::Utils
use constant true   => (1==1);
use constant false  => (1==0);

# history file
use constant history_file => ".ifdbcli";

# spark if available
my $spark = (-e '/opt/scalable/bin/spark' ? '/opt/scalable/bin/spark' : undef);

#
my $vers    = "0.6";

# variables
my ($opt,$rc,$ix,$host,$port,$user,$pass,$db,$file,$fh,$header,$data);
my ($debug,$verbose,$help,$hostname,$line, @_params, $_p, $_tb,$ifdbhf);
my (%parameters,$result,$rh,@res,$term,$version,$first,$series);
my (@columns,$nohttp,$format,$outfile,$ofh,$kvp,$k,$v,$str,@hist);
my ($vals,$vstr,$cmd,$url,$hash,$json,$param,$query,@usecols);
my ($skip);

my ($tsdb,$hashout,$t0,$tf,$dt);

my $count   = 1;
my $sep     = " ";
 
my @command_line_specs = (
                     Param("host"),
                     Param("port"),
                     Param("db"),
                     Param("user"),
                     Param("pass"),                     
                     Param("file"),
                     Param("spark"),
                     Switch("help"),
                     Switch("version"),
                     Switch("debug"),
                     Switch("verbose"),
                     Switch("nohttp"),
                     );

# parse all command line options
$opt = Getopt::Lucid->getopt( \@command_line_specs );


# test/set debug, verbose, etc
$debug      = $opt->get_debug   ? true : false;
$verbose    = $opt->get_verbose ? true : false;
$version    = $opt->get_version ? true : false;
$help       = $opt->get_help    ? true : false;
$nohttp     = $opt->get_nohttp  ? false : true;
$user       = $opt->get_user;
$pass       = $opt->get_pass;
$db         = $opt->get_db;
$port       = $opt->get_port || 8086;
$host       = $opt->get_host || '127.0.0.1';
$file       = $opt->get_file || undef;
$spark      = ($opt->get_spark ? $opt->get_spark : $spark);
$first      = true;
$hostname   = `hostname`;
chomp($hostname);

&help()             if ($help);
&version($vers)     if ($version);



# connect file handle to file.  Use STDIN if no --file=... has been specified
$fh     = IO::File->new();
$format = "ascii";
$outfile= "-";
$ofh    = *STDOUT;

if ($file) {
    die "FATAL ERROR: Unable to open file=\'$file\' for reading\n" if (!($fh->open('<'.$file)));
  }
 else
  {
    $term = Term::ReadLine->new('influxdb-cli');
  }

# read history file it it exists, and add it back into history
if ((-e history_file) && (!defined($file)) ) {
    open($ifdbhf, "<".history_file) or next;
    while (my $hl = <$ifdbhf>)
     {
       chomp $hl ;
       #eval {
        $term->addhistory($hl);
        #}; 
     }        
}    


# loop until done
$parameters{'time_precision'} = 's';
$parameters{'chunked'}        = 1;

# build TSDB connection
&reopen_tsdb_connection();


while ($line = ( defined($file) ? $fh->getline() : $term->readline($db.'> ')) ) {
    
    chomp($line);
    $skip   = false;
    last if (($line =~ /^\\exit/) || ($line =~ /^\\quit/) );
    
    
    # check for parameter setting
    if ($line =~ /^\\set\s+(.*)/) {
        $kvp    = $1;
        ($k,$v) = split(/\=/,$kvp);

	if (lc($k) =~ /^debug$/) {
            $debug = ( $v =~ /^true$/ ? true : false) ;
	    $tsdb->debug($debug);
        }        
        if (lc($k) =~ /^sep$/) {
            $sep = $v;
        }
        if (lc($k) =~ /^no_seq$/) {
            $tsdb->suppress_seq(1);
            printf STDERR "D[%i] influxdb-cli.pl; suppress sequence number\n",$$ if ($debug);
        }
        if (lc($k) =~ /^use_seq$/) {
            $tsdb->suppress_seq(0);
            printf STDERR "D[%i] influxdb-cli.pl; do not suppress sequence number\n",$$ if ($debug);
        }
        if (lc($k) =~ /^no_ind$/) {
            $tsdb->suppress_id(1);
            printf STDERR "D[%i] influxdb-cli.pl; suppress index number\n",$$ if ($debug);
        }
        if (lc($k) =~ /^use_ind$/) {
            $tsdb->suppress_id(0);
            printf STDERR "D[%i] influxdb-cli.pl; do not suppress index number\n",$$ if ($debug);
        }
        if (lc($k) =~ /^dump$/) {
            printf "TSDB object: %s\n",Dumper($tsdb);
        }
        if (lc($k) =~ /^output$/) {
            $ofh = IO::File->new();
            if (!$ofh->open("> $v")) {
                warn "ERROR: unable to open file \'$v\' for output\n";
                $ofh    = *STDOUT;
            }
            $ofh->autoflush(true);
        }
        if (lc($k) =~ /^format$/) {
            if (lc($v) =~ /^ascii$/) {
                $format = "ascii";
               }
            elsif (lc($v) =~ /^csv$/) {
                $format = "csv";
               }
            elsif (lc($v) =~ /^gnuplot$/) {
                $format = "gnuplot";
               }
            else { $format = "ascii"; }            
        }
        if (lc($k) =~ /^db$/) {
            $db           = $v;
            &reopen_tsdb_connection();
        }
        if (lc($k) =~ /^host$/) {
            $host         = $v;
            &reopen_tsdb_connection();
        }
        if (lc($k) =~ /^user$/) {
            $user         = $v;
            $skip         = true;
            &reopen_tsdb_connection();
        }
        if (lc($k) =~ /^pass$/) {
            $pass         = $v;
            $skip         = true;
            &reopen_tsdb_connection();
        }
        if (lc($k) =~ /^port$/) {
            $port         = $v;
            &reopen_tsdb_connection();
        }
        
        if (!$skip) {
            eval {$term->addhistory($line)  if (!defined($file)); } ;
        }
        next;
    }
    
    # parameter checking
    if ($line =~ /^\\get\s+(.*)/) {
        $k  = $1;
        if (lc($k) =~ /^output$/) {
            printf STDOUT "# outfile = %s\n",$outfile;
        }
        if (lc($k) =~ /^format$/) {
            printf STDOUT "# format = %s\n",$format;
        }
        eval { $term->addhistory($line)  if (!defined($file)); } ;
        next;
    }
    
    # query parameter showing
    if ($line =~ /^\\show\s+query\s+parameters{0,1}\s{0,}(.*?\,{0,1}){0,}/) {
      $_tb = Text::ASCIITable->new( {headingText => "Parameter"} );
      $_tb->setCols('Parameter','Value');
      @_params = (defined($1) ? split(/\,/,$2) : undef);
      if ($format =~ /csv/) {
            $str    = '#';
            $str    .= join($sep,(sort keys %parameters))."\n";
            print $ofh $str;
            $str    = "";
        }
      foreach  $_p (sort keys %parameters) { 
        next if ( @_params && grep(/$_p/,@_params) );
        $_tb->addRow($_p,$parameters{$_p});
        if ($format =~ /csv/) {
            $str    .= sprintf("%s,%s\n",$_p,$parameters{$_p} );
            
        }        
      }
      &output_results($format,$ofh,($format =~ /ascii/ ? $_tb : $str));
      
      eval { $term->addhistory($line)  if (!defined($file)); };
      next;
    }
    
    # environment parameter setting
    if ($line =~ /^\\set\s+(.*?)\s+(.*?)\=(.*?)/) {
      $parameters{$2} = $3;
      eval { $term->addhistory($line) if (!defined($file)); };
      next;
    }
    
    # do a chunked GET query, return a hash-of-hashes
    $t0     = [gettimeofday];
    $result = $tsdb->_send_chunked_get_query_LWP_return_df({query => $line, parameters => \%parameters});
    $dt     = tv_interval ( $t0, [gettimeofday]);       
    printf STDERR "D[%i] influxdb-cli.pl; DB query \'%s\' took %-.6fs\n",$$,$line,$dt if ($debug);

    if ($result) {
        $hashout  =  $result->{result};
        # if $series is not defined, then the query has returned nothing
        # add it to history and go to next ...    
        eval { $term->addhistory($line) if (!defined($file)); };
                   
        if ($result->{rc} !~ /200/) {
            printf $ofh "ERROR:\n\tmessage\t= \'%s\'\n\trc\t= \'%s\'\n",$result->{error},$result->{rc};
            next;
          }
        else
          {
            next if (!$hashout); # skip processing if the return is empty but no error message provided            
            @columns = @{$hashout->{columns}} ;
            if ($format =~ /ascii/) {
            	my $heading = sprintf "results: query = \'%s\'",$line;
                $_tb = Text::ASCIITable->new( {headingText => $heading} );
                if ($line =~ /list\s+series/i) {
                    $_tb->setCols( 'series');
                  }
                else
                  {
                    $_tb->setCols( @columns );
                  }
               }
            elsif ($format =~/csv/) {
              if ($line =~ /^list\s+series/i) {
                     $str = "#series\n";
                  }
                else
                  {
                      $str = "#".join($sep,"time",@columns)."\n";
                  }
            }
            
            my ($rows,@r,$lst,$id1,@cnames,$idq,@ids,@usecn,@loc,$c,$point,@_row,$_c);
            my $i = 0;            
            undef @loc;
            
            $t0     = [gettimeofday];          
            $_c = 0;            
            if ($line =~ /^list/i) {
                undef @loc;
                foreach $c (@columns) {
                    push @loc,$_c if ($c !~ /time/);
                    $_c++;
                }
            }
            else
            {
                foreach $c (@columns) {
                    push @loc,$_c;
                    $_c++;
                }
            }
              
            if ($hashout->{points}) {
                foreach  $point (@{$hashout->{points}}) {
                        @_row = @{$point}[@loc];
                        if ($format =~ /ascii/) {                           
                            $_tb->addRow(@{$point}[@loc]);                              
                          }
                        elsif ($format =~ /csv/) {
                            $str.= sprintf("%s\n",join($sep,@{$point}[@loc]));
                        }                        
                }
            }
                 
        }
            
        $dt     = tv_interval ( $t0, [gettimeofday]);       
        printf STDERR "D[%i] influxdb-cli.pl; output formatting took %-.6fs\n",$$,$dt if ($debug);
        
        
        $t0     = [gettimeofday];
        if ($format =~ /ascii/) {
            printf $ofh "%s\n",$_tb;
           }
        elsif ($format =~ /csv/) {
            printf $ofh "%s\n",$str;
        }
        $dt     = tv_interval ( $t0, [gettimeofday]);       
        printf STDERR "D[%i] influxdb-cli.pl; outputting took %-.6fs\n",$$,$dt if ($debug);
            
          
        
        eval { $term->addhistory($line) if (!defined($file)); };
        open($ifdbhf, ">>".history_file) or next;
        printf $ifdbhf "%s\n",$line;
        close($ifdbhf); 
        next;
    }
}    



exit 0;


sub version {
    my $V = shift;
    print "new.pl version $V\n";
    exit 0;
}

sub set_url {
  my $h     = shift;
  my $url   = sprintf 'http://%s:%i/db/%s/series?',
              $h->{host},
              (defined($h->{port}) ? $h->{port} : 8086),
              $h->{db};
  return $url;              
}


sub output_results {
  my ($fh,$data) = @_;
  printf $fh "%s\n",$data;
}

sub reopen_tsdb_connection {
    undef $tsdb;
    $tsdb = Scalable::TSDB->new(
        {
          host    => $host, 
          port    => $port, 
          db      => $db, 
          user    => $user, 
          pass    => $pass, 
          ssl     => false,
          debug   => $debug,
          suppress_id => false,
          suppress_seq=> false
        }
    );
}
