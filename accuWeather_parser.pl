#!/usr/bin/perl
use utf8;
binmode(STDOUT, ":utf8");
use LWP::Simple;

#use WWW::Mechanize::Firefox;
#use WWW::WebKit;
#my $mech = WWW::Mechanize::Firefox->new();
#my $webkit = WWW::WebKit->new();
#$webkit->init;
use HTML::TreeBuilder::XPath;
use strict;
use warnings;
use feature qw{say switch};
use Data::Dumper;
use Storable;
use Carp;
use Term::ANSIColor qw{:constants};
use BCscripts::Debug::Func qw{:Debug :CAuto :PrintSay};
use experimental qw(smartmatch switch autoderef);
DebugConfig(
	Anime	=> YELLOW,
	Score	=> RED,
	Anime2	=> GREEN,
	Score2	=> RED,
);
#my $url = 'http://myanimelist.net/anime/21273/Gochuumon_wa_Usagi_Desu_ka/userrecs';
my $Name = "AccuWeather";
my $Site = 'http://www.accuweather.com';
my $Location = "/en/us/lakeland-tn/38002/";
my $LocationID = "2201989";

my $CONFIG = { };
$CONFIG->{Lifetime}{Current}=ToSec('1m');
$CONFIG->{Lifetime}{Today}=ToSec('1hr'); # Daily forecast for the current day.
$CONFIG->{Lifetime}{Minutes}=ToSec('1m');
$CONFIG->{Lifetime}{Hours}=ToSec('10m');
$CONFIG->{Lifetime}{Days}=ToSec('5hr');
#$CONFIG->{Lifetime}{Days}=ToSec('1hr'); # TODO Dynamic ranges. Eg, Lifetime>Days>1=1hr, Liftime>Days>2-7=5hr, Lifetime>Days>8-45=2days
$CONFIG->{Lifetime}{Advisories}=ToSec('1m');
$CONFIG->{Get}{Current}=1;
$CONFIG->{Get}{MinuteCast}=1;
$CONFIG->{Get}{Hourly}=1;
$CONFIG->{Get}{Day}=1;
$CONFIG->{Get}{Tomarrow}=1;
$CONFIG->{Get}{Week}=1;
$CONFIG->{Get}{Month}=0;
$CONFIG->{Get}{Year}=0;
$CONFIG->{Get}{Condition}=1;
$CONFIG->{Get}{Perc}{Rain}=1;
$CONFIG->{Get}{Perc}{Hail}=1;
$CONFIG->{Get}{Perc}{Snow}=1;
$CONFIG->{Get}{Perc}{Sleat}=1;
$CONFIG->{Get}{Perc}{Ice}=1; # Icing roads
$CONFIG->{Get}{Perc}{Tornadic}=1;
$CONFIG->{Get}{Perc}{Hurican}=1;
$CONFIG->{Get}{Temp}{High}=1;
$CONFIG->{Get}{Temp}{Low}=1;
$CONFIG->{Get}{Temp}{Average}=1;
$CONFIG->{Get}{Advisories}{Active}=1;
$CONFIG->{Get}{Advisories}{Pending}=1;
#################################	A Day	*	7

# FIXME When grouping Series Votes, We should consider things like, Number of episoded, Type (1 ep movie/OVA/SpinOff), Num of Recomendations.
# TODO Generate recomendations for each combination of Genres.
# TODO Basic Statistics. (Calculate  BellCurve for Score and Calculate common combinations for genres.) (Obviousle, I'm not familure with statistics)
my $List;
my $STORE_FILE='/home/beck/tmp/' . $Name . '.db';
my $STORE={};
my $FC={};
######
# MAIN
######
sub NO_OP {
	return;
	my $IFC;
my $IFC_Examp = {
	Time=>0, # The time the forecast refers to
	Range=>'24h', # How long the forecast refers to.(current=0s,minutcast=60s,hourly=60min,daily=24hr)
	LastUpdated=>0,
	Units=>'Metric', # Metric or Imperial
	Weather=>{
		Temp=>0,
		Humidity=>0,
		Description=>"Clear",
		Percipitation=>{Chance=>0,Amnt=>0,TotalDurration=>0},
		Rain=>{Chance=>0,Amnt=>0,TotalDurration=>0},
		Snow=>{Chance=>0,Amnt=>0,TotalDurration=>0},
		Sleat=>{Chance=>0,Amnt=>0,TotalDurration=>0},
		Hail=>{Chance=>0,Amnt=>0,TotalDurration=>0},
		Thunderstorm=>{Chance=>0,TotalDurration=>undef},
		Tornado=>{Chance=>0,TotalDurration=>undef},
		Wind=>{Speed=>0,Dir=>'N'},
		UV_Index=>{Max=>0,Min=>0,Cur=>0}
	},
	Feel=>{
		Temp=>0,
	},
};
my $FC_Example={
	# Current now prepended with 0 for start-time for 
	Current=>{0=>$IFC},
	Minutes=>{starttime1=>$IFC,starttime=>$IFC},
	Hours=>{starttime1=>$IFC,starttime2=>$IFC},
	Days=>{starttime1=>$IFC,starttime2=>$IFC},
};
}
$FC=retrieve($STORE_FILE) if ( -e $STORE_FILE);
#StoreUpdate();
#die 'PAUSED';
my $INST={};

