#!/opt/scalable/bin/perl

use lib "../lib";
use Scalable::TSDB;
use SI::Utils;
use Data::Dumper;


my ($db,$u,$r);

$db = Scalable::TSDB->new(
							{
								host 	=> '192.168.101.250', 
								port 	=> 8086, 
								db 		=> 'unison', 
								user 	=> 'scalable', 
								pass	=> 'scalable', 
								ssl 	=> false,
								debug	=> true
							}
						);

$r	= $db->_send_simple_get_query({ query => 'list series'});

printf "Dumper: %s\n",Dumper($db);
printf "r = %s\n",Dumper($r);
