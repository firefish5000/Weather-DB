#!/usr/bin/perl

package Accuweather::Parser;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '1.00';
require Exporter;
use AutoLoader qw(AUTOLOAD);


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

sub new {
	my $class = shift;
    my $arg = shift;
    my $self = {
		StoreFile => q{/home/beck/tmp/AccuWeather.db},
		Site => 'http://www.accuweather.com',
		Lifetime	=> {
			Current => ToSec('1m'),
			Today	=> ToSec('1hr'), # Daily forecast for the current day.
			Minutes => ToSec('1m'),
			Hours	=> ToSec('10m'),
			Days	=> ToSec('5h'),
			Advisories => ToSec('1m'),
		},
		Locations => {},
	};
    bless($self, $class);
    return $self;
}

######
# MAIN
######
sub NO_OP {
	return;
	my $IFC;
my $LFC_Examp = { # LocaleTime Forecast Example
	# TODO Default Values?
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
my $FC = {
	Locations=>{
		LastUpdated=>0, # Should only change when a comprehensive, full update occured on its children.
		SOMEPLACE1=>{
			LastUpdated=>0, # Should only change when a comprehensive, full update occured on its children.
			Days=> {
				LastUpdated=>0,
				
			}
		},
		SOMEPLACE2=>{
			LastUpdated=>0,
		},
	}
	Time=>
}
}
sub Load() {
	my $FC=shift;
	$FC->{Locations}=retrieve($FC->{StoreFile}) if ( -e $FC->{StoreFile});
	return $FC;
}
sub Save() {
	my $FC=shift;
	store($FC->{StoreFile},$FC->{Locations});
}
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
	my $FC = shift;
	my $path = shift;
	my $query = shift//'';
	my $page = join('/',$Site,$Location,$path,$LocationID) . $query;
	my $content = get( $page ) or Carp("Unable to fetch page <" . $page . ">!"); # lwp
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
		#Info "It's Old $LastUpdate + $LifeTime <= " . time;
		return 1;
	}
	#Info "It's Good $LastUpdate + $LifeTime > " . time;
	return 0;
}

#########
# Weather
#########
sub GetForecast() { # Parses Extended Forcast
	my $FC = shift;
	my $Locations = shift; # TODO/FIXME
	# FIXME Need to check parse didn't fail on each, and return error and keep old values if it did.
	my $tfc = {
		LastUpdated=>time,
		Current=>{0=>$FC->GetCurrent(Location=>$location,)},
		Minutes=>$FC->GetMinutes(Location=>$location,),
		Hours=>$FC->GetHours(Location=>$location,),
		Days=>$FC->GetDays(Location=>$location,),
	};
	$FC->{Locations}{$Location}=$tfc;
	#Info Dumper $FC;
	store($FC, $STORE_FILE); # FIXME
	return $FC;
}

### TAB PARSERS

