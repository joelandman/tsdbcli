package Scalable::TSDB;

use Moose;
use 5.018;
use feature qw(say);

use Carp;
use Mojo::UserAgent;

has 'host' => { is => 'rw', isa => 'Str'};
has 'port' => { is => 'rw', isa => 'Int'};
has 'user' => { is => 'rw', isa => 'Str'};
has 'pass' => { is => 'rw', isa => 'Str'};
has 'db'   => { is => 'rw', isa => 'Str'};
has 'ssl'  => { is => 'rw', isa => 'Bool'};

sub connect_db {
	my $self 	= shift;
	my $url		= $self->_generate_url;
}

sub _generate_url {
	my ($self,$series)	= @_;
	my ($url,$scheme);

	# add user from object into query
	if ($query !~ /u=.*?\&{0,1}/) {
		$query .= sprintf '&u=%s',$self->user();
		$query =~ s/^\&//; # eliminate the ampersand at start of string if it exists
	}

	# add password from object into query
	if ($query !~ /p=.*?\&{0,1}/) {
		$query .= sprintf '&p=%s',$self->pass();
		$query =~ s/^\&//; # eliminate the ampersand at start of string if it exists
	}

	$scheme 	= "http";
	$scheme		.= "s" if ($self->ssl());
	$url 		= sprintf '%s://%s/db/%s/%s?%s'
}

1;