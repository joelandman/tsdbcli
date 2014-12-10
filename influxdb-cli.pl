#!/usr/bin/perl

# Copyright (c) 2002-2014 Scalable Informatics
# This is not free software, this is not freely distributable
# software.  You may not copy this software.  You may not 
# alter and redistribute this software.

# new.pl: new.pl does this stuff

use strict;
use v5.12;
 

use POSIX qw[strftime];
use IO::File;
use URI::Escape;
use Term::ReadLine;
use Text::ASCIITable;
use JSON::PP;
use Data::Dumper;
use Getopt::Lucid qw( :all );
use Mojo::UserAgent;
use LWP::UserAgent;
use lib "./lib";
use Scalable::TSDB;
 

# from SI::Utils
use constant true   => (1==1);
use constant false  => (1==0);

# history file
use constant history_file => ".ifdbcli";

# spark if available
my $spark = '/opt/scalable/bin/spark';

#
my $vers    = "0.5";

# variables
my ($opt,$rc,$ix,$host,$port,$user,$pass,$db,$file,$fh,$header,$data);
my ($debug,$verbose,$help,$hostname,$line, @_params, $_p, $_tb,$ifdbhf);
my (%parameters,$result,$rh,@res,$term,$version,$first,$series);
my (@columns,$nohttp,$format,$outfile,$ofh,$kvp,$k,$v,$str,@hist);
my ($vals,$vstr,$cmd,$url,$hash,$json,$param,$query);

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
eval { $opt = Getopt::Lucid->getopt( \@command_line_specs ) };


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

# read history file it it exists
if (-e history_file) {
    open($ifdbhf, "<".history_file) or next;
    while (my $hl = <$ifdbhf>)
     {
       chomp $hl ;
       eval { $term->AddHistory($line)  if (!defined($file)); }; 
     }        
}    


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

# loop until done
$parameters{'time_precision'} = 's';
$parameters{'chunked'}        = 0;