# Parse the daily tab
sub GetDays() {
	my $FC = shift;
	my $Location = shift; # TODO/FIXME
	my $args=shift;
	my $tfc = $FC->{$Location}{Days}//{}; # FIXME
	return $tfc unless IsOld($tfc->{LastUpdated},$FC->{Lifetime}{Days});
	$tfc->{Range}=ToSec('24h');
	$tfc->{LastUpdated}=time;
	for my $i (1..45) {
		my $day = Daily_Parser($Location,%$args,day=>$i);
		$tfc->{$day->{Time}}=$day;
	}
	$FC->{Locations}{$Location}=$tfc;
	return $tfc;
}
sub GetHours() {
	my $FC = shift;
	my $Location = shift; # TODO/FIXME
	my $tfc = $FC->{Locations}{$Location}{Hours}//{};
	return $tfc unless IsOld($tfc->{LastUpdated},$FC->{Lifetime}{Hours});
	$tfc = Hourly_Parser($Location);
	return $tfc;
}
sub GetMinutes() {
	my $Location = shift; # TODO/FIXME
	my $tfc = $FC->{Locations}{$Location}{Minutes}//{};
	return $tfc unless IsOld($tfc->{LastUpdated},$FC->{Lifetime}{Minutes});
	$tfc = Minut_Parser();
	return $tfc;
}
sub GetCurrent() {
	my $Location = shift; # TODO/FIXME
	my $tfc = $FC->{Locations}{$Location}{Current}//{};
	return $tfc unless IsOld($tfc->{LastUpdated},$FC->{Lifetime}{Current});
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
	my $orig=shift//{};
	my $new=shift//{};
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
		# FIXME Check time
		my $mfc = {};
		if ($first) {
			#my $hrmin = $Min->findvalue('./span[@class="time"]');
			my $hrmin = $Min->findvalue('//div[@id="content"]//div[@class="panel minute-tabs"]//ul[@class="thefeed-tab-buttons"]/li/a[@class="feed current"]');
			$date = qx{date --date='$hrmin' +%s}; # FIXME remove all qx/syscalls
			chomp($date);
			$first=0;
		}
		$mfc->{Time} = $date;
		# FIXME NOTE TODO Possible Risk of Jumping Minutes. Add checks and a better converter.
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
	$date =~ s{\s}{}g;
	chomp($date);
	# return DateTime->new(month => $month, day => $day, time_zone => "America/Chicago")->epoche();
	return $date;
}
sub NamedParser() {
	my $args=shift;
	my $name=$args->{name};
	my $val=$args->{val}//$args->{nval}//undef;
	my $nval=$args->{nval}//$val;
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
#$CONFIG->{Lifetime}{Current}=ToSec('1d');
#$CONFIG->{Lifetime}{Today}=ToSec('1d'); # Daily forecast for the current day.
#$CONFIG->{Lifetime}{Minutes}=ToSec('1d');
#$CONFIG->{Lifetime}{Hours}=ToSec('1d');
#$CONFIG->{Lifetime}{Days}=ToSec('1d');

#NOTE These config defaults will be removed, latter defaults will be specified vi
$CONFIG->{Lifetime}{Current}=ToSec('1m');
$CONFIG->{Lifetime}{Today}=ToSec('1hr'); # Daily forecast for the current day.
$CONFIG->{Lifetime}{Minutes}=ToSec('1m');
$CONFIG->{Lifetime}{Hours}=ToSec('10m');
$CONFIG->{Lifetime}{Days}=ToSec('5h');
$CONFIG->{Lifetime}{Advisories}=ToSec('1m');
#$CONFIG->{Lifetime}{Days}=ToSec('1hr'); # TODO Dynamic ranges. Eg, Lifetime>Days>1=1hr, Liftime>Days>2-7=5hr, Lifetime>Days>8-45=2days
$CONFIG->{Locations}{NAME}{Path}="/en/us/lakeland-tn/38002/";
$CONFIG->{Locations}{NAME}{ID}="2201989"; # Daily forecast for the current day.
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
my $LFC_Examp = { # LocaleTime Forecast Example
	# TODO Default Values?
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
my $FC = {
	Locations=>{
		LastUpdated=>0, # Should only change when a comprehensive, full update occured on its children.
		SOMEPLACE1=>{
			LastUpdated=>0, # Should only change when a comprehensive, full update occured on its children.
			Days=> {
				LastUpdated=>0,
				
			}
		},
		SOMEPLACE2=>{
			LastUpdated=>0,
		},
	}
	Time=>
}
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
	my $args={@_};
	my $path = $args->{path};
	my $query = $args->{query};
	my $Location = $args->{Location};
	my $LocationID = $args->{LocationID};
	my $page = join('/',$Site,$Location,$path,$LocationID) . $query;
	my $content = get( $page ) or Carp("Unable to fetch page <" . $page . ">!"); # lwp
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
		#Info "It's Old $LastUpdate + $LifeTime <= " . time;
		return 1;
	}
	#Info "It's Good $LastUpdate + $LifeTime > " . time;
	return 0;
}

#########
# Weather
#########
sub GetForecast { # Parses Extended Forcast
	# FIXME Need to check parse didn't fail on each, and return error and keep old values if it did.
	my $tfc = {
		
		LastUpdated=>time,
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
	my $FC = shift;
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
	my $orig=shift//{};
	my $new=shift//{};
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
	my $Root=Build_Html_Tree(location=>,path=>'minute-weather-forecast');
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
		# FIXME Check time
		my $mfc = {};
		if ($first) {
			#my $hrmin = $Min->findvalue('./span[@class="time"]');
			my $hrmin = $Min->findvalue('//div[@id="content"]//div[@class="panel minute-tabs"]//ul[@class="thefeed-tab-buttons"]/li/a[@class="feed current"]');
			$date = qx{date --date='$hrmin' +%s}; # FIXME remove all qx/syscalls
			chomp($date);
			$first=0;
		}
		$mfc->{Time} = $date;
		# FIXME NOTE TODO Possible Risk of Jumping Minutes. Add checks and a better converter.
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
	$date =~ s{\s}{}g;
	chomp($date);
	# return DateTime->new(month => $month, day => $day, time_zone => "America/Chicago")->epoche();
	return $date;
}
sub NamedParser() {
	my $args=shift;
	my $name=$args->{name};
	my $val=$args->{val}//$args->{nval}//undef;
	my $nval=$args->{nval}//$val;
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
