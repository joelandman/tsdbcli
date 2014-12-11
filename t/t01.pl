#!/opt/scalable/bin/perl

use lib "../lib";
use Scalable::TSDB;
use SI::Utils;
use Data::Dumper;


my ($db,$u);

$db = Scalable::TSDB->new({db => 'd1', user => 'u1', pass => 'p1', ssl => true});
$u  = $db->_generate_url('select * from db'); 

printf "Dumper: %s\n",Dumper($db);
printf "url = %s\n",$u;