influxdbcli
===========

InfluxDB CLI to interact with time series databases and data 


Dependencies:
-------------

*  Perl 5.12 or higher
*  several Perl modules [Term::ReadLine](https://metacpan.org/pod/Term::ReadLine), [Term::ReadLine::Gnu](https://metacpan.org/pod/Term::ReadLine::Gnu), 
   [Text::ASCIITable](https://metacpan.org/pod/Text::ASCIITable), [Getopt::Lucid](https://metacpan.org/pod/Getopt::Lucid), [JSON::PP](https://metacpan.org/pod/JSON::PP)),
   [Moose](https://metacpan.org/pod/Moose), [List::MoreUtils](https://metacpan.org/pod/List::MoreUtils)
*  OS ReadLine library
    
Installing dependencies:
------------------------

First pass at installer.  Will check for dependencies.  

*  Perl:  Should be included in your distribution/OS.  If not, your options are 
*  Linux:    Included in distribution
*  MacOSX:   Included in distribution
*  Windows:  
  *  [ActiveState Perl](http://www.activestate.com/activeperl/downloads)
  *  [StrawBerry Perl](http://strawberryperl.com/)
  *  [Cygwin](https://www.cygwin.com/) and installing the Perl components


### OS ReadLine library ###

Should be included in your distribution/OS
*    Linux:    Included in distribution, make sure the /readline/i packages (library/development) are installed
*    MacOSX:   Included in distribution, make sure the /readline/i packages (library/development) are installed
*    Windows:  Cygwin or http://gnuwin32.sourceforge.net/packages/readline.htm 

### Perl modules ###
Some of these modules are not included in the package manager distributions, so you will need to use CPAN to install (let it autoconfigure for you, and use the sudo mechanism)

by hand 
   
* Linux and MacOSX

  `sudo cpan Term::ReadLine Term::ReadLine::Gnu Text::ASCIITable \
	Getopt::Lucid JSON::PP LWP::UserAgent`Moose List::MoreUtils

  additional for MacOSX, assuming [homebrew](http://brew.sh/) is installed
    
    `brew install readline ; \
     brew link --force readline ; \
     sudo cpan Term::ReadLine::Gnu ; \
     brew unlink readline`
  
* Windows:  ActiveState has ppm, Cygwin and StrawBerry Perl have cpan, so use the same approach for Linux here.

Automatically

      make INSTPATH=/path/to/installation

This will create the directory /path/to/installation if it doesn't exist.   If you don't specify INSTPATH, it will use /opt/scalable/influxdb-cli.

[Scalable Informatics](https://scalableinformatics.com) supplies a pre-built stack with all the dependencies and Perl 5.20.1 installed on our appliances, located in the /opt/scalable/ pathway.  If you would like to be able to use this, please contact us.  We may use this path in the usage examples below.

Installation
------------
   Run the installation script.  This will work on Linux and MacOSX.  $_path is the full path to where you would like to install the program.  The libraries (Scalable::TSDB) will be installed below that path in lib/Scalable.

      sudo ./install.pl $_path



Usage
-----

    /opt/scalable/bin/influxdb-cli.pl --user $USER --pass $PASS \
    --host metal --db metrics  
  
  or

    /opt/scalable/bin/influxdb-cli.pl --user $USER --pass $PASS \
    --host metal --db metrics --file=Input.file.ifdb
    
where Input.file.ifdb might look something like this:

    \set format=csv
    \set output=disk.read.data
    select value/1000 from /usn-01.disktotals.readkbs/ limit 100

In these examples, $USER is the username, $PASS is the password.  Note
that the queries are converted to queries.  The InfluxDB escaping is
not automatic, you will need to escape or quote the series names 
properly, according to the InfluxDB developers.  

Note also that the database does not currently signal 
problems with series names in a uniform manner, so you may not get any
rows back if you issue a query for something it interprets differently
from what you expect.


Commands
--------

Commands are prefaced with a '\' character.
  
  
`select QUERY`
execute a query.  Query example:

    select * from metal.diskinfo.writekbs.sda limit 10
  

>     metrics> select * from metal.diskinfo.writekbs.sda limit 10
> 
>     .--------------------------------------.
>     |      metal.diskinfo.writekbs.sda     |
>     +------------+-----------------+-------+
>     | time       | sequence_number | value |
>     +------------+-----------------+-------+
>     | 1408992211 |               1 |   136 |
>     | 1408992210 |               1 |   128 |
>     | 1408992208 |               1 |     0 |
>     | 1408992207 |               1 |     0 |
>     | 1408992206 |               1 |   364 |
>     | 1408992204 |               1 |     0 |
>     | 1408992202 |               1 |     0 |
>     | 1408992201 |               1 |   136 |
>     | 1408992200 |               1 |   132 |
>     | 1408992199 |               1 |     0 |
>     '------------+-----------------+-------'
 
continuous query example, using a previously defined continuous query:   

    select * from sda.writekbs limit 10

>     metrics> select * from sda.writekbs limit 10
>     .-------------------------------------------------.
>     |                   sda.writekbs                  |
>     +------------+-----------------+------------------+
>     | time       | sequence_number | mean             |
>     +------------+-----------------+------------------+
>     | 1408992210 |               1 |              132 |
>     | 1408992195 |               1 | 144.727272727273 |
>     | 1408992180 |               1 |              244 |
>     | 1408992165 |               1 | 83.6363636363636 |
>     | 1408992150 |               1 | 190.571428571429 |
>     | 1408992135 |               1 | 32.3333333333333 |
>     | 1408992120 |               1 | 59.1428571428571 |
>     | 1408992105 |               1 | 107.076923076923 |
>     | 1408992090 |               1 | 103.428571428571 |
>     | 1408992075 |               1 | 165.666666666667 |
>     '------------+-----------------+------------------'     

`\match regex`
  shows the series names that will match the regex.  For example:

>	unison> \match MB
>	.------------------------------.
>	| results: query = '\match MB' |
>	+------------------------------+
>	| series                       |
>	+------------------------------+
>	| unison.sicloud.read.MBps     |
>	| unison.sicloud.read_MBps     |
>	| unison.sicloud.write.MBps    |
>	| unison.sicloud.write_MBps    |
>	'------------------------------'

    unison> \match usn-(\d+).(.*?)disktot(.*?).(read|write)kbs
    .-----------------------------------------------------------------------.
    | results: query = '\match usn-(\d+).(.*?)disktot(.*?).(read|write)kbs' |
    +-----------------------------------------------------------------------+
    | series                                                                |
    +-----------------------------------------------------------------------+
    | usn-01-1g.disktotals.readkbs                                          |
    | usn-01-1g.disktotals.writekbs                                         |
    | usn-02-1g.disktotals.readkbs                                          |
    | usn-02-1g.disktotals.writekbs                                         |
    | usn-03-1g.disktotals.readkbs                                          |
    | usn-03-1g.disktotals.writekbs                                         |
    | usn-03.disktotals.readkbs                                             |
    | usn-03.disktotals.writekbs                                            |
    '-----------------------------------------------------------------------'

  This is syntactic sugar to some degree, but if you have thousands of 
  series, it is very much needed.


`\show query parameters`
  shows parameters related to the queries being executed.
  
>     metrics> \show query parameters
>     .------------------------.
>     |        Parameter       |
>     +----------------+-------+
>     | Parameter      | Value |
>     +----------------+-------+
>     | chunked        |     0 |
>     | time_precision | s     |
>     '----------------+-------'

`\set query parameter=value`
sets a query parameter 

`\set sep=X`
sets the csv output format seperator to the character (really string!) X

`\set output=FILENAME`
sends output from queries to this filename.  It will overwrite the file.  Default output is to STDOUT
  
`\set format={ascii|csv}`
  sets the output format to ascii (nicely formatted ascii tables) or csv (very basic, suitable for post processing with another tool, or graphing with Gnuplot, uses the seperator defined previously, or defaults to a space).   Csv provides a minimal header with a # (pound/hash) symbol at front and a list of the columns in order they are presented. 

`\set db=NAME_OF_DATABASE`
sets the name of the database to connect to on the InfluxDB instance

`\set host=HOSTNAME`
sets the hostname where the InfluxDB instance is running

`\set port=PORT`
sets the port number where the InfluxDB instance is running

`\set user=USERNAME`
sets the username to use to connect to the InfluxDB instance.   Not stored in command history

`\set pass=PASSWORD`
sets the password to use to connect to the InfluxDB instance.   Not stored in command history


`\get format`
  shows the current format state

>     metrics> \get format
>     # format = ascii
   
`\get output`
  shows the current output location.  - means STDOUT.

>     metrics> \get output
>     # outfile = -


Use case:
  
  * Periodic data extractions where a continuous query is less relevant.
  * Examining data from a command line
  * creating continuous queries
  * hand executing continuous queries


Limitations:

  A number of features not yet implemented.

Bugs:

  Queries from multiple sequences with regexs will fail.  Still investigating but
it appears to be related to inconsistent regex/quoting.  

  ReadLine based:  
    symtom:   Can't locate object method "AddHistory" via package 
              "Term::ReadLine::Stub" at /opt/scalable/bin/influxdb-cli.pl line ... 
    reason:   Term::ReadLine is not installed or visible from the module
    fix:      install Term::ReadLine, though we'll probably wrap the AddHistory in an eval.
  
  Query input line based:
    symtom:   Strange parsing error ...
    reason:   naive command line parser, its not a real parser with a grammar
    fix:      TBD

TODO
--------

* Add query and output caching.  
* Provide cli based data language for post query manipulation.  
* Plotting hooks to generate visible plots

Everything else
