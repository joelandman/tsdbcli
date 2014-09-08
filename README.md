influxdbcli
===========

InfluxDB CLI to interact with time series databases and data 


Dependencies:
-------------

*  Perl 5.10 or higher
*  several Perl modules (InfluxDB, Term::ReadLine, Term::ReadLine::Gnu, 
   Text::ASCIITable, Getopt::Lucid, JSON::PP)
*  OS ReadLine library
    
Installing dependencies:
------------------------

We will simplify this in the future with an installer, and likely snapshots of the relevant modules and dependencies, or use PAR::Dist.

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
   
* Linux and MacOSX
    sudo cpan Term::ReadLine Term::ReadLine::Gnu \
              Text::ASCIITable Getopt::Lucid \
              JSON::PP InfluxDB


  
  assuming [homebrew](http://brew.sh/) for MacOSX is installed
  
    brew install readline
    brew link --force readline
    sudo cpan Term::ReadLine::Gnu
    brew unlink readline
  
Windows:  ActiveState has ppm, Cygwin and StrawBerry Perl have cpan, so use the same approach for Linux here.


[Scalable Informatics](https://scalableinformatics.com) supplies a pre-built stack with all the dependencies and Perl 5.18.2 or 5.20.0 installed on our appliances, located in the /opt/scalable/ pathway.  If you would like to be able to use this, please contact us.  We may use this path in the usage examples below.

Installation
------------
   copy the `influxdb-cli.pl` to a path where you will access it from, either in your search path, or at a fixed location that you will always use.


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
    select value/1000 from usn-01.disktotals.readkbs

In these examples, $USER is the username, $PASS is the password.


Commands
--------

Commands are prefaced with a '\' character.
  
`\list {series|continuous}` will list either the series in the database or the continuous queries defined in the database
    
> metrics> \list series
> .-----------------------------.
> | series name                 |
> +-----------------------------+
>| loadavg                     |
>| metal.cpuload.avg1          |
>| metal.cpuload.avg15         |
>| metal.cpuload.avg5          |
>| metal.cputotals.idle        |
>| metal.cputotals.irq         |
>| metal.cputotals.nice        |
>| metal.cputotals.soft        |
>| metal.cputotals.steal       |
>| metal.cputotals.sys         |
>| metal.cputotals.user        |
>| metal.cputotals.wait        |
>...
>| metal.swapinfo.in           |
>| metal.swapinfo.out          |
>| metal.swapinfo.total        |
>| metal.swapinfo.used         |
>| sda.max                     |
>| sda.max1                    |
>| sda.writekbs                |
>'-----------------------------'

>metrics> \list continuous
>.----------------------------------------------------------------------.
>| id | query                                                           |
>+----+-----------------------------------------------------------------+
>|  1 | select mean(value) from metal.diskinfo.writekbs.sda group       |
>|    |            by time(15s) where time > now()-1h into sda.writekbs |
>|  3 | select max(value) from metal.diskinfo.writekbs.sda group        |
>|    |            by time(5s) into sda.max1                            |
>'----+-----------------------------------------------------------------'

`\create continuous QUERY`
create a continuous query.  For example: 

    select mean(value) from metal.diskinfo.writekbs.sda group by time(15s) where time > now()-1h into sda.writekbs
  
`select QUERY`
execute a query.  Query example:

    select * from metal.diskinfo.writekbs.sda limit 10
  

>     metrics> select * from metal.diskinfo.writekbs.sda limit 10
> 
>     .--------------------------------------.
>     |      metal.diskinfo.writekbs.sda     |
>     +------------+-----------------+-------+
> | time       | sequence_number | value |
> +------------+-----------------+-------+
> | 1408992211 |               1 |   136 |
> | 1408992210 |               1 |   128 |
> | 1408992208 |               1 |     0 |
> | 1408992207 |               1 |     0 |
> | 1408992206 |               1 |   364 |
> | 1408992204 |               1 |     0 |
> | 1408992202 |               1 |     0 |
> | 1408992201 |               1 |   136 |
> | 1408992200 |               1 |   132 |
> | 1408992199 |               1 |     0 |
> '------------+-----------------+-------'
 
continuous query example, using the previously defined continuous query:   

    select * from sda.writekbs limit 10

>metrics> select * from sda.writekbs limit 10
>.-------------------------------------------------.
>|                   sda.writekbs                  |
>+------------+-----------------+------------------+
>| time       | sequence_number | mean             |
>+------------+-----------------+------------------+
>| 1408992210 |               1 |              132 |
>| 1408992195 |               1 | 144.727272727273 |
>| 1408992180 |               1 |              244 |
>| 1408992165 |               1 | 83.6363636363636 |
>| 1408992150 |               1 | 190.571428571429 |
>| 1408992135 |               1 | 32.3333333333333 |
>| 1408992120 |               1 | 59.1428571428571 |
>| 1408992105 |               1 | 107.076923076923 |
>| 1408992090 |               1 | 103.428571428571 |
>| 1408992075 |               1 | 165.666666666667 |
>'------------+-----------------+------------------'     

  \show query parameters
  shows parameters related to the queries being executed.
  
>metrics> \show query parameters
>.------------------------.
>|        Parameter       |
>+----------------+-------+
>| Parameter      | Value |
>+----------------+-------+
>| chunked        |     0 |
>| time_precision | s     |
>'----------------+-------'

\set query parameter=value
sets a query parameter (currently broken, do not use)

\set sep=X
sets the csv output format seperator to the character (really string!) X

\set output=FILENAME
sends output from queries to this filename.  It will overwrite the file.  Default output is to STDOUT
  
\set format={ascii|csv}
  sets the output format to ascii (nicely formatted ascii tables) or csv (very basic, suitable for post processing with another tool, or graphing with Gnuplot, uses the seperator defined previously, or defaults to a space).  

  Csv provides a minimal header with a # (pound/hash) symbol at front and a list of the columns in order they are presented.
  
\get format
  shows the current format state

>metrics> \get format
># format = ascii
   
  \get output
  shows the current output location.  - means STDOUT.

>metrics> \get output
># outfile = -


Use case:
  
  * Periodic data extractions where a continuous query is less relevant.
  * Examining data from a command line
  * creating continuous queries
  * hand executing continuous queries


Limitations:

  A number of features not yet implemented.  Continuous queries cannot be deleted (yet).  

Bugs:

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

Everything else
