#!/opt/scalable/bin/perl

use lib "../lib";
use Scalable::TSDB;
use SI::Utils;
use Data::Dumper;


my ($db,$u,$r);

$db = Scalable::TSDB->new(
							{
								host 	=> 'unison', 
								port 	=> 8086, 
								db 		=> 'unison', 
								user 	=> 'scalable', 
								pass	=> 'scalable', 
								ssl 	=> false,
								debug	=> true
							}
						);

$r	= $db->_send_simple_get_query('list series');

printf "Dumper: %s\n",Dumper($db);
printf "r = %s\n",Dumper($r);