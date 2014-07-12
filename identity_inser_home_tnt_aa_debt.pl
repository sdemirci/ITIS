#!/usr/bin/perl
use warnings; use strict;
use Seq;
use Getopt::Std;


########## get parameters #################
my %opts;
my $usage = "$0
	-h : help message
	-s : informative sam file
	-g : genome file
	-l : library insertion size
	-n : the id of te seq
	-p : 'directory/prefix' of your output files, relative to your working direcroty;
		 this script generate two output files : '\$WD/directory/prefix.ins.loc.lst' and '\$WD/directory/prefix.supported.reads.sam
	-r : tnt realian sam 
	-d : debug mode on 
";

die "$usage\n" if (@ARGV==0);
getopts("hs:g:l:n:p:r:d",\%opts);
if ($opts{h}){ print "$usage"; exit};

my ($sam_file,$genome_file,$ins_size,$te) = ($opts{s},$opts{g},$opts{l},$opts{n});
my $sam_te = $opts{r};
my $project = $opts{p};




############# put genome seq in hash  #########
my %genomes = Seq::seq_hash($genome_file);
my $tnt_len = length ($genomes{$te});  # transposon length



############# files used to save results ##
open OUT ,">${project}.ins.loc.lst" or die $!;
open SUPP,">${project}.supported.reads.sam" or die $!;


############ parsing the te realn sam file ##### because TE have LTRs at both end

my %guanxi = te_aln($sam_te); 

=head
my $che = $guanxi{"SRR823377.1286498:1"};
print "@$che\n";
my $ch = $guanxi{"SRR823377.1286498:2"};
print "@$ch\n";

foreach( keys%guanxi){
	#print "K:$_\n";	
	my $v = $guanxi{$_};
	print "@$v\n";
}
=cut




###########################################################
################ the mainbody of code######################
###########################################################
###########################################################
my @aligns = scan_sam ($sam_file);

=test scan_sam
foreach my $it ( @aligns){
	print "@$it\n";
}
=cut

my $rds;
foreach my $grp (@aligns){  # parse each group of reads
	my %cors;
	my @hits = @$grp;
	$rds = join "\n",@hits;
	my %te_ha = read_2_ha($hits[0] );
	$cors{$te} = \%te_ha;
	my %chr_ha = read_2_ha($hits[1] );
	$cors{tar} = \%chr_ha;

	
	#print "THERE :$rds\n";
	my $tar_cig = $cors{tar}{cig};
	my $te_cig = $cors{$te}{cig}; 
	

	if ( $tar_cig =~ /M/ and $te_cig =~ /M/){
		cross(%cors);
	}
	if($te_cig =~ /S/){
		te_start(%cors);
	}
	if($te_cig =~ /E/){
		te_end(%cors);
	}
	if($tar_cig =~ /S/){
		ge_start(%cors);
	}
	if($tar_cig =~ /E/){
		ge_end(%cors);
	}
	if ($tar_cig =~ /Z/){
		#print "Do nothing for tar_cig_f:$read\n";
	}
	if ($te_cig =~ /Z/){
		#print "Do nothing for te_cig_f:$read\n";
	}
}
#################### the end of mainbody of code ######################





#######    sub functions  #######
sub te_aln{
	my $sam_te = shift @_;	
	
	my %guanxi;
	my %te_rcd;
	open my $fh, "samtools view -S -X $sam_te|"  or die $!;
	my $l_seq;
	my $l_as;
	while (<$fh>){
		chomp;
		my @ar  = (split /\t/,$_,12);
		my ($id,$flag,$pos,$cig,$seq,$tags) = @ar[0,1,3,5,9,11];
		
		my $direc = ($flag =~ /r/)?-1:1;
		my ($as) = $tags =~ /AS:i:(\d+)/;  

		## firstly, save the full infor to $l_seq and $l_as	
		unless($te_rcd{$id}){
			$guanxi{$id} = [];
			if ($direc == -1){
				$l_seq = Seq::rev_com($seq);
			}else{
				$l_seq = $seq;
			}
			$l_as = $as;
			$te_rcd{$id} = 1;
		}
		
		if($direc == -1){
			$seq = Seq::rev_com($l_seq);
		}else{
			$seq = $l_seq;
		}
		$ar[9] = "$seq";
		my $p = join "\t", @ar;
			
		if ($cig =~ /^\d+M$/){
			push @{$guanxi{$id}}, $p;
		}elsif($cig =~ /^\d+M(\d+)[SH]$/){
			if (abs(($pos + length($l_seq) - $1 -1) - $tnt_len) < 2){
				push @{$guanxi{$id}} ,$p;
			}
		}elsif($cig =~ /^\d+[SH]\d+M$/){
			if (abs ($pos) < 2){
				push @{$guanxi{$id}} , $p;
			}
		}
	}
	return %guanxi;
}
	
	

