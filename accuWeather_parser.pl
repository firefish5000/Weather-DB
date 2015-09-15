#!/usr/bin/perl
use utf8;
binmode(STDOUT, ":utf8");
use LWP::Simple;
use WeatherDB::AccuWeather;

#use WWW::Mechanize::Firefox;
#use WWW::WebKit;
#my $mech = WWW::Mechanize::Firefox->new();
#my $webkit = WWW::WebKit->new();
#$webkit->init;
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

my $FC = WeatherDB::AccuWeather->new();
$FC->GetForecast('Lakeland')
__END__
#__Read_Args();

store($FC, $STORE_FILE);

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
# TODO: Should we add month/year? what do we do for leap days and month size? Perhaps a way to do this only for @exact?
#        if ($format =~ m{^ y((ea)?rs?)? $}ix) {
#           $Seconds+=$sec*60*60*24;
#		} elsif ($format =~ m{^ mon(th)?s? $}ix) {

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
				$FC->GetDays();
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
	my $Times;
	my $Locations;
	my $Types;
	while (@ARGV) {
		given ($ARGV[0]) {
			when (/^time$/i) {
				shift @ARGV;
				$Times=Time_Arg($Times);
				shift @ARGV;
			}
			when (/^type$/i) {
				shift @ARGV;
				$Types=Type_Arg($Types);
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
	my @Keys;
	if (defined($Locations)) {
	} else {
		$Locations=[keys $FC->{Locations}];
	}
	foreach my $location (@{$Locations}) {
		if (defined($Times)) {
			foreach()
		} else {
			my $someplace = NestedHash(Hash=>$FC,Keys=>$location);
			next unless ($someplace->{Exists});
			next unless (ref($someplace->{Value}) eq 'HASH');
			foreach my $timeunit (keys $someplace->{Value}) {
				next unless ($timeunit);
				my $timeunit = NestedHash(Hash=>$FC,Keys=>$location);
				next unless(ref($someplace->{Value}{$timeunit}) eq 'HASH');
				next unless(ref($someplace->{Value}{$timeunit}));
				$Times=[$timeunit]
			}
		}
			my $someplace = NestedHash(Hash=>$FC,Keys=>$location)->{Value});
			foreach my $sometime (keys $sometime) ) {
				$sometime->{}
			}
		}
		foreach my $time (defined($Times) ? @{$Times} : keys NestedHash(Hash=>$FC,Keys=>[@$location]) ) {
			next unless(IsDigit($time));
			next unless (NestedHash(Hash=>$FC,Keys=>[@$location,@$time])->{Exists});
			foreach my $type (defined($Types) ? @{$Types} : keys $FC->{$location}{$time}) {
				next unless (NestedHash(Hash=>$FC,Keys=>[@$location,@$time,@$type])->{Exists});
				my $nestkeys=[@$location,@$time,@$type];
				my $nk = NestedHash(Hash=>$FC,Keys=>$nestkeys);
				next unless ($nk->{Exists});
				Err $nk->{Error} if ($nk->{Error});
				Msg (CWrn(join('>', @$nestkeys)),' ', (Dumper $nk->{Value}));
			}
		}
	}
}
sub Type_Arg {
	my $oarg=$ARGV[0];
	my $arg=$oarg;
	my $Types=shift||[];
	my @Keys;
	while (defined($arg) and $arg ne '') {
		my ($key,$type,$next) = $arg =~ m{^([^{},]+)(?:([{},])(.*))?$};
		my $opener = (defined($type) && $type eq '{') ? 1 : 0;
		my $closer = (defined($type) && $type eq '}') ? 1 : 0;
		my $ref=$Refs[-1];
		if ($opener) {
			push(@Keys,$key);
		} elsif ($closer) {
			Err "Closer after key<$key> without matching opener in request<$oarg>." unless (scalar(@Keys));
			push(@$Types,[@Keys,$key]);
			pop(@Keys);
		} else {
			push(@$Types,[@Keys,$key]);
		}
		$arg=$next;
	}
	return $Types
}
sub Time_Arg {
	my $oarg=$ARGV[0];
	my $arg=$oarg;
	my @Keys;
	my $Times=shift||{};
	while (defined($arg) and $arg ne '') {
		my ($key,$type,$next) = $arg =~ m{^([^{},]+)(?:(\{|\}*\,?)(.*))?$};
		Err "Parsing No Key in Remaining<$arg> from request<$oarg>." unless (defined $key);
		my $opener = (defined($type) && $type eq '{') ? 1 : 0;
		my $closer = () = $type =~ /\}/g;
		my $ref=$Refs[-1];
			if ($opener) {
				Err "Descending too far for Time arg. Key<$key> in request <$oarg>." if (scalar(@Keys) >= 2);
				push(@Keys,$key);
			} elsif ($closer) {
				Err "Closer after key<$key> without matching opener in request<$oarg>." unless (scalar(@Keys));
				Msg "Closer Using key<$key> with Rem<$arg> in request<$oarg>.";
				Time_Filtrate($Times,\@Keys,\$key);
				pop(@Keys) for (1 .. $closer);
			} else {
				if (scalar @Keys >= 1) {
					Time_Filtrate($Times,\@Keys,\$key);
				} else {
					foreach my $time (keys $FC->{$key}) {
						next unless(IsDigit($time));
						push(@$Times, [$key,$time]);
					}
				}
			}
		$arg=$next;
	}
	#Info Dumper @Times;
	return $Times;
}
sub Time_Filtrate {
	my $Times=shift();
	my @Keys=@{shift()};
	my $key=${shift()};
	my $digit = qr{(?:(?:\d+(?:\.\d*)?)|(?:\d*\.\d+))};
	if ($key =~ m{^([@~]?)([+-]?$digit)([a-zA-Z]*)(?:-(\@?)([+-]?$digit)([a-zA-Z]*))?$}) { # If we are dealing with a time range
		my $ttype = $Keys[0];
		my $range=ToSec(1 . $ttype)/2;
		my $start_relitive=($1) ? (($1 eq '@') ? 0 : 2) : 1 ;
		my ($start,$start_unit,$end_relitive,$end,$end_unit)=($2,$3||$ttype,( ($4)? 0 : 1),$5,$6||$ttype);
		my $start_offset;
		my $end_offset;
		my $time = time;
		my $start_time;
		my $end_time;
		if ($end) {
			$start_offset=ToSec($start . ($start_unit||$ttype));
			$end_offset=ToSec($end . ($end_unit||$ttype));
			$start_time	= (($start_relitive>=1) ? $time : 0) + $start_offset;
			$end_time	= (($end_relitive==1) ? $time : 0) + $end_offset;
			foreach my $ktime (keys $FC->{$ttype}) {
				next unless(IsDigit($ktime));
				push(@$Times,[$ttype,$ktime]) if (($end_time) >= $ktime && $ktime >= ($start_time));
			}
		} elsif ($start_relitive == 1) {
			$end_offset=ToSec(1 . $ttype)/2;
			$start_offset=ToSec($start . ($start_unit||$ttype));
			$start_time	= $time + $start_offset - $end_offset;
			$end_time	= $time + $start_offset + $end_offset;
			foreach my $ktime (keys $FC->{$ttype}) {
				next unless(IsDigit($ktime));
				push(@$Times,[$ttype,$ktime]) if (($end_time) >= $ktime && $ktime >= ($start_time));
			}
		} elsif ($start_relitive == 2) {
			$start_offset=ToSec($start . ($start_unit||$ttype));
			$start_time	= $time + $start_offset;
			push(@$Times,[$ttype,$start_time]);
		} else {
			$start_time=ToSec($start . ($start_unit||$ttype)) ;
			push(@$Times,[$ttype,$start_offset]);
		}
	} else {
		push(@$Times,[@Keys,$key]);
	}
	return $Times;
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
