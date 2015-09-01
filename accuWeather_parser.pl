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
$CONFIG->{Lifetime}{Minute}=ToSec('1m');
$CONFIG->{Lifetime}{Hourly}=ToSec('10m');
$CONFIG->{Lifetime}{Daily}=ToSec('1hr');
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
	Current=>$IFC,
	Minutes=>{minsec1=>$IFC,minsec2=>$IFC},
	Hours=>{HrSec1=>$IFC,HrSec2=>$IFC},
	Days=>{DaySec1=>$IFC,DaySec2=>$IFC},
};
}
$STORE=retrieve($STORE_FILE) if ( -e $STORE_FILE);
#StoreUpdate();
#die 'PAUSED';
my $INST={};

__Read_Args();
# NOTE Helper Vars. Should be replaced once structure is stable

store($STORE, $STORE_FILE);
#EnhancedRecs(keys $STORE->{UserList}{$User}{$Type}{Completed});
##################
# HELPER FUNCTIONS
##################
sub Build_Html_Tree {
	my $path = shift;
	my $query = shift//'';
	#$mech->get( $Site . $path);
	#$webkit->open( $Site . $path);
	#$webkit->wait_for_page_to_load(15000);
	my $page = join('/',$Site,$Location,$path,$LocationID ) . $query;
	my $content = get( $page ) or die("Unable to fetch page <" . $page . ">!"); # lwp
	#$lwp->wait_for_page_to_load(15000);
	#my $AnimeTree = HTML::TreeBuilder::XPath->new_from_content($mech->content);
	#my $content =  $webkit->view->get_dom_document->get_document_element->get_outer_html;
	my $AnimeTree = HTML::TreeBuilder::XPath->new_from_content($content);
	return $AnimeTree;
}
#########
# STORAGE
#########
my $STORE_CNT=0;

sub StoreInfo {
	my $Page	= shift;
	my $Tree	= shift || undef;
	my $WeFetch = (defined $Tree) ? 0 : 1;
	if ( IsOld($STORE->{Page}{$Page}{Info}{LastUpdate}) ) {
		$Tree //= Build_Html_Tree($Page);
		$STORE->{Page}{$Page}{Info} = PageInfo($Tree);
		$STORE->{Page}{$Page}{Info}{LastUpdate} = time;
		if ($STORE_CNT++ >= 14) { store($STORE, $STORE_FILE); $STORE_CNT= 0; }
		StorePageDetails($Page,$Tree) if ($WeFetch);
	}
	return $STORE->{Page}{$Page}{Info};
}
sub IsOld {
	my $LastUpdate=shift//0;
	my $LifeTime=shift//0;
	return 1 if	($LastUpdate + $LifeTime <= time );
	return 0;
}

#########
# Weather
#########
sub Parser() { # Parses Extended Forcast
	my $Root=Build_Html_Tree( 'daily-weather-forecast');
	#my $Root=Build_Html_Tree( $Location);
	my $ShortCast = $Root->findnodes('//div[@id="feed-tabs"]');
	my $FC = {
		Current=>,
		Minutes=>,
		Hours=>,
		Days=>,
	}
#	foreach my $day ();
	#say Dumper $Root;
	say Dumper $FC;
}

### TAB PARSERS