sub scan_sam{    # put the pair reads in to one element of one array @re
	my $file = shift @_;
	open my $fh , $file or die $!;
	
	my @re;   
	while (<$fh>){
		chomp;
		if (/^@/){
			print SUPP "$_\n";
			next;
		}
		my($id,$flag,$chr) = (split /\t/,$_)[0,1,2];
		next if ( $chr =~ /$te/);

		my $r = ($flag =~ /1/)?1:2;
		$_ =~ s/$id\t/$id:$r\t/;
		my $r_a_t = ($r =~ /2/)?1:2;
		
		if(   defined $guanxi{"$id:$r_a_t"}){
			foreach my $te_aln (@{$guanxi{"$id:$r_a_t"}}){
				print "$te_aln\n$_\n" if ($id eq "SRR823377.1286498");
				push @re, [$te_aln,$_] unless ($chr =~ $te);
			}
		}
	}
	return @re;
}	

sub read_2_ha{     # this subroutine used to
	my %cors;
	my $hit =shift  @_;
	my($id,$flag,$chr,$pos,$mq,$cig,$nchr,$npos,$seq) = (split /\t/,$hit)[0,1,2,3,4,5,6,7,9];
	my $rc = (($flag =~ /r/)? -1:1);
	my $cs = cigar($cig);
	($id,my $r) = $id =~ /(.+)\:(\d)$/;
	$cors{cig} = $cs;
	$cors{direc} = $rc;
	$cors{id} = $id;
	$cors{pos} = $pos;
	$cors{seq} = $seq;
	$cors{chr} = $chr;
	return %cors;
}

sub cigar {
	my $cig = shift @_;
	return "Z" if ($cig =~ /\*/);
	my $len;		        #  reads length
	my $cs;                      #  simplified cigars 
	my ($m_l);					# match length
		
	while ($cig =~ /(\d+)([MSIH])/g){
		my $n = $1;
		my $c = $2;
		$len += $n;
		$m_l += $1 if ($c eq "M");
	}
	if ($m_l/$len > 95/100  ){     #  matcha and mismatch > 0.95 ; it will be considered as totally matched reads
		$cs = "M";
	}else{
		if ( $cig =~ /^(\d+)[SH]/ and $1 >= 5){
			$cs .= "S:$1";
		}
		if ( $cig =~ /(\d+)[SH]$/ and $1 >= 5){
			$cs .= "E:$1";
		}
	}
	$cs = ($cs?$cs:"Z");
	return $cs;
}

sub cross {
	my %cors = @_;
	if ( $cors{$te}{direc} == 1 and $cors{$te}{pos} > ($tnt_len - $ins_size)){
		
		#   ---------------------------->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>------------------------------
		#                                                               ----->    <--------
		#   ----------------------------<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<------------------------------
		#                 -------->       <------
		my ($ins_direc,$jun);
		if ($cors{tar}{direc} == 1){
			$ins_direc = "R";
			$jun = $cors{tar}{pos} + length ($cors{tar}{seq});  # assume the ins site is the end of match of reads at genome
		}else{
			$ins_direc = "S";
			$jun = $cors{tar}{pos};                            # assume the ins site at the start of match of read at genome
		}
		$ins_direc = $cors{$te}{ori} if($cors{$te}{ori});
		print OUT "$cors{$te}{id}\t$ins_direc\t$cors{tar}{chr}\t$jun\tCE\n";
		print SUPP "$rds\n";
	}elsif ( $cors{$te}{direc} == -1  and $cors{$te}{pos} < ($ins_size - length($cors{$te}{seq}))){
		
		#   ---------------------------->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>------------------------------
		#                   -------->       <--------
		#
		#   ----------------------------<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<------------------------------
		#                                                                ------>	<-----
       		
		my ($ins_direc,$jun);
		if ( $cors{tar}{direc} == 1 ){
			$ins_direc = "S";
			$jun = $cors{tar}{pos} + length($cors{tar}{seq});
		}else{
			$ins_direc = "R";
			$jun = $cors{tar}{pos};
		}
		$ins_direc = $cors{$te}{ori} if($cors{$te}{ori});
		print OUT "$cors{$te}{id}\t$ins_direc\t$cors{tar}{chr}\t$jun\tCS\n";
		print SUPP "$rds\n";
	}else{
		print  "cross fail:$cors{$te}{id}\tte_direc:$cors{$te}{direc}\tte_pos:$cors{$te}{pos}\ttar_direc:$cors{tar}{direc}\n" if ($opts{d});
	}
}

