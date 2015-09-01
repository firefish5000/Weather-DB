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
$STORE=retrieve($STORE_FILE) if ( -e $STORE_FILE);
#StoreUpdate();
#die 'PAUSED';
my $INST={};

__Read_Args();
# NOTE Helper Vars. Should be replaced once structure is stable
my @UL_Statuses = qw{Current Completed Planned Stalled Dropped};
foreach my $User (@{$CONFIG->{Traking}{UserList}}) {
	my $Type='Anime';
	GetUserLists($User);
	#GetUserList(User=>$User,Type=>'Anime');
	foreach my $Page (keys %{$STORE->{UserList}{$User}{$Type}{Completed}}) {
		StoreAnime($Page);
		GenRelationsTree($Page);
	}
}
store($STORE, $STORE_FILE);
#EnhancedRecs(keys $STORE->{UserList}{$User}{$Type}{Completed});
##################
# HELPER FUNCTIONS
##################
sub Build_Html_Tree {
	my $path = shift;
	#$mech->get( $Site . $path);
	#$webkit->open( $Site . $path);
	#$webkit->wait_for_page_to_load(15000);
	my $content = get( $Site . $path) or die("Unable to fetch page '" . $Site . $path . "'!"); # lwp
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
	my $LastUpdate=shift;
	return 1 if	((($LastUpdate//0) + $CONFIG->{Options}{LifeTime} + int(rand($CONFIG->{Options}{LifeDevi})) ) <= time );
	return 0;
}

#########
# Weather
#########
sub Extended_Parser() { # Parses Extended Forcast
	my $Root=Build_Html_Tree( '/en/us/lakeland-tn/38002/daily-weather-forecast/2201989');
	#my $Root=Build_Html_Tree( $Location);
	my $ShortCast = $Root->findnodes('//div[@id="feed-tabs"]');
#	foreach my $day ();
	#say Dumper $Root;
	say Dumper $ShortCast;

	...
}

### TAB PARSERS

# Parse the daily tab
sub Extended_Daily_Parser() {
	my $Root=Build_Html_Tree( $Location . '/daily-weather-forecast/' . $LocationID );
	my $FC = {}; # ForCast
	foreach my $DayCast ( $Root->findnodes('//div[@id="detail-day-night"]/div') ) {
		my $Info = $DayCast->findnodes('.//div[@class="info"]')->[0];
			$FC->{Temp}		= $Info->findvalue('./span[@class="temp"]');
			my $RealFeel = $Info->findnodes_as_string('./span[@class="realfeel"]');
			($FC->{RealFeel}{Temp}) = $RealFeel =~ m{RealFeel.?\s+(\d+)\x{b0}};
			($FC->{RealFeel}{Percipitation}) = $RealFeel =~ m{Precipitation.?\s+(\d+)%};
			say Dumper $RealFeel;
		my $Cont = $DayCast->findnodes('.//div[@class="content"]')->[0];
			#TODO Desc
			my $Stats = $Cont->findnodes('./ul[@class="stats"]')->[0];
			$FC= { %{$FC}, %{Stats_Parser($Stats)} };
		say Dumper $FC;
	}
}
sub Extended_Now_Parser() {
	my $Root=Build_Html_Tree( $Location . '/daily-weather-forecast/' . $LocationID );
	my $FC = {}; # ForCast
	foreach my $DayCast ( $Root->findnodes('//div[@id="detail-day-night"]/div') ) {
		my $Info = $DayCast->findnodes('.//div[@class="info"]')->[0];
			$FC->{Temp}		= $Info->findvalue('./span[@class="temp"]');
			my $RealFeel = $Info->findnodes_as_string('./span[@class="realfeel"]');
			($FC->{RealFeel}{Temp}) = $RealFeel =~ m{RealFeel.?\s+(\d+)\x{b0}};
			($FC->{RealFeel}{Percipitation}) = $RealFeel =~ m{Precipitation.?\s+(\d+)%};
			say Dumper $RealFeel;
		my $Cont = $DayCast->findnodes('.//div[@class="content"]')->[0];
			#TODO Desc
			my $Stats = $Cont->findnodes('./ul[@class="stats"]')->[0];
			$FC= { %{$FC}, %{Stats_Parser($Stats)} };
		say Dumper $FC;
	}
}
# Parses Day/Night Subsection
sub Stats_Parser() {
	my $Stats=shift;
	my $FC={};
	foreach my $stat ($Stats->findnodes('./li')) {
		my $val=$stat->findvalue('./strong');
		my ($name) = $stat->findvalue('./text()') =~ m{^([^:]+):};
		given ($name) {
			when ('Max UV Index') { $FC->{MaxUV}=$val; }
			when ('Thunderstorms') { $FC->{Thunder}{Likelyhood}=$val; }
			when ('Precipitation') { $FC->{Percipitation}{Inches}=$val; }
			when ('Rain') { $FC->{Rain}{Inches}=$val; }
			when ('Snow') { $FC->{Snow}{Inches}=$val; }
			when ('Ice') { $FC->{Ice}{Inches}=$val; }
			when ('Hours of Precipitation') { $FC->{Percipitation}{Hours}=$val; }
			when ('Hours of Rain') { $FC->{Rain}{Hours}=$val; }
			when ('Humidity') { $FC->{Rain}{Hours}=$val; }
			when ('Pressure') { $FC->{Pressure}=$val; }
			when ('UV Index') { $FC->{UV_Index}{Current}=$val; }
			when ('Cloud Cover') { $FC->{CloudCoverage}=$val; }
			when ('Ceiling') { $FC->{Ceiling}=$val; } # Where clouds start?
			when ('Dew Point') { $FC->{Dew}{Point}=$val; }
			when ('Visibility') { $FC->{Visibility}=$val; }
			#when ('') { $FC->{}=$val; }
			default {
				Warn qq{Unhandled Name<$name> Value<$val>.};
			}
		}
	}
	return $FC;
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
			when (/test/i) {
				Extended_Daily_Parser();
				shift @ARGV;
				#Extended_Parser();
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