__Read_Args();
# NOTE Helper Vars. Should be replaced once structure is stable

store($FC, $STORE_FILE);
#EnhancedRecs(keys $STORE->{UserList}{$User}{$Type}{Completed});
##################
# HELPER FUNCTIONS
##################
sub Build_Html_Tree {
	my $path = shift;
	my $query = shift//'';
	my $page = join('/',$Site,$Location,$path,$LocationID ) . $query;
	my $content = get( $page ) or die("Unable to fetch page <" . $page . ">!"); # lwp
	#$lwp->wait_for_page_to_load(15000);
	my $FCTree = HTML::TreeBuilder::XPath->new_from_content($content);
	return $FCTree;
}
#########
# STORAGE
#########
my $STORE_CNT=0;

sub IsOld {
	my $LastUpdate=shift//0;
	my $LifeTime=shift//0;
	#return 1 if	($LastUpdate + $LifeTime <= time );
	if	($LastUpdate + $LifeTime <= time ) {
		Info "It's Old $LastUpdate + $LifeTime <= " . time;
		return 1;
	}
	Info "It's Good $LastUpdate + $LifeTime > " . time;
	return 0;
}

#########
# Weather
#########
sub GetForecast { # Parses Extended Forcast
	my $Root=Build_Html_Tree( 'daily-weather-forecast');
	#my $Root=Build_Html_Tree( $Location);
	Msg "Will Get:\nCurrent Minutes Hours Days";
	# FIXME Need to check parse didn't fail on each, and return error and keep old values if it did.
	my $tfc = {
		Current=>{0=>GetCurrent()},
		Minutes=>GetMinutes(),
		Hours=>GetHours(),
		Days=>GetDays(),
	};
	$FC=$tfc;
	#Info Dumper $FC;
	store($FC, $STORE_FILE);
	return $FC
}

### TAB PARSERS

