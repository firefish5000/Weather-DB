#!/usr/bin/perl

package WeatherDB::AccuWeather;

our @ISA = qw(Exporter);
#our %EXPORT_TAGS = ( 'all' => [ qw() ] );
#our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
#our @EXPORT = qw();
our $VERSION = '1.00';
#require Exporter;
#use AutoLoader qw(AUTOLOAD);


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
		Alias => {
			Lakeland => {Path=>q{en/us/lakeland-tn/38002}, ID=> 2201989},
		},
	};
    bless($self, $class);
    return $self;
}

######
# MAIN
######
sub Load() {
	my $FC=shift;
	$FC->{Locations}=retrieve($FC->{StoreFile}) if ( -e $FC->{StoreFile});
	return $FC;
}
sub Save() {
	my $FC=shift;
	store($FC->{Locations},$FC->{StoreFile});
}
##################
# HELPER FUNCTIONS
##################
sub ToSec {
    my $time = shift;
    my $Seconds = 0;
	return 0 unless defined($time);
	return $time if $time =~ m{^( '-'? \d+ | inf )$}x;
	#Croak q{Time Uninitialized} unless defined($time);
	#while ($time =~ m{ (\d+) \s* ([^0-9 \t]+)?  }gx) {
	while ($time =~ m{ (\d+(?:\.\d*)?|\d*\.\d+) \s* ([^0-9 \t]+)?  }gx) {
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
sub Location {
	my $FC = shift;
	my $Loc = shift or confess qq{No Loc Set};
	if (ref($Loc) ne q{HASH}) {
		confess "Not a known location alias <$Loc>" unless exists $FC->{Alias}{$Loc}{ID};
		$Loc=$FC->{Locations}{$FC->{Alias}{$Loc}{ID}}//=$FC->{Alias}{$Loc} or die "Not a known location alias <$Loc>";
	}
	my $tfc =  $FC->{Locations}{$Loc->{ID}} ||= {};
	return $tfc;
}
sub Build_Html_Tree {
	my $FC = shift;
	my $Loc = $FC->Location(shift);
	my $path = shift;
	my $query = shift//'';
	my $page = join('/',$FC->{Site},$Loc->{Path},$path,$Loc->{ID}) . $query;
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
	$FC->Load();
	my $Loc = $FC->Location(shift); # TODO/FIXME
	my $tfc = $Loc;
	# FIXME Need to check parse didn't fail on each, and return error and keep old values if it did.
	$tfc->{LastUpdated}	= time;
	$tfc->{Current}		= {0=>$FC->GetCurrent($Loc)},
	$tfc->{Minutes}		= $FC->GetMinutes($Loc),
	$tfc->{Hours}		= $FC->GetHours($Loc),
	$tfc->{Days}		= $FC->GetDays($Loc),
	Wrn Dumper $tfc;
	$FC->Save(); # FIXME
	return $FC;
}

### TAB PARSERS

# Parse the daily tab
sub GetDays() {
	my $FC = shift;
	my $Loc = $FC->Location(shift); # TODO/FIXME
	my $args=shift;
	my $tfc = $Loc->{Days}//={}; # FIXME
	return $tfc unless IsOld($tfc->{LastUpdated},$FC->{Lifetime}{Days});
	$tfc->{Range}=ToSec('24h');
	$tfc->{LastUpdated}=time;
	for my $i (1..45) {
		# my $day = Daily_Parser($Location,%$args,day=>$i); # Downt know what to do with
		my $day = $FC->Daily_Parser($Loc,%$args,day=>$i);
		$tfc->{$day->{Time}}=$day;
	}
	return $tfc;
}
sub GetHours() {
	my $FC = shift;
	my $Location=shift;
	my $tfc = $FC->Location($Location)->{Hours} //= {};
	return $tfc unless IsOld($tfc->{LastUpdated},$FC->{Lifetime}{Hours});
	$tfc = $FC->Hourly_Parser($Location);
	return $tfc;
}
sub GetMinutes() {
	my $FC = shift;
	my $Loc = $FC->Location(shift); # TODO/FIXME
	my $tfc = $Loc->{Minutes}//={};
	return $tfc unless IsOld($tfc->{LastUpdated},$FC->{Lifetime}{Minutes});
	$tfc = $FC->Minut_Parser($Loc);
	return $tfc;
}
sub GetCurrent() {
	my $FC = shift;
	my $Loc = $FC->Location(shift); # TODO/FIXME
	my $tfc = $Loc->{Current}//{};
	return $tfc unless IsOld($tfc->{LastUpdated},$FC->{Lifetime}{Current});
	$tfc = $FC->Current_Parser($Loc);
	return $tfc;
}
sub Daily_Parser() {
	my $FC = shift;
	my $Loc = $FC->Location(shift); # TODO/FIXME
	my $args={@_};
	my $day=$args->{day}//1;
	my $Root=$FC->Build_Html_Tree( $Loc, 'daily-weather-forecast',"?day=$day" );
	my $tfc = {}; # ForCast
	$tfc->{Time}=DateParser($Root);
	$tfc->{Range}=ToSec('24h');
	$tfc->{LastUpdated}=time;
	foreach my $DayCast ( $Root->findnodes('//div[@id="detail-day-night"]/div') ) {
		my $class = $DayCast->findvalue('./@class');
		my ($MorningOrNight) = $class =~ m{^(day|night)$} or Croak qq{Daily parser got class <$class>, which does not match the known classes of day/night};
		$MorningOrNight = ($MorningOrNight eq q{day}) ? q{Morning} : q{Night};
		# Some Daily_tab specific parsers
		my $Cont = $DayCast->findnodes('.//div[@class="content"]')->[0];
		$tfc->{$MorningOrNight}{Condition} = $Cont->findvalue('./div[@class="desc"]/p') or Carp q{Could not find Condition};
		# Utilize genaric Parsers
		$tfc->{$MorningOrNight} = {%$tfc,%{ForecastInfo_Parser($DayCast)} };
		#TODO Desc
		my $Stats = $Cont->findnodes('./ul[@class="stats"]')->[0];
		$tfc->{$MorningOrNight} = {%$tfc, %{Stats_Parser($Stats)} };
		# Store High/Low
		$tfc->{Temp}{High} = $tfc->{$MorningOrNight}{Temp} if (exists $tfc->{$MorningOrNight}{Temp} && $tfc->{Temp}{High} < $tfc->{$MorningOrNight}{Temp});
		$tfc->{Temp}{Low} = $tfc->{$MorningOrNight}{Temp} if (exists $tfc->{$MorningOrNight}{Temp}{Avg} && $tfc->{Temp}{Low} > $tfc->{$MorningOrNight}{Temp}{Avg});
	}
	return $tfc;
}
sub Current_Parser() {
	my $FC = shift;
	my $Loc = $FC->Location(shift); # TODO/FIXME
	my $Root=$FC->Build_Html_Tree($Loc, 'current-weather');
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
	my $FC = shift;
	my $Loc = $FC->Location(shift); # TODO/FIXME
	my $Root=$FC->Build_Html_Tree($Loc, 'hourly-weather-forecast' );
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
		Wrn "Class<$class> Name<$name>";
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
	my $FC = shift;
	my $Loc = $FC->Location(shift); # TODO/FIXME
	my $Root=$FC->Build_Html_Tree($Loc, 'minute-weather-forecast' );
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
	my $FC = shift;
	my $Loc = $FC->Location(shift); # TODO/FIXME
	my $Root=$FC->Build_Html_Tree( $Loc->{Path} . '/weather-warnings/' . $Loc->{ID} );
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
		when (/^Temp/) { $lFC->{Weather}{Temp}{Avg}=$val; }
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
1;