# Parse the daily tab
sub Get_Daily() {
	for my $i (1..45) {
		Daily_Parser($i)
	}
}
sub Daily_Parser() {
	my $day=shift//1;
	my $Root=Build_Html_Tree( 'daily-weather-forecast',"?day=$day" );
	my $FC = {}; # ForCast
	$FC->{Time}=DateParser($Root);
	$FC->{Range}=ToSec('24h');
	$FC->{LastUpdate}=time;
	foreach my $DayCast ( $Root->findnodes('//div[@id="detail-day-night"]/div') ) {
		$FC={%{$FC},%{ForecastInfo_Parser($DayCast)}};
		my $Cont = $DayCast->findnodes('.//div[@class="content"]')->[0];
			#TODO Desc
			my $Stats = $Cont->findnodes('./ul[@class="stats"]')->[0];
			$FC= { %{$FC}, %{Stats_Parser($Stats)} };
		say Dumper $FC;
	}
}
sub Current_Parser() {
	my $Root=Build_Html_Tree('current-weather');
	my $FC = {}; # ForCast
	$FC->{Time}=0;
	$FC->{Range}=0;
	$FC->{LastUpdate}=time;
	foreach my $DayCast ( $Root->findnodes('//div[@id="detail-now"]/div') ) {
		$FC={%{$FC},%{ForecastInfo_Parser($DayCast)}};
		my $Cont = $DayCast->findnodes('.//div[@class="more-info"]')->[0];
			#TODO Desc
			my $Stats = $Cont->findnodes('./ul[@class="stats"]')->[0];
			$FC= { %{$FC}, %{Stats_Parser($Stats)} };
		say Dumper $FC;
	}
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
	my $FC={};
	my @FCs;
	$FC->{Range}=ToSec('1h');
	$FC->{LastUpdate}=time;
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
		$hfc->{LastUpdate}=time;
		$FC->{$time}=$hfc;
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
	say Dumper $FC;
	return $FC;
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
	my $FC={};
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
		$mfc->{LastUpdate} = time;
		$FC->{$mfc->{Time}} = $mfc;
		$date+=ToSec('1m');
	}
	say Dumper $FC;
}
sub ForecastInfo_Parser() {
	my $DayCast=shift;
	my $FC={};
	my $Info = $DayCast->findnodes('.//div[@class="info"]')->[0];
	$FC->{Temp}		= $Info->findvalue('./span[@class="temp"]');
	$FC->{Condition}		= $Info->findvalue('./span[@class="cond"]');
	my $RealFeel	= $Info->findnodes_as_string('./span[@class="realfeel"]');
	($FC->{RealFeel}{Temp}) = $1 if $RealFeel =~ m{RealFeel.?\s+(\d+)};
	($FC->{RealFeel}{Percipitation}) = $1 if $RealFeel =~ m{Precipitation.?\s+(\d+)%};
	return $FC;
}
sub Advisories_Parser() { # TODO
	my $Root=Build_Html_Tree( $Location . '/weather-warnings/' . $LocationID );
}
sub Stats_Parser() {
	my $Stats=shift;
	my $FC={};
	foreach my $stat ($Stats->findnodes('./li')) {
		my $val=$stat->findvalue('./strong');
		my ($name) = $stat->findvalue('./text()') =~ m{^([^:]+):};
		OverwriteTable($FC,NamedParser({name=>$name,val=>$val,nval=>$val}));
	}
	return $FC;
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


##################
# MAL USER LIST PARSER {{{
##################

sub GetUserList {
	my $args = { @_ };
	my $User = $args->{User};
	my $Type = $args->{Type};
	my $typepath='';
	if ($Type eq 'Anime') {
		$typepath = '/animelist/';
	} elsif ($Type eq 'Manga') {
		$typepath = '/mangalist/';
	} else {
		croak "WhateverWeAre was given an unknown Type '$Type'.";
	}
	return $STORE->{UserList}{$User}{$Type} if (($CONFIG->{Options}{UpdateUserList}//1) == 0);
	my $UserTree = Build_Html_Tree( $typepath . $User);
	my $CTable='';
	my $Layout={};
	my $XPath_UserList_Pre = '/html/body/div[@id="list_surround"]';
	foreach my $Table ($UserTree->findnodes('/html/body/div[@id="list_surround"]/table')) {
		$CTable = 'Current'		if ($Table->matches($XPath_UserList_Pre . '/table[@class="header_cw"]'));
		$CTable = 'Completed'	if ($Table->matches($XPath_UserList_Pre . '/table[@class="header_completed"]'));
		$CTable = 'Planned'		if ($Table->matches($XPath_UserList_Pre . '/table[@class="header_ptw"]'));
		next unless ($CTable =~ m/Current|Completed|Planned/);
		if ($Table->exists('./tbody/tr/td[@class="table_header"]')) {
			$Layout = ParseLayout($Table);
			next;
		} 
		if ($Table->exists('./tbody/tr/td[@class="catagory_totals"]')) {
			$CTable='';
			$Layout={};
			next;
		}
		next unless (scalar(keys $Layout) >= 1 );
		next unless (exists $Layout->{Link});
		StoreUserList(	User => $User,
						Status => $CTable,
						UserListItem => ReadItem(Item=>$Table,Layout=>$Layout),
		) if ($Table->exists('./tbody/tr/td[@class="td1" or @class="td2"]'));
	}
	return $STORE->{UserList}{$User}{$Type};
}
sub ReadItem {
	my $args={@_};
	my $Item=$args->{Item};
	my $Layout=$args->{Layout};
#	my $Name = $Item->findvalue('./tbody/tr/td[2]/a/span');
#	my $Link = $Item->findvalue('./tbody/tr/td[2]/a/@href');
#	my $Score = $Item->findvalue('./tbody/tr/td[3]');
#	my $Type = $Item->findvalue('./tbody/tr/td[4]');
#	my $Progress = $Item->findvalue('./tbody/tr/td[5]');
#	my @Tags = $Item->findnodes_as_strings('./tbody/tr/td[6]/span/a');
	my $Tree;
	foreach my $key (keys $Layout) {
		my $xpath = $Layout->{$key};
		given ($key) {
			when ('Name') {
				$Tree->{$key} = $Item->findvalue($xpath . '/a/span');
			}
			when ('Link') {
				$Tree->{$key} = $Item->findvalue($xpath . '/a/@href');
			}
			when ('Score') {
				$Tree->{$key} = $Item->findvalue($xpath);
			}
			when ('Type') {
				$Tree->{$key} = $Item->findvalue($xpath);
			}
			when (m/^Progress|Chapters|Volumes$/) {
				$Tree->{$key} = $Item->findvalue($xpath);
			}
			when ('Tags') {
				$Tree->{$key} = [$Item->findnodes_as_strings($xpath . '/span/a')];
			}
		}
	}
	$Tree->{Score}=0 unless ($Tree->{Score} =~ /^\d+(\.\d*)?|\d*(\.\d+)$/); #FIXME
#	$Tree->{Score}= $Tree->{Score} - 5.5; #FIXME
	# TODO Expanded details from More hidden/javascript block
	return($Tree);
	#return({
	#	Name		=> $Name,
	#	Link		=> $Link,
	#	Score		=> $Score,
	#	Type		=> $Type,
	#	Progress	=> $Progress,
	#	Tags		=> \@Tags,
	#});
}
##############
# ANIME Parser
##############
sub AniDets {
	my $AniTree = shift;
#	my @InfoTree = $AniTree->findnodes('/html/body/div[@id="myanimelist"]/div[@id="contentWrapper"]/div[@id="content"]/table/tbody/tr/td[2]/div[2]/table/tbody/tr[1]/');
	my @UTree = $AniTree->findnodes('/html/body/div[@id="myanimelist"]/div[@id="contentWrapper"]/div[@id="content"]/table/tbody/tr/td[2]/div[2]/table/tbody/tr[2]/td/* | /html/body/div[@id="myanimelist"]/div[@id="contentWrapper"]/div[@id="content"]/table/tbody/tr/td[2]/div[2]/table/tbody/tr[2]/td/text()');
	#say $AniTree->findnodes_as_strings('/html/body/div[@id="myanimelist"]/div[@id="contentWrapper"]/div[@id="content"]/table/tbody/tr/td[2]/div[2]/table/tbody/tr[2]/td/text()[3]');
#	say $AniTree->findnodes('/html/body/div[@id="myanimelist"]/div[@id="contentWrapper"]')->[0]->dump;
	#say $AniTree->findnodes('/html/body/div[@id="myanimelist"]/div[@id="contentWrapper"]/div[@id="content"]/table/tbody/tr/td[2]/div[2]/table/tbody/tr[2]')->[0]->dump;
	my $Dets={};
	my $MODE='';
	my $Item='';
	foreach my $cont (@UTree) {
		if (ref($cont) eq 'HTML::Element') {
			if ($cont->tag eq 'h2') {
				if ($cont->as_text =~ m/^ *Related Anime *$/) {
					$MODE='Related';
				} else {
					$MODE='';
				}
			}
		} 
		next unless ($MODE =~ /Related/);
		if (ref($cont) eq 'HTML::TreeBuilder::XPath::TextNode') {
			my $text = $cont->getValue;
			next if $text =~ /^\h*,\h*$/;
			croak "Expecting a : terminated string or comma, but got <$text>" unless $text =~ /\:\h*$/;
			$text =~ s/\:\h*$//;
			$Item=$text;
		} elsif (ref($cont) eq 'HTML::Element') {
			next unless ($Item =~ /./);
			if ($cont->tag eq 'a') {
				push(@{$Dets->{Relations}{$Item}}, $cont->attr('href')) if ($cont->attr('href') =~ m{^/anime/+[^/]+}); # ensure it links somewhere. Best to find a way to check for 404/500
			}
		}
	}
	return $Dets;
}
#
# MAL }}}
#

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
        } elsif ($format =~ m{^ m(in(ut)?s?)? $}ix) {
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
			when (/test-day/i) {
				Daily_Parser();
				shift @ARGV;
			}
			when (/test-now/i) {
				Current_Parser();
				shift @ARGV;
			}
			when (/test-hour/i) {
				#Hourly_Parser();
				Hourly_Parser();
				shift @ARGV;
			}
			when (/test-min/i) {
				#Hourly_Parser();
				Minut_Parser();
				shift @ARGV;
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

sub PrintHelp {
say <<"HEREHELP"
-h for help
-er --enhanced-recs
-err -enhanced-recs-relational
--link:				Lists Links to recs rather than Listing just the names
--user
-g --genre:			Filters Anime/Manga to Genre.
-kl --keep-list:	Keeps Anime/Manga from the User's list in the recommandations list. 
-ns --no-save		Doesn't save at the end. Useefull when Testing new changes to the script.
-nul --no-update-list		Doesn't update user list.
HEREHELP
}
#############
# Generic }}}
#############