# Parse the daily tab
sub GetDays() {
	my $tfc = $FC->{Days}//{};
	return $tfc unless IsOld($tfc->{LastUpdated},$CONFIG->{Lifetime}{Days});
	$tfc->{Range}=ToSec('24h');
	$tfc->{LastUpdated}=time;
	for my $i (1..45) {
		my $day = Daily_Parser($i);
		$tfc->{$day->{Time}}=$day;
	}
	return $tfc
}
sub GetHours() {
	my $tfc = $FC->{Hours}//{};
	return $tfc unless IsOld($tfc->{LastUpdated},$CONFIG->{Lifetime}{Hours});
	$tfc = Hourly_Parser();
	return $tfc;
}
sub GetMinutes() {
	my $tfc = $FC->{Minutes}//{};
	return $tfc unless IsOld($tfc->{LastUpdated},$CONFIG->{Lifetime}{Minutes});
	$tfc = Minut_Parser();
	return $tfc;
}
sub GetCurrent() {
	my $tfc = $FC->{Current}//{};
	return $tfc unless IsOld($tfc->{LastUpdated},$CONFIG->{Lifetime}{Current});
	$tfc = Current_Parser();
	return $tfc;
}
sub Daily_Parser() {
	my $day=shift//1;
	my $Root=Build_Html_Tree( 'daily-weather-forecast',"?day=$day" );
	my $tfc = {}; # ForCast
	$tfc->{Time}=DateParser($Root);
	$tfc->{Range}=ToSec('24h');
	$tfc->{LastUpdated}=time;
	foreach my $DayCast ( $Root->findnodes('//div[@id="detail-day-night"]/div') ) {
		$tfc={%{$tfc},%{ForecastInfo_Parser($DayCast)}};
		my $Cont = $DayCast->findnodes('.//div[@class="content"]')->[0];
			#TODO Desc
			my $Stats = $Cont->findnodes('./ul[@class="stats"]')->[0];
			$tfc= { %{$tfc}, %{Stats_Parser($Stats)} };
	}
	return $tfc;
}
sub Current_Parser() {
	my $Root=Build_Html_Tree('current-weather');
	my $tfc = {}; # ForCast
	$tfc->{Time}=0;
	$tfc->{Range}=0;
	$tfc->{LastUpdated}=time;
	foreach my $DayCast ( $Root->findnodes('//div[@id="detail-now"]/div') ) {
		$tfc={%{$tfc},%{ForecastInfo_Parser($DayCast)}};
		my $Cont = $DayCast->findnodes('.//div[@class="more-info"]')->[0];
			#TODO Desc
			my $Stats = $Cont->findnodes('./ul[@class="stats"]')->[0];
			$tfc= { %{$tfc}, %{Stats_Parser($Stats)} };
	}
	return $tfc;
}
# Parses Day/Night Subsection
# Page up to ?hour=curhour+85.
sub OverwriteTable {
	my $orig=shift||{};
	my $new=shift||{};
	foreach my $key (keys $new) {
		$orig->{$key}=$new->{$key};
	}
}
sub Hourly_Parser() {
	my $Root=Build_Html_Tree('hourly-weather-forecast' );
	my $Hourly = $Root->findnodes('//div[@id="detail-hourly"]/div/table[@class="data"]')->[0];
	my $i=0;
	my $tfc={};
	my @FCs;
	$tfc->{Range}=ToSec('1h');
	$tfc->{LastUpdated}=time;
	my $first=1;
	my $time;
	foreach my $header ($Hourly->findnodes('./thead/tr/th')) {
		next if ($i++ == 0 && scalar $header->findnodes('./@class="first"') == 1 );
		if ($first) {
			($time) = $header->findnodes_as_string('.') =~ m{(\d\d?(?:am|pm))} or die "Could Not Find Time in Detail-Hourly header<" . $header->findnodes_as_string('.') .">";
			$time = qx{date --date='$time' +%s}; # FIXME remove all qx/syscalls
			chomp($time);
			$first=0;
		}
		my $hfc = {};
		$hfc->{Time}=$time;
		$hfc->{Range}=ToSec('1h');
		$hfc->{LastUpdated}=time;
		$tfc->{$time}=$hfc;
		push(@FCs,$hfc);
		$time+=ToSec('1h');
	}
	foreach my $row ($Hourly->findnodes('./tr')) {
		my $class = $row->findvalue('./@class');
		my $name = $row->findvalue('./th');
		say "Class<$class> Name<$name>";
		$i=0;
		foreach my $col ($row->findnodes('./td')) {
			my $hfc=$FCs[$i++];
			my $val =  $col->findvalue('.');
			my ($nval) =  $val =~ m{(\d+(?:[%\x{b0}]|am|pm|hours|min|sec|hr)?)};
			OverwriteTable($hfc,NamedParser({name=>$name,val=>$val,nval=>$nval}));
		}
	}
	return $tfc;
}
sub Minut_Parser() {
	my $Root=Build_Html_Tree('minute-weather-forecast' );
	my @minutes;
	foreach my $num (0,30,60,90) {
		foreach my $col ($Root->findnodes('//div[@id="mc-' . $num . '"]/div[@class="minute-column"]')) {
			#push(@minutes,$col->findnodes('./ul[@class="minute-list"]/li')); # FIXME contains class
			push(@minutes,$col->findnodes('./ul/li'));
		}
	}
	my $tfc={};
	$tfc->{Range} = ToSec('1m');
	$tfc->{LastUpdated} = time;
	my $first=1;
	my $date;
	foreach my $Min (@minutes) {
		my $mfc = {};
		if ($first) {
			my $hrmin = $Min->findvalue('./span[@class="time"]');
			$date = qx{date --date='$hrmin' +%s}; # FIXME remove all qx/syscalls
			chomp($date);
			$first=0;
		}
		$mfc->{Time} = $date;
		# FIXME NOTE TODO Possible Risk of Jumping Minutes. Add checks and a better converter.
		#my $hrmin = $Min->findvalue('./span[@class="time"]');
		#my $chkdate = qx{date --date='$hrmin' +%s}; # FIXME remove all qx/syscalls
		#chomp($chkdate);
		#my $chkhrmin =  qx{date --date='\@$date' +%H:%M};
		#chomp($chkhrmin);
		#Wrn 'Date ', $chkhrmin, ' Accu ', $Min->findvalue('./span[@class="time"]');
		#Info 'Date ', $date, ' Accu ', $chkdate;
		$mfc->{Weather}{Description} = $Min->findvalue('./span[@class="type"]');
		$mfc->{Range} = ToSec('1m');
		$mfc->{LastUpdated} = time;
		$tfc->{$mfc->{Time}} = $mfc;
		$date+=ToSec('1m');
	}
	return $tfc;
}
sub ForecastInfo_Parser() {
	my $DayCast=shift;
	my $tfc={};
	my $Info = $DayCast->findnodes('.//div[@class="info"]')->[0];
	$tfc->{Temp}		= $Info->findvalue('./span[@class="temp"]');
	$tfc->{Condition}		= $Info->findvalue('./span[@class="cond"]');
	my $RealFeel	= $Info->findnodes_as_string('./span[@class="realfeel"]');
	($tfc->{RealFeel}{Temp}) = $1 if $RealFeel =~ m{RealFeel.?\s+(\d+)};
	($tfc->{RealFeel}{Percipitation}) = $1 if $RealFeel =~ m{Precipitation.?\s+(\d+)%};
	return $tfc;
}
sub Advisories_Parser() { # TODO
	my $Root=Build_Html_Tree( $Location . '/weather-warnings/' . $LocationID );
}
sub Stats_Parser() {
	my $Stats=shift;
	my $tfc={};
	foreach my $stat ($Stats->findnodes('./li')) {
		my $val=$stat->findvalue('./strong');
		my ($name) = $stat->findvalue('./text()') =~ m{^([^:]+):};
		OverwriteTable($tfc,NamedParser({name=>$name,val=>$val,nval=>$val}));
	}
	return $tfc;
}
sub DateParser() {
	# Parsing the date from the site seems easier than determining weather day1 == pc's current day, tomarrow, or yesterday.
	# Especialy when the current time is between 23:59 and 00:01.
	my $Root=shift;
	my ($month,$day) = $Root->findvalue('//div[@id="feed-tabs"]/ul/li[contains(@class,"current")]/div/h4') =~ m{^(\S+)\s+(\d+)$};
	my $date = qx{date --date='$month $day' +%s};
	use DateTime;
	# return DateTime->new(month => $month, day => $day, time_zone => "America/Chicago")->epoche();
	return $date;
}
sub NamedParser() {
	my $args=shift;
	my $name=$args->{name};
	my $val=$args->{val}||$args->{nval}||undef;
	my $nval=$args->{nval}||$val;
	my $lFC={};
	given ($name) {
		when ('Forecast') { $lFC->{Weather}{Description}=$val; }
		when (/^Wind/) { $lFC->{Weather}{Wind}{Speed}=$val; }
		when (/^Temp/) { $lFC->{Weather}{Temp}=$val; }
		when (/^RealFeel/) { $lFC->{Feel}{Temp}=$val; }
		when ('Max UV Index') { $lFC->{Weather}{UV_Index}{Max}=$val; }
		when ('Thunderstorms') { $lFC->{Weather}{Thunder}{Chance}=$val; }
		when ('Precipitation') { $lFC->{Weather}{Percipitation}{Amnt}=$val; }
		when ('Rain') { $lFC->{Weather}{Rain}{Amnt}=$nval; }
		when ('Snow') { $lFC->{Weather}{Snow}{Amnt}=$nval; }
		when ('Ice') { $lFC->{Weather}{Ice}{Amnt}=$nval; }
		when ('Hours of Precipitation') { $lFC->{Weather}{Percipitation}{TotalDurration}=$val; }
		when ('Hours of Rain') { $lFC->{Weather}{Rain}{TotalDurration}=$val; }
		when ('Humidity') { $lFC->{Weather}{Humidity}=$val; }
		when ('Pressure') { $lFC->{Weather}{Pressure}=$val; }
		when ('UV Index') { $lFC->{Weather}{UV_Index}{Current}=$val; }
		when ('Cloud Cover') { $lFC->{Weather}{CloudCoverage}=$val; }
		when ('Ceiling') { $lFC->{Weather}{Ceiling}=$val; } # Where clouds start?
		when ('Dew Point') { $lFC->{Weather}{Dew}{Point}=$val; }
		when ('Visibility') { $lFC->{Weather}{Visibility}=$val; }
		when (/^Middle Grid line/) { return $lFC; }
		#when ('') { $lFC->{}=$val; }
		default {
			Warn qq{Unhandled Name<$name> Value<$val>.};
		}
	}
	return $lFC;
}
#############
# Helpers {{{
# Stollen from IdleScript
sub MakeKeyArray { 
	#shift; # Discard $PM or self; # FIXME Its hard to determin when $PM->MakeKeyArray will and wont pass self... As such, we are requiring noself 
	my @Ret;
	foreach my $arg (@_) {
		if (ref $arg eq 'ARRAY') {
			my @A = MakeKeyArray(@$arg);
			push @Ret, @A if (scalar(@A)>=1); # These are side by side
		} elsif (ref $arg eq 'HASH') {
			foreach my $key (keys $arg){
				my @H = MakeKeyArray($arg->{$key});
				foreach my $FatVal (@H) {
					my @val=MakeKeyArray($FatVal); # Flatten the returned array or return given scalar
					push @Ret, [$key, @val];
				}
			}
		} else {
			push @Ret, $arg;
		}
	}
	return @Ret;
}
# Slightly modified Nested hash, originally by ikegami and Axeman 
# https://stackoverflow.com/questions/11505100/perl-how-to-turn-array-into-nested-hash-keys
sub NestedHash {
	my $args = {
		Assighn=> 'Set', # Set, Appened, Merge
		CroakOnError => 0,
		Overwrite => 0,
		Actions => "Return",
	};
	#shift; # Discard $PM or self;
	# We can do 3 things. We can only use existing keys,
	# Create the Last key at the end of the chain,
	# Or create keys recursivly
	
	# CHECK ARGS
	Croak "NestedHash expects a argument Hash" unless ( (scalar @_ %2) == 0 );
	$args = {%$args, @_};
	my @accepted_args = qw{Create Keys Hash Value Assighn Actions Overwrite CroakOnError};
	foreach my $key (qw{Hash Keys}) {
		Croak "NestedHash requires key '$key' to be passed." unless exists $args->{$key};
	}
	foreach my $key (keys $args) {
		Carp "NestedHash does not take a '$key' key. Please use only<" .join(' ',@accepted_args) .'>' unless ($key ~~ @accepted_args);
	}
	Croak "NestedHash's Assighn must be either 'Set', 'Appened'/'Add', 'Merge', 'IfNonExisting', or 'IfUndef'." unless ($args->{Assighn} ~~ @{[qw{Set Add Appened Merge IfNonExisting IfUndef NonExisting Undef}]});
	$args->{Assighn} = 'Appened' if ($args->{Assighn} eq 'Add');
	my $Return={ # Prior to us setting/creating them.
		Exists=>1,
		Defined=>1,
		Error=>0,
		Value=>undef,
		Parent=>undef,
		LastKey=>undef,
	};

	#HELPERS
	my $Error=sub { 
		if ($args->{CroakOnError}) {
			Croak @_;
		}
		$Return->{Error}=\@_;
	};
	
	# KEY DECENDER
	my $Goal = $args->{Create} // 'Exist'; # Goal defaults to Exists
	my $ref = \$args->{Hash};
	my @keys = (ref $args->{Keys} eq 'ARRAY' ) ? @{$args->{Keys}} : @{[$args->{Keys}]};
	my $key;
#	Info "Nested Hash recieved Keys @keys TOTAL: ", scalar(@keys);
	while (scalar(@keys) >= 1) { #FIXME This seems too magical
		$key = shift @keys;
		my $lref = $$ref;
		$Return->{Parent} = $lref;
		$Return->{LastKey} = $key;
#		Info "ON $key HAVE @keys TOTAL: ", scalar(@keys);
		if (exists $lref->{ $key } 
		 ||($Goal eq "Last" && scalar(@keys) == 0)
		 ||($Goal eq "Recursive")) {
			if (scalar(@keys) >= 1) {
				$ref = \$lref->{ $key }; #FIXME should probably be if exists then this
				$$ref={} if ($args->{Overwrite} || ! $$ref);
				if (ref $$ref ne "HASH") {
					$Return->{Value}=$$ref;
					$Return->{Exists}=0; $Return->{Defined}=0;
					$Error->("Existing key $key is not a hash but we still need to decened to @keys.");
				}
			} else {
				$Return->{Exists}=0 unless exists $lref->{$key};
				$Return->{Defined}=0 unless defined $lref->{$key};
				$ref = \$lref->{ $key }; 
				$Return->{Value}=$$ref;
			}
		} else {
			$Return->{Exists}=0; $Return->{Defined}=0;
			$Error->("Tried to acess nonexisting key $key @keys on $Goal");
			return $Return;
		}
	}

	# VALUE SETTER
    if (exists $args->{Value}) {
		given ($args->{Assighn}) {
		    when ('Set' || 'Replace') {
			    $$ref = $args->{Value};
			}
		    when ('IfNonExisting') {
			    $$ref = $args->{Value} unless ($Return->{Exists});
			}
			when ('IfUndef') {
			    $$ref = $args->{Value} unless ($Return->{Defined});
			}
			when ('Merge') {
			    $$ref = merge($$ref,$args->{Value});
			}
			when ('Appened') {
				if (ref $args->{Value} eq 'ARRAY') {
					$$ref = [] unless defined($$ref); # NOTE if the original value is undef, we currently assume empty list. )
					$$ref = [$$ref] if (ref $$ref ne 'ARRAY') ; # NOTE cosider making this more flexible
					$$ref = [@{$$ref}, @{$args->{Value}} ];
				} 
				elsif (ref $args->{Value} eq 'HASH') {
					$$ref = {} unless defined($$ref);
					if (ref $$ref ne 'HASH') { # FIXME through an error?
						Confess "Trying to appened a hash to a non hash";
						$$ref = {};
					}
					$$ref = { %{$$ref}, %{$args->{Value}} };
				}
			}
		} # END given
	}
	$Return->{Value}=$$ref;
	$Return->{Ref}=$ref; # Because if value is undef or not a ref, altering it becomes dificault...
    return $Return; # Returns the last key by default
}
# Helpers }}}
#############

