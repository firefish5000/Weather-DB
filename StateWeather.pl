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

my $FC = WeatherDB::AccuWeather->new();
$FC->Load();
$FC->GetForecast('Lakeland');
$FC->Daily_Parser('Lakeland',{},day=>1);
say ('The Current weather is ', Describe($FC->{Locations}{$FC->{Alias}{Lakeland}{ID}}{Current}{0}) );
say ('Today is expected to be ', Describe(ValsOfTime($FC->{Locations}{$FC->{Alias}{Lakeland}{ID}}{Days},q{-12h},q{12h})->[0]) );
say ('Tommarow is expected to be ', Describe(ValsOfTime($FC->{Locations}{$FC->{Alias}{Lakeland}{ID}}{Days},q{12h},q{12h})->[0]) );
#say ('This Morning is expected to be ', Describe($FC->{Locations}{$FC->{Alias}{Lakeland}{ID}}{Current}{0}) );
#say ('and Tonight is expected to be ', Describe($FC->{Locations}{$FC->{Alias}{Lakeland}{ID}}{}{0}) );
#say ('and Tonight is expected to be ', Describe($FC->{Locations}{$FC->{Alias}{Lakeland}{ID}}{Current}{0}) );
sub KeysOfTime {
	my $tunit=shift;
	my $tstart=ToSec(shift);
	my $trange=ToSec(shift);
	my @times = sort(keys $tunit);
	my @times2;
	foreach my $time (@times) {
		push (@times2,$time) if (time+$tstart - $trange <= $time && $time <= time + $tstart + $trange);
	}
	return \@times2;
}
sub ValsOfTime {
	my $tunit=shift;
	my $tstart=ToSec(shift);
	my $trange=ToSec(shift);
	my @times = sort(keys $tunit);
	my @times2;
	foreach my $time (@times) {
		push (@times2,$tunit->{$time}) if (time+$tstart - $trange <= $time && $time <= time + $tstart + $trange);
	}
	return \@times2;
}
sub Describe {
	my $tfc=shift; # Pass the time specific forcast.
#	my $Time = ($tfc->{Range} == 60) ? q{Minute};
	my $Temp=q{};
	my $Feel=q{};
	my $Cond=q{};
	Wrn "Weather store:\n", Dumper $tfc;
	foreach my $key (keys ($tfc)) {
		my $val=$tfc->{$key};
		given ($key) {
			when ('Temp') {
				$Temp = qq{with a tempeture of $val Farenheit};
			}
			when ('RealFeel') {
				$Feel=q{Feels like } . RealFeel($val);
			}
			when ('Condition') {
				$Cond=$val;
			}
			default {
				Carp qq{Unknown key <$key>};
			}
		}
	}
	return join(qq{\n}, $Cond, $Temp, $Feel);
}
sub RealFeel {
	my $RF = shift;
	my $Temp;
	foreach my $key (keys ($RF)) {
		my $val=$RF->{$key};
		given ($key) {
			when ('Temp') {
				$Temp = qq{of $val degrees Farenheit};
			}
			default {
				Carp qq{Unknown key <$key>};
			}
		}
	}
	return join("\n",$Temp);
}
sub Time_Filtrate {
	my $Times=shift();
	my @Keys=@{shift()};
	my $key=shift();
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
sub ToSec {
    my $time = shift;
    my $Seconds = 0;
	return 0 unless defined($time);
	return $time if $time =~ m{^( '-'? \d+ | inf )$}x;
	#Croak q{Time Uninitialized} unless defined($time);
	#while ($time =~ m{ (\d+) \s* ([^0-9 \t]+)?  }gx) {
	while ($time =~ m{ ([\+\-]?(?:\d+(?:\.\d*)?|\d*\.\d+)) \s* ([^0-9 \t]+)?  }gx) {
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