sub te_start{
	my %cors = @_;
	if($cors{$te}{cig} =~ /S:(\d+)/ and $cors{$te}{direc} == -1 ){
		# ---------------------------->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>------------------------------
		#             ------->     <-------
		#
		# --------------------------- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<------------------------------
		#                                                                 ------->   <-----
		
		my $l = $1;
		if ($cors{$te}{pos} <=2 ){
			my $que = substr($cors{$te}{seq},0,$l);
			( my $que_r = $que) =~ tr/ATCGatcg/TAGCtagc/;
			$que_r = reverse $que_r;
			my $ins_direc;
			my $sub;
			my $chr_t = $cors{tar}{chr};
			my $pos_t = $cors{tar}{pos};
			my $len_t = length $cors{tar}{seq};
			if($cors{tar}{direc} == 1){
				$ins_direc = "S";
				$sub = substr($genomes{$chr_t},$pos_t-1,$ins_size);
				
				my ($diff,$jun) = mat($que,$sub);
				
				if($jun != -1 and $diff/$l < 0.05){
					$jun = $jun + $pos_t+ $l -1 ;
					print OUT "$cors{$te}{id}\t$ins_direc\t$chr_t\t$jun\tTS\n";
					print SUPP "$rds\n";
				}
			}else{
				$ins_direc = "R";
				my $sub_start = $pos_t-$ins_size +$len_t;
				$sub = substr($genomes{$chr_t},$sub_start-1,$ins_size);
				
				my($diff,$jun) = mat($que_r,$sub);

				if($jun != -1 and $diff/$l < 0.05){
					$jun = $jun + $sub_start ;
					print OUT "$cors{$te}{id}\t$ins_direc\t$chr_t\t$jun\tTS\n";
					print SUPP "$rds\n";
				}	
			}
		}else{
			print "te_start_pos_err:$cors{$te}{id}\t$cors{$te}{pos}\n"if ($opts{d});
		}
	}else{
		print  "te_start_direc:$cors{$te}{id}\t$cors{$te}{cig}\t$cors{$te}{direc}\n" if ($opts{d});
	}
}

sub te_end{
	my %cors = @_;
	if ($cors{$te}{cig} =~ /E:(\d+)/ and $cors{$te}{direc} == 1){

		#---------------------------->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>-------------------------------
		#                                                      -------->     <-------
		#
		#----------------------------<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<-------------------------------
		#                ------>  <--------      
		my $l = $1;
		my $end_pos = $cors{$te}{pos} + length($cors{$te}{seq}) - $l;
		if ($end_pos >= $tnt_len-10 ){
			my $que = substr($cors{$te}{seq},-$l);
			( my $que_r = $que) =~ tr/ATCGatcg/TAGCtagc/;
			$que_r = reverse $que_r;
			my $ins_direc;
			my $sub;
			my $chr_t = $cors{tar}{chr};
			my $pos_t = $cors{tar}{pos};
			my $len_t = length $cors{tar}{seq};
			if($cors{tar}{direc} == 1){
				$ins_direc = "R";
				$sub = substr($genomes{$chr_t},$pos_t-1,$ins_size);
				
				my ($diff,$jun) = mat($que_r,$sub);
				
				if( $jun != -1 and $diff/$l <0.05 ){
					$jun = $jun + $pos_t + $l -1 ;
					print OUT "$cors{$te}{id}\t$ins_direc\t$chr_t\t$jun\tTE\n";
					print SUPP "$rds\n";
				}
			}else{
				$ins_direc = "S";
				my $sub_start = $pos_t+$len_t-$ins_size;
				$sub = substr($genomes{$chr_t},$sub_start-1,$ins_size);
				
				my ($diff,$jun) = mat($que,$sub);

				if($jun != -1 and $diff/$l < 0.05 ){
					$jun = $jun + $sub_start;
					print OUT "$cors{$te}{id}\t$ins_direc\t$chr_t\t$jun\tTE\n";
					print SUPP "$rds\n";
				}
			}
		}else{
			print  "te_end_pos:$cors{$te}{id}\t$end_pos\n"if ($opts{d}) ;
		}
	}else{
		print "te_end_direc:$cors{$te}{id}\t$cors{$te}{cig}\t$cors{$te}{direc} \n"if ($opts{d});
	}
}