while ($line = ( defined($file) ? $fh->getline() : $term->readline($db.'> ')) ) {
    
    chomp($line);

    if (($line =~ /^\\exit/) || ($line =~ /^\\quit/) ) {
      last;
    }
    
    ### setup database url
    $url    = &set_url  ({host=>$host, port => $port , db => $db });
    
    if ($line =~ /^\\set\s+(.*)/) {
        $kvp    = $1;
        ($k,$v) = split(/\=/,$kvp);
        
        if (lc($k) =~ /sep/) {
            $sep = $v;
        }
        if (lc($k) =~ /output/) {
            $ofh = IO::File->new();
            if (!$ofh->open("> $v")) {
                warn "ERROR: unable to open file \'$v\' for output\n";
                $ofh    = *STDOUT;
            }
            $ofh->autoflush(true);
        }
        if (lc($k) =~ /format/) {
            if (lc($v) =~ /ascii/) {
                $format = "ascii";
               }
            elsif (lc($v) =~ /csv/) {
                $format = "csv";
               }
            elsif (lc($v) =~ /gnuplot/) {
                $format = "gnuplot";
               }
            else { $format = "ascii"; }            
        }
        eval {$term->AddHistory($line)  if (!defined($file)); } ;
        next;
    }
    
    if ($line =~ /^\\get\s+(.*)/) {
        $k  = $1;
        if (lc($k) =~ /output/) {
            printf STDOUT "# outfile = %s\n",$outfile;
        }
        if (lc($k) =~ /format/) {
            printf STDOUT "# format = %s\n",$format;
        }
        eval { $term->AddHistory($line)  if (!defined($file)); } ;
        next;
    }
    
    
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
      
      eval { $term->AddHistory($line)  if (!defined($file)); };
      next;
    }
    
    if ($line =~ /^\\set\s+(.*?)\s+(.*?)\=(.*?)/) {
      $parameters{$1} = $2;
      eval { $term->AddHistory($line) if (!defined($file)); };
      next;
    }
    
    if ($line =~ /\\list\s+(.*?)$/) {
        my $_arg = $1;
        my (@series_list,$h,%cols,$first,@a,$_series,@b);
        if ($_arg =~ /series/i) {
            $result = &send_non_chunked_query(
                {
                  user => $user, 
                  pass => $pass, 
                  query => "list series"}
            );
            
            $first  = @$result[0];
            @a      = @{$first->{columns}};
            foreach my $i (0 .. $#a) {$cols{$a[$i]} = $i; }
            @series_list = @{$first->{points}};
            if ($format =~ /ascii/) {
                $_tb = Text::ASCIITable->new();
                $_tb->setCols('series name');
                
                foreach $_series ( @series_list ) {
                    $_tb->addRow(@{$_series}[$cols{'name'}]);       
                }    
            }
            elsif ($format =~ /csv/) {
                $str    = "#series\n";
                foreach my $_series (sort @series_list ) {
                    $str.= sprintf("%s\n",@{$_series}[$cols{'name'}]);       
                }  
            }
            if ($format =~ /ascii/) {
                printf $ofh "%s\n",$_tb;                
               }
            elsif ($format =~ /csv/) {
                printf $ofh "%s\n",$str;
            }            
            eval { $term->AddHistory($line) if (!defined($file)); };    
        }
        
        if ($_arg =~ /continuous/i) {
            eval {$result = $ix->list_continuous_queries() or warn "WARNING: " . $ix->errstr };            
            if ($result) {
                $_tb = Text::ASCIITable->new();
                $_tb->setCols('id', 'query');
                my %h = %{@{$result}[0]};
                my @cqueries = @{$h{points}};
                 
                foreach my $query (@cqueries) {
                    my @cq = @{$query};
                    $_tb->addRow([$cq[1],$cq[2]]);   
                }
            }
            printf $ofh "%s\n",$_tb;
            eval { $term->AddHistory($line) if (!defined($file)); };
        }
        
      next;
    }
    
    if ($line =~ /\\create\s+(.*?)\s+(.*?)\s+name\s+as\s+(.*?)$/) {
        my $arg     = $1;
        my $cquery  = $2;
        my $cq_name = $3;
        if ($arg =~ /continuous/) {
            eval {
                  $result = $ix->create_continuous_query(q => $cquery , name => $cq_name) 
                  or warn "WARNING: " . $ix->errstr
                 };
        }
        eval { $term->AddHistory($line) if (!defined($file)); };
        next;
    }
    
    if ($line =~ /\\plot\s+(.*)/) {
        my $query = $1;
        eval { $result = $ix->query(q => $line, %parameters) or warn "WARNING: " . $ix->errstr };
        @columns = @{$series->{columns}};
        my @sindex= sort { $columns[$a] cmp $columns[$b]} @columns;
         
        
        
        foreach my $point (reverse sort @{$result}) {
            foreach my $col (0 .. $#columns) {
                push @{$vals->{$columns[$col]}},@{$point}[$col];
            }
            foreach my $col (0 .. $#columns) {
                $vstr   = join(" ",@{$vals->{$columns[$col]}});
                $cmd    = sprintf "%s %s",$spark,$vstr;
                open(my $ifh, "$cmd |");
                my @in = split(/\n/,<$ifh>);
                close($ifh);
                printf $ofh "#%s\n# %s\n",$columns[$col],join("",@in);
            }
            
        }
        next;
    }
    
    
    #eval { $result = $ix->query(q => $line, %parameters) or warn "WARNING: " . $ix->errstr };
    $result = &send_non_chunked_query(
                {
                  user => $user, 
                  pass => $pass, 
                  query => $line}
            );
    if ($result) {
        @res    = @{$result};
        $series = $res[0];
        
        # if $series is not defined, then the query has returned nothing
        # add it to history and go to next ...
        if (!defined($series)) {
            eval { $term->AddHistory($line) if (!defined($file)); };
            next;
        }
        
        if ($series->{error}) {
            printf $ofh "ERROR:\n\tmessage\t= \'%s\'\n\tdetails\t= \'%s\'\n\n",$series->{message},$series->{error};
          }
        else
          {
            @columns = @{$series->{columns}};
           
            
            if ($format =~ /ascii/) {
                $_tb = Text::ASCIITable->new( {headingText => $series->{name}} );
                $_tb->setCols( @{$series->{columns}});
               }
            elsif ($format =~/csv/) {
                $str = "#".join($sep,@{$series->{columns}})."\n";
            }
            
            
            foreach my $point (reverse sort @{$result}) {
                if ($format =~ /ascii/) {
                    $_tb->addRow([$series->{points}]);   
                   }
                elsif ($format =~ /csv/) {
                    my $points = $series->{points};
                    my @tpoints = reverse @{$points};
                    foreach my $spoint (@tpoints){
                            $str.= sprintf("%s\n",join($sep,@$spoint));
                    }
                }
                
                    
                }
            
            if ($format =~ /ascii/) {
                printf $ofh "%s\n",$_tb;
               }
            elsif ($format =~ /csv/) {
                printf $ofh "%s\n",$str;
            }
          }
        
        eval { $term->AddHistory($line) if (!defined($file)); };
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


sub send_non_chunked_query {
  my $hash  = shift;  
  my $h = {u => $hash->{user}, p => $hash->{pass} , q => $hash->{query}};
  my ($ua,$tx,$series,$result,$rv);
  
  $url .= (sprintf 'u=%s',$hash->{user});
  $url .= (sprintf '&p=%s',$hash->{pass});
  $url .= (sprintf '&q=%s',uri_escape($hash->{query}));
  #foreach my $p (keys %parameters) { $url .= (sprintf '&%s=%s',$p,$parameters{$p}) }
  
  #$ua = LWP::UserAgent->new;
  $ua = Mojo::UserAgent->new;
  #$tx = $ua->get($url);
  $tx = $ua->build_tx(GET => $url);
  my $body = '';
  $tx->req->headers->content_length(length $body);
  
  # Start writing directly with a drain callback
  my $drain;
  $drain = sub {
    my $content = shift;
    my $chunk   = substr $body, 0, 1, '';
    $drain      = undef unless length $body;
    $content->write($chunk, $drain);
  };
  $tx->req->content->$drain;

  # Process transaction
  $tx = $ua->start($tx);
  $rv = $tx->{content} if ($tx->{content});
  if ($rv) {
    if ($tx->{_rc} != 400) {
      $result    = decode_json $rv if ($rv);
     }
    else
     {
      push @{$result},{ error => $tx->{content}, message => $tx->{_msg} };
     }  
   }
  else
   {
      push @{$result},{ error => "Warning:  Empty", message => $tx->{_msg} };
   }
  
   
  return $result;              
}

sub output_results {
  my ($fh,$data) = @_;
  printf $fh "%s\n",$data;
}

