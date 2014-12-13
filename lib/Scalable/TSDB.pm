package Scalable::TSDB;

use Moose;
use URI::Escape;
use JSON::PP;
use Mojo::UserAgent;

has 'host' => ( is => 'rw', isa => 'Str');
has 'port' => ( is => 'rw', isa => 'Int');
has 'user' => ( is => 'rw', isa => 'Str');
has 'pass' => ( is => 'rw', isa => 'Str');
has 'db'   => ( is => 'rw', isa => 'Str');
has 'ssl'  => ( is => 'rw', isa => 'Bool');
has 'debug'=> ( is => 'rw', isa => 'Bool');

sub connect_db {
	my $self 	= shift;
	my $url		= $self->_generate_url;
}

sub _generate_url {
	my ($self,$qh)	= @_;
	my ($url,$scheme,$destination,$query,$q,$p);

	# take arguments of the form query => 'query', parameters => { p1 => 'v1', p2 => 'v2', ... }
	$q = $qh->{query} if ($qh->{query});
	$p = $qh->{parameters} if ($qh->{parameters});
	$query = "";
	

	# add user from object into query
	if ($query !~ /u=.*?\&{0,1}/) {
		$query = (sprintf 'u=%s&',$self->user()).$query;
		$query =~ s/^\&//; # eliminate the ampersand at start of string if it exists
	}

	
	# add password from object into query
	if ($query !~ /p=.*?\&{0,1}/) {
		$query = (sprintf 'p=%s&',$self->pass()).$query;
		$query =~ s/^\&//; # eliminate the ampersand at start of string if it exists
	}
	
	# append parameters to query if we have them
	if ($p) {
		foreach my $param (sort keys %{$p}) {
			$query .= sprintf '%s=%s&',$param,$p->{$param};
		}
	}
	
	my $dbquery = $q;
	# force quoting of series names ... grrrr
	$dbquery =~ s|from\s+(.*?)\s+|from \"$1\"\ |g;
	#printf "from = %s\n",$1;

	$query .= sprintf 'q=%s',uri_escape($dbquery);

	printf STDERR "D[%i]  Scalable::TSDB::_generate_url; query = \'%s\'\n",$$,$query if ($self->debug());

	# scheme
	$scheme 	= "http";
	$scheme		.= "s" if ($self->ssl());

	# destination (host + port if defined).  localhost is used if host not defined
	$destination = $self->host() || 'localhost';
	$destination .= ":".$self->port() if ($self->port());

	# specific to InfluxDB.  Change for any others
	$url 		= sprintf '%s://%s/db/%s/series?%s',
					$scheme,
					$destination,
					$self->db(),
					$query;
	printf STDERR "D[%i]  Scalable::TSDB::_generate_url; url = \'%s\'\n",$$,$url if ($self->debug());

	return $url;				
}

sub _send_simple_get_query {
	my ($self,$q) = @_;
	my ($ret,$rc,$output,$res,$h,@cols,@points,$i,$m,$count,$return,$rary);
	my $query;
	
	if ($q->{query}) {
		$query=$q;
	}
	
	my $url 	= $self->_generate_url($query);
	my $ua 		= Mojo::UserAgent->new;
	my $json 	= JSON::PP->new;
	$ret 	= $ua->get($url)->res;
	$rc		= $ret->code;
	$return = { rc => $rc };  # default return code
	if (!$ret->is_empty) {
		$output 	= $ret->body;
		if ($output) {
			eval { $res = $json->decode($output); };
			if ($res) {
				# munge this horrible HoAoA into something resembling a sane data structure (HoH)
				$rary = @{$res}[0];				
				@cols 	= @{$rary->{columns}};
				$m 	= $#cols;
				@points = @{$rary->{points}};
				$count  = 0;
				# build a hash of hashes, indexed by a count, such that a pop(keys %$h) will give
				# you the number of records returned
				foreach my $point (@points) {
					for($i=0;$i<=$m;$i++) {
						$h->{$count}->{$cols[$i]} = @{$point}[$i];
					}
					$count++;
				}				
			}
			$return		= { rc => $rc, result => $h};	
		  }		 
	}
	return $return;
}


1;