#!/opt/scalable/bin/perl

use lib "../lib";
use Nlytiq::TSDB;
use Data::Utils;
use Data::Dumper;


my ($db,$u);

$db = Nlytiq::TSDB->new({db => 'd1', user => 'u1', pass => 'p1', ssl => true});
$u  = $db->_generate_url({query => 'select * from db'}); 

printf "Dumper: %s\n",Dumper($db);
printf "url = %s\n",$u;
