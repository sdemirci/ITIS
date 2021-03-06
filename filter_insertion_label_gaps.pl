#!/usr/bin/perl
use warnings; use strict;
use Getopt::Std;

my $help = "$0 
	-i : insertion list in bed format
	-l : postion list of te homo in ref genome
	-g : position list of reference gaps(NNs)
	-m : mode (new, copy or regular), default is regular
	-n : in the form /t=3/TS=1/TE=1/ , the minimum requried:
			t:total reads supporting insertion  /3/
			CS:clipped reads cover TE start site /0/
			CE:clipped reads cover TE end site  /0/
			cs:cross reads cover TE start  /0/
			ce:cross reads cover TE end    /0/
			TS:total reads cover TE start  /1/
			TE:total reads cover TE end    /1/
	-q : degault <1>, the minimum required average mapping quality
	-d : default <2,200>, the reads depth range
	-b : the treshhold of NB tag  default : 100;
	-h : help message
	";

die $help unless ( @ARGV);

my %opt;
getopts("i:l:g:m:b:c:n:q:d:r:h",\%opt);
die $help  if($opt{h});

######## parameters ###########
my $nb = $opt{b}?$opt{b}:100;
my $ins_file = $opt{i};
my $lst = $opt{l};
my $gap = $opt{g};

my $mode = $opt{m}? $opt{m}:'regular';

my $sr = $opt{n}? $opt{n} : '/t=3/TS=1/TE=1/';
	my %paras = parse_sr($sr);

my $MQ = defined($opt{q})?$opt{q}:1;
my ($DP_L,$DP_H) = $opt{d}?(split ',',$opt{d}):(split ',',"2,200");

open INS, "$ins_file" or die $!;


## all homo in hash %homos
my %homos;
if($lst){
	open LST, $lst or die $!;
	while(<LST>){
		chomp;
		my($chr,$s,$e,$te) = split /\t/;
		$s = $s - $nb;
		$e = $e + $nb;
		foreach my $i ($s..$e){
			$homos{$te}{$chr}{$i} = 1;
		}
	}
}

## all gaps  in hash %gaps
my %gaps;
if($gap){ 
        open GAP, $gap or die $!;
        while(<GAP>){
                chomp;
                my($chr,$s,$e) = split /\t/;
                $s = $s - $nb;
                $e = $e + $nb;
                foreach my $i ($s..$e){
                        $gaps{$chr}{$i} = 1;
                }
        }
}


while(<INS>){
	
	my $boo = 1;

	my($chr,$s,$e,$t,$rest) = (split /\t/, $_,5);
	
	my@tags = split /;/, $t;

### parse the rest key and values ###
#####################################
	my %other;
	foreach my $r (@tags){
		my($k,$v) = split /=/,$r;
		$other{$k} = $v;
	}

# filter support reads number
	if(exists $other{SR}){
		my($cf,$tot,$r1,$r2,$r3,$r4) = split /,/,$other{SR};
		
		if($mode eq 'regular'){
		
			if($tot < $paras{t} or $r1 < $paras{CS} or $r2 < $paras{CE} or $r3 < $paras{cs} or $r4 < $paras{ce} 
				or ($r1+$r3) < $paras{TS} or ($r2+$r4) < $paras{TE}){
				$boo = 0;
			}
		}elsif ($mode eq 'copy'){
			
			if($tot < $paras{t} or $r1 < $paras{CS} or $r2 < $paras{CE} or $r3 < $paras{cs} or $r4 < $paras{ce} 
				or  ( ($r1+$r3) < $paras{TS} and ($r2+$r4) < $paras{TE}) ) {
				$boo = 0;
			}
			
		}elsif ($mode eq 'new'){
			
			if($tot < $paras{t} or ($r1 < $paras{CS} and $r2 < $paras{CE}) or $r3 < $paras{cs} or $r4 < $paras{ce} 
				or  ( ($r1+$r3) < $paras{TS} and ($r2+$r4) < $paras{TE}) ) {
				$boo = 0;
			}
			
		}
	}
# filter eveage mapping valeu
	if(exists $other{MQ} and $other{MQ} < $MQ){
		$boo = 0;
	}
#SD:210818 the DP check is removed
# filter bg depth
#	if(exists $other{DP} ){
#		my $dp = $other{DP};
#		if ($dp < $DP_L or $dp > $DP_H){
#			$boo = 0;
#		}
#	}

# mark ins near known site
	if ($lst){
		my $near = 0 ;
		for my $i ($s..$e){
			if ($i ~~ %{$homos{$other{NM}}{$chr}}){
				$near = 1;
			}
		}
		if($near){
			$t .= ";NB=Y";
		}else{
			$t .= ";NB=N";
		}
	}

# mark ins near gap site
        if ($lst){
                my $near = 0 ;
                for my $i ($s..$e){
                        if ($i ~~ %{$gaps{$chr}}){
                                $near = 1;
                        }
                }
                if($near){
                        $t .= ";NG=Y";
                }else{
                        $t .= ";NG=N";
                }
        }




	print join "\t", ($chr,$s,$e,$t,$rest) if $boo;
}

sub parse_sr{
	my $p = shift @_;
	my %paras = (
		t  => 0,
		CS => 0,
		CE => 0,
		cs => 0,
		ce => 0,
		TS => 0,
		TE => 0,
	);
	my @ps = split /\//,$p;
	foreach my $t (@ps){
		next unless($t);
		my($k,$v) = split /=/,$t;
		$paras{$k} = $v;
	}
	return %paras;
}