#######################
# Generic Functions {{{
#######################
sub IsDigit {
	my $Digit = shift;
	return 1 if ($Digit =~ m{^((\d+(\.\d*)?)|(\d*\.\d+))$});
	return 0;
}
sub ToSec {
    my $time = shift;
    my $Seconds = 0;
	return 0 unless defined($time);
	return $time if $time =~ m{^( '-'? \d+ | inf )$}x;
	#Croak q{Time Uninitialized} unless defined($time);
	#while ($time =~ m{ (\d+) \s* ([^0-9 \t]+)?  }gx) {
	while ($time =~ m{ (\d+(?:\.\d*)?|`\d*\.\d+) \s* ([^0-9 \t]+)?  }gx) {
        my $sec = $1;
        my $format=$2 || '';
        if ($format =~ m{^ d(ays?)? $}ix) {
            $Seconds+=$sec*60*60*24;
		} elsif ($format =~ m{^ h((ou)?rs?)? $}ix) {
            $Seconds+=$sec*60*60;
        } elsif ($format =~ m{^ m(in(ute)?s?)? $}ix) {
            $Seconds+=$sec*60;
        } elsif ($format =~ m{^ (s(ec(ond)?s?)?)? $}ix) {
            $Seconds+=$sec;
        } else {
            Croak q{Unknown Time Format }, $format, q{ In }, $time;
        }
    }
    return $Seconds;
}

sub __Read_Args {
	PARSE_ARGUMENTS:
	while (${ARGV[0]}) { # While ARGV[0] exist
		given (${ARGV[0]}) { # check if ARGV[0] Value
			when (/^-h$|^--help$/) {
				PrintHelp();
				exit;
			}
			when (/^(-l|--link)$/) {
				shift @ARGV;
				$CONFIG->{Options}{Linking}=1;
			}
			when (/^(-ns|--no-save)$/i) {
				shift @ARGV;
				$STORE_FILE='/dev/null';
			}
			when ('test-days') {
				GetDays();
				shift @ARGV;
			}
			when (/test-now/i) {
				GetCurrent();
				shift @ARGV;
			}
			when (/test-hour/i) {
				#Hourly_Parser();
				GetHours();
				shift @ARGV;
			}
			when (/test-min/i) {
				GetMinutes();
				shift @ARGV;
			}
			when ('update-forecast') {
				GetForecast();
				shift @ARGV;
			}
			when ('forcast'){
				shift @ARGV;
				Forecast_Args();
			}
			when ('retrieve'){
				shift @ARGV;
				Time_Args();
			}
			default {
				say "Unknown Option '$ARGV[0]'";
				PrintHelp();
				exit;
			}
		}
	}
	return 0;
}
sub Forecast_Args {
	my $Time=[];
	while (@ARGV) {
		given ($ARGV[0]) {
			when (/^time$/i) {
				shift @ARGV;
				$Time=Time_Arg();
				shift @ARGV;
			}
			when (/^type$/i) {
				shift @ARGV;
				Type_Arg($Time);
				shift @ARGV;
			}
			when (/^location$/i) {
				shift @ARGV;
				my $loc=shift @ARGV;
			}
			default {
				return;
			}
		}
	}
}
sub Time_args {
	while (@ARGV) {
		given ($ARGV[0]) {
			when (/^d(ays?)?$/i) {
				shift @ARGV;
				my $time=shift @ARGV;
			}
			when (/^h((ou)?rs?)?$/i) {
				shift @ARGV;
				my $type=shift @ARGV;
			}
			when (/^m(in(ute)?s?)?$/i) {
				shift @ARGV;
				my $type=shift @ARGV;
			}
			default {
				return;
			}
		}
	}
}
sub TypeArgs {
	while(@ARGV) {
		Type_Arg($ARGV[0]);
	}
}
sub Type_Arg {
	my $oarg=$ARGV[0];
	my $arg=$oarg;
	my $Times=shift||[];
	my @Refs;
	push(@Refs,$FC);
	my @Keys;
	while (defined($arg) and $arg ne '') {
		my ($key,$type,$next) = $arg =~ m{^([^{},]+)(?:([{},])(.*))?$};
		my $opener = (defined($type) && $type eq '{') ? 1 : 0;
		my $closer = (defined($type) && $type eq '}') ? 1 : 0;
		my $ref=$Refs[-1];
			if ($opener) {
				#	push(@Refs,$ref->{$key});
				push(@Keys,$key);
			} elsif ($closer) {
				#Info $ref->{$key};
				#foreach my $time (@{$CONFIG->{Times}}) {
				Err "Closer after key<$key> without matching opener in request<$oarg>." unless (scalar(@Keys));
				foreach my $time (@{$Times}) {
					my $nestedkeys = [@{$time},@Keys,$key];
					my $nk = NestedHash(Hash=>$FC,Keys=>$nestedkeys);
					next unless ($nk->{Exists});
					Err $nk->{Error} if ($nk->{Error});
					Msg (CWrn(join('>', @$nestedkeys)),' ', (Dumper $nk->{Value}));
				}
				#pop(@Refs);
				pop(@Keys);
			} else {
				#print $ref->{$key};
				foreach my $time (@{$Times}) {
					my $nestedkeys = [@{$time},@Keys,$key];
					my $nk = NestedHash(Hash=>$FC,Keys=>$nestedkeys);
					next unless ($nk->{Exists});
					Err $nk->{Error} if ($nk->{Error});
					Msg (CWrn(join('>', @$nestedkeys)),' ', (Dumper $nk->{Value}));
				}
			}
		$arg=$next;
	}
}
sub Time_Arg {
	my $oarg=$ARGV[0];
	my $arg=$oarg;
	my @Refs;
	push(@Refs,$FC);
	my @Keys;
	my @Times;
	while (defined($arg) and $arg ne '') {
		my ($key,$type,$next) = $arg =~ m{^([^{},]+)(?:([{},])(.*))?$};
		Err "Parsing No Key in Remaining<$arg> from request<$oarg>." unless (defined $key);
		my $opener = (defined($type) && $type eq '{') ? 1 : 0;
		my $closer = (defined($type) && $type eq '}') ? 1 : 0;
		my $ref=$Refs[-1];
			if ($opener) {
				Err "Descending too far for Time arg. Key<$key> in request <$oarg>." if (scalar(@Keys) >= 2);
				Wrn "HERE Opener";
				push(@Keys,$key);
			} elsif ($closer) {
				Err "Closer after key<$key> without matching opener in request<$oarg>." unless (scalar(@Keys));
				Wrn "HERE Closure";
				if ($key =~ m{^([@~]?)([+-]?\d+)([a-zA-Z]*)(?:-(\@?)([+-]?\d+)([a-zA-Z]*))?$}) { # If we are dealing with a time range
					Wrn "Closure Matches";
					my $ttype = $Keys[0];
					my $range=ToSec(1 . $ttype)/2;
					my $start_relitive=($1) ? (($1 eq '@') ? 0 : 2) : 1 ;
					my ($start,$start_unit,$end_relitive,$end,$end_unit)=($2,$3//$ttype,( ($4)? 0 : 1),$5,$6//$ttype);
					my $start_offset;
					my $end_offset;
					my $time = time;
					my $start_time;
					my $end_time;
					Wrn "HERE";
					if ($end) {
						$start_offset=ToSec($start . ($start_unit//$ttype));
						$end_offset=ToSec($end . ($end_unit//$ttype));
						$start_time	= (($start_relitive>=1) ? $time : 0) + $start_offset;
						$end_time	= (($end_relitive==1) ? $time : 0) + $end_offset;
						foreach my $ktime (keys $FC->{$ttype}) {
							next unless(IsDigit($ktime));
							push(@Times,[$ttype,$ktime]) if (($time + $end_offset) >= $ktime && $ktime >= ($time - $start_offset));
						}
					} elsif ($start_relitive == 1) {
						$end_offset=ToSec(1 . $ttype)/2;
						$start_offset=ToSec($start . ($start_unit//$ttype)) -$end_offset;
						$start_time	= $time + $start_offset;
						$end_time	= $time + $end_offset;
						foreach my $ktime (keys $FC->{$ttype}) {
							next unless(IsDigit($ktime));
							push(@Times,[$ttype,$ktime]) if (($time + $end_offset) >= $ktime && $ktime >= ($time - $start_offset));
						}
					} elsif ($start_relitive == 2) {
						$start_offset=ToSec($start . ($start_unit//$ttype));
						$start_time	= $time + $start_offset;
						push(@Times,[$ttype,$start_time]);
					} else {
						$start_time=ToSec($start . ($start_unit//$ttype)) ;
						push(@Times,[$ttype,$start_offset]);
					}
				} else {
					Wrn "Closure NoMatch";
					push(@Times,[@Keys,$key]);
				}
				pop(@Keys);
			} else {
				Wrn "HERE NoOpenNoClose";
				if (scalar @Keys >= 1) {
					if ($key =~ m{^([+-]?\d+)([a-zA-Z]*)(?:-([+-]?\d+)([a-zA-Z]*))$}) { # If we are dealing with a time range
						my $ttype = $Keys[0];
						my $range=ToSec(1 . $ttype)/2;
						my ($start,$start_unit,$end,$end_unit)=($1,$2//$ttype,$3,$4//$ttype);
						my $start_offset;
						my $end_offset;
						if ($end) {
							$start_offset=ToSec($start . ($start_unit//$ttype));
							$end_offset=ToSec($end . ($end_unit//$ttype));
						} else {
							$end_offset=ToSec(1 . $ttype)/2;
							$start_offset=ToSec($start . ($start_unit//$ttype)) - $end_offset;
						}
						my $time = time;
						foreach my $ktime (keys $FC->{$ttype}) {
							next unless(IsDigit($ktime));
							push(@Times,[$ttype,$ktime]) if (($time + $end_offset) >= $ktime && $ktime >= ($time - $start_offset));
						}
					} else {
						my $nk = NestedHash(Hash=>$FC,Keys=>[@Keys,$key]);
						next unless ($nk->{Exists});
						Err $nk->{Error} if ($nk->{Error});
						push(@Times,[@Keys,$key]);
					}
				} else {
					foreach my $time (keys $FC->{$key}) {
						next unless(IsDigit($time));
						push(@Times, [$key,$time]);
					}
				}
			}
		$arg=$next;
	}
	return \@Times;
}
sub Time_Filtrate {
	my @Times=@{shift()};
	my @Keys=@{shift()};
	my $key=shift;
	if ($key =~ m{^([@~]?)([+-]?\d+)([a-zA-Z]*)(?:-(\@?)([+-]?\d+)([a-zA-Z]*))?$}) { # If we are dealing with a time range
		Wrn "Closure Matches";
		my $ttype = $Keys[0];
		my $range=ToSec(1 . $ttype)/2;
		my $start_relitive=($1) ? (($1 eq '@') ? 0 : 2) : 1 ;
		my ($start,$start_unit,$end_relitive,$end,$end_unit)=($2,$3//$ttype,( ($4)? 0 : 1),$5,$6//$ttype);
		my $start_offset;
		my $end_offset;
		my $time = time;
		my $start_time;
		my $end_time;
		Wrn "HERE";
		if ($end) {
			$start_offset=ToSec($start . ($start_unit//$ttype));
			$end_offset=ToSec($end . ($end_unit//$ttype));
			$start_time	= (($start_relitive>=1) ? $time : 0) + $start_offset;
			$end_time	= (($end_relitive==1) ? $time : 0) + $end_offset;
			foreach my $ktime (keys $FC->{$ttype}) {
				next unless(IsDigit($ktime));
				push(@Times,[$ttype,$ktime]) if (($time + $end_offset) >= $ktime && $ktime >= ($time - $start_offset));
			}
		} elsif ($start_relitive == 1) {
			$end_offset=ToSec(1 . $ttype)/2;
			$start_offset=ToSec($start . ($start_unit//$ttype)) -$end_offset;
			$start_time	= $time + $start_offset;
			$end_time	= $time + $end_offset;
			foreach my $ktime (keys $FC->{$ttype}) {
				next unless(IsDigit($ktime));
				push(@Times,[$ttype,$ktime]) if (($time + $end_offset) >= $ktime && $ktime >= ($time - $start_offset));
			}
		} elsif ($start_relitive == 2) {
			$start_offset=ToSec($start . ($start_unit//$ttype));
			$start_time	= $time + $start_offset;
			push(@Times,[$ttype,$start_time]);
		} else {
			$start_time=ToSec($start . ($start_unit//$ttype)) ;
			push(@Times,[$ttype,$start_offset]);
		}
	} else {
		Wrn "Closure NoMatch";
		push(@Times,[@Keys,$key]);
	}
}

sub ForecastFilter_Arg {
	my $oarg=$ARGV[0];
	my $arg=$oarg;
	my @Refs;
	push(@Refs,$FC);
	my @Keys;
	while (defined($arg) and $arg ne '') {
		my ($key,$type,$next) = $arg =~ m{^([^{},]+)(?:([{},])(.*))?$};
		my $opener = (defined($type) && $type eq '{') ? 1 : 0;
		my $closer = (defined($type) && $type eq '}') ? 1 : 0;
		my $ref=$Refs[-1];
			if ($opener) {
				#	push(@Refs,$ref->{$key});
				push(@Keys,$key);
			} elsif ($closer) {
				#Info $ref->{$key};
				#foreach my $time (@{$CONFIG->{Times}}) {
				my $nk = NestedHash(Hash=>$FC,Keys=>[@Keys,$key]);
				next unless ($nk->{Exists});
				Err $nk->{Error} if ($nk->{Error});
				Msg (CWrn(join('>', @Keys, $key)),' ', (Dumper $nk->{Value}));
				#pop(@Refs);
				pop(@Keys);
			} else {
				#print $ref->{$key};
				my $nk = NestedHash(Hash=>$FC,Keys=>[@Keys,$key]);
				next unless ($nk->{Exists});
				Err $nk->{Error} if ($nk->{Error});
				Msg (CWrn(join('>', @Keys, $key)),' ', (Dumper $nk->{Value}));
			}
		$arg=$next;
	}
}
sub PrintHelp {
say <<"HEREHELP"
-h for help
--link:				Lists Links to recs rather than Listing just the names
-ns --no-save		Doesn't save at the end. Useefull when Testing new changes to the script.

update-forecast		Updates the Forecast DB.
forecast [time <TimeRange>]* [type <WeatherWanted>]*
	TimeRange=day 1-2
HEREHELP
}
#############
# Generic }}}
#############
