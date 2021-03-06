#!/usr/bin/perl
use warnings; use strict;
use Seq;
use Bio::SeqIO;
use Getopt::Std;

my %opt;
getopts("g:t:o:h",\%opt) ;

die "USAGE $0 
	-g genome seq file
	-t te seq file
	-o name of output file with combined sequence (*.fa)
	-h help

	" if ( $opt{h});

# put genome seq in hash
my $seq_in = Bio::SeqIO -> new (-file => $opt{g},-format => "fasta");
my %genome ;
my @order;
while (my $seq_obj = $seq_in -> next_seq){
	my $id = $seq_obj -> id;
	my $seq = $seq_obj -> seq;
	$genome{$id} = $seq;
	push @order,$id;
}
# put te seq in hash
my %te = Seq::seq_hash($opt{t});

# using blast2seq to identify the te homolog
open LIS, ">$opt{o}.list" or die $!;
open BLA, "blastn -query $opt{t} -subject $opt{g} -word_size 14 -outfmt 6 |" or die $!;
while(<BLA>){
	chomp;
	my ($te,$chr,$s,$e) = (split /\t/,$_)[0,1,8,9];
	($s,$e) = sort {$a<=>$b}($s,$e);
	print LIS "$chr\t$s\t$e\t$te\n";
	my $l = $e-$s+1;
	#print STDERR "substracting...\nalignment $_\n";
	substr($genome{$chr},$s-1,$l) = "N"x$l;
}



# put masked genome seq and te seq together 
open OUT, ">$opt{o}" or die $!;
foreach my $k ( @order){
	print OUT ">$k\n$genome{$k}\n";
}

foreach my $k(keys %te){
	print OUT ">$k\n$te{$k}\n";
}