sub ge_start{
	my %cors = @_;
	if($cors{tar}{cig} =~ /S:(\d+)/ ){
		#  --------------------------------------->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>-------------------------------------------------
		#                                                        --------->       <---------
		#
		#
		#  ---------------------------------------<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<-------------------------------------------------
		#                                                         -------->        <----------  
		my $l = $1;
		my $que = substr($cors{tar}{seq},0,$l);
		( my $que_r = $que) =~ tr/ATCGatcg/TAGCtagc/;
		$que_r = reverse $que_r; 
		my $sub_h = "NNNNN".substr($genomes{$te},0,$l+5);
		my $sub_t = substr($genomes{$te},-($l+5))."NNNNN";
		
		my %ma_hash = match($que,$que_r,$sub_h,$sub_t);	
		if  (%ma_hash){
			if ($ma_hash{3}  and $cors{$te}{direc} == 1 and $cors{$te}{pos} > ($tnt_len - $ins_size)  ){
				my $adj = $ma_hash{3} - 5;
				my $ins_direc = "S";
				my $jun  = $cors{tar}{pos} - $adj;
				print OUT "$cors{tar}{id}\t$ins_direc\t$cors{tar}{chr}\t$jun\tGE\n";
				print SUPP "$rds\n";
			}elsif($ma_hash{-2}  and $cors{$te}{direc} == -1 and $cors{$te}{pos} < ($ins_size - length($cors{$te}{seq}))) {
				my $adj = $ma_hash{-2} -5 ;
				my $ins_direc = "R";
				my $jun = $cors{tar}{pos} + $adj ;
				print OUT "$cors{tar}{id}\t$ins_direc\t$cors{tar}{chr}\t$jun\tGS\n";
				print SUPP "$rds\n";
			}
		}else{
			print "ge_start_mism:$cors{tar}{id}:$que\t$que_r\n"if ($opts{d});
		}
	}
}

sub ge_end{
	my %cors = @_;
	if($cors{tar}{cig} =~ /E:(\d+)/){
	
		#  --------------------------------------->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>-------------------------------------------------
		#                                    --------->       <---------
		#
		#
		#  ---------------------------------------<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<-------------------------------------------------
		#                                     -------->        <----------  
		my $l = $1;
				
		my $que = substr($cors{tar}{seq},-$l);
		( my $que_r = $que) =~ tr/ATCGatcg/TAGCtagc/;
		$que_r = reverse $que_r; 
		my $sub_h = "NNNNN".substr($genomes{$te},0,$l+5);
		my $sub_t = substr($genomes{$te},-($l+5))."NNNNN";
		
		my %ma_hash = match($que,$que_r,$sub_h,$sub_t);
		if (%ma_hash){
			
			if ( $ma_hash{-3} and $cors{$te}{direc} == 1 and $cors{$te}{pos} > ($tnt_len - $ins_size)){
				my $adj = $ma_hash{-3} - 5;
				my $ins_direc = "R";
				my $jun = $cors{tar}{pos} + length($cors{tar}{seq})-$l-1+$adj;
				print OUT "$cors{tar}{id}\t$ins_direc\t$cors{tar}{chr}\t$jun\tGE\n";
				print SUPP "$rds\n";
			}elsif ( $ma_hash{2} and $cors{$te}{direc} == -1 and $cors{$te}{pos} < ($ins_size - length($cors{$te}{seq}))){
				my $adj = $ma_hash{2} - 5;
				my $ins_direc = "S";
				my $jun = $cors{tar}{pos} + length($cors{tar}{seq})-$l-1-$adj;
				print OUT "$cors{tar}{id}\t$ins_direc\t$cors{tar}{chr}\t$jun\tGS\n";
				print SUPP "$rds\n";
			}
		}else{
			print "ge_end_mism:$cors{tar}{id}\t$que\tsub:$sub_t\t$sub_h\n"if ($opts{d});
		}
	}
}


sub mat { 
	my ($que,$sub) = @_;
	my $q_l = length $que;
	my $s_l = length $sub;
	my $record = 100;
	my $loc = -1;
	for my $i (0..($s_l-$q_l)){
		my $tgt = substr($sub,$i,$q_l);
		my $diffcount = () = ($que ^ $tgt) =~ /[^\x00]/g;
		if ($diffcount < $record){
			$loc = $i;
			$record = $diffcount;
		}

	}
	return ($record,$loc);
}


sub match {
	my %relas;
	
	for my $j (0..1){
		for my $k (2..3){
			my $que = $_[$j];
			my $sub = $_[$k];
			my ($diff,$loc) = mat($que,$sub);
			my $ratio = $diff/(length $que);
			my $direc = ($j==0?1:-1);
			
			my $dir_pos  = $direc * $k;	
			$relas{$ratio}{$dir_pos} = $loc   # head of tail of sequence matched
		}
	}
	
	foreach (sort {$a<=>$b} keys %relas){	
		if ( $_ <= 0.05){
			my $v = $relas{$_};
			my %m_h = %$v;
			return (%m_h);   #### return value SH  ST RH  RT  
		}
		last;
	}
}

sub count_m {
	my $cig = shift @_;
	my $num;
	while($cig =~ /(\d+)M/g){
		$num += $1;
	}
	return $num;
}
