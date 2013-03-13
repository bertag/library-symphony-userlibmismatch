#!/opt/sirsi/Unicorn/Bin/perl

#Import Ostinato
use lib "ostinato";
use Getopt::Long;
use Ostinato::Transaction;

#Get Flags from command line
my $optParser = new Getopt::Long::Parser;
my %optFlags = ();
$optParser->configure("bundling");
$optParser->getoptions(\%optFlags,
#	"help|?|x|h",
	"config=s",
	"destination=s",
);

my $vars = prepFromFlags(\%optFlags);
runProgram($vars);

sub prepFromFlags
{
	my $flags = shift;
	my %vars  = ();

	if(defined($flags->{'config'}))
	{
		$config = YAML::LoadFile($flags->{'config'});
		$vars{'userlib'} = defined $config->{'userlib'}  ?  $config->{'userlib'}  :  "";
		$vars{'usercat'} = defined $config->{'usercat'}  ?  $config->{'usercat'}  :  "";
		$vars{'startdate'} = defined $config->{'startdate'}  ?  $config->{'startdate'}  :  "";
		$vars{'enddate'}   = defined $config->{'enddate'}    ?  $config->{'enddate'}    :  "";
		$vars{'address_policy_codes'} = defined $config->{'address_policy_codes'}  ?  $config->{'address_policy_codes'}  :  "";

		if($vars{'startdate'} eq "" || $vars{'enddate'} eq "" || ($vars{'userlib'} eq "" && $vars{'usercat'} eq ""))
		{
			die("ERROR: 'startdate', 'enddate', and 'address_policy_codes'  must be defined in your config file.  Additionally, either 'userlib' or 'usercat' must be defined in your config file.\nRun \"perldoc userlibmismatch.pl\" for more information\n");
		}
	}
	else
	{
			die("ERROR: Define config file by running \"userlibmismatch.pl --config='path/to/config'.\nRun \"perldoc userlibmismatch.pl\" for more information\n");
	}

	$vars{'destination'} = defined($flags->{'destination'}) && -w $flags->{'destination'}
	                       ?  $flags->{'destination'}
						   :  '/proc/self/fd/1';  #Default to STDOUT if destination is not writable or undefined

	return \%vars;
}


sub runProgram
{
	my $vars = shift;

	#Pull in and format variables
	my $dateStart = Date::Parse::str2time($vars->{'startdate'});
	my $dateEnd   = Date::Parse::str2time($vars->{'enddate'});
	my $userlib   = $vars->{'userlib'};
	my $userlibstring   = defined $vars->{'userlib'} && $vars->{'userlib'} ne ''
	                      ?  "-y" . $vars->{'userlib'}
						  :  "";
	my $usercatstring   = defined $vars->{'usercat'} && $vars->{'usercat'} ne ''
	                      ?  "-q" . $vars->{'usercat'}  
						  :  "";
	my @address_policy_codes = split(',', $vars->{'address_policy_codes'});
	my $address_string = "";
	foreach (@address_policy_codes)
	{
		$address_string .= "V.$_.";
	}

	#Ostinato will now go to town....
	my $transactor = new Ostinato::Transaction();
	$transactor->autoprepare($dateStart,$dateEnd);
	$transactor->extractdata({
		cmdcode     => "CV",
		outcode     => "UO,FE",
		datacode    => "FE!" . $userlib,
		timestamp   => Ostinato::TRUE,
		command     => 'sed "s/$/\\|/" | seluser -iB ' . $usercatstring . $userlibstring . ' -oBDqr' . $address_string . 'S 2>testrun.error | sort ',
		destination => $vars->{'destination'},
	});
}
