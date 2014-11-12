#ITIS:(Identify Transposon Insertion Site)<br>
is a pipeline to identify TE indertion site in genome

It require three input files:<br>  	
	(i) reference genome sequence,<br> 
	(ii)TE sequence, <br>
	(iii)paired-end(PE) short reads generated from sample with TE in it have moved to other region.<br> 

By aligning read pairs to merged reference sequence, reference genome and TE sequence, ITIS will check each informative read pairs as long as it have more than 20bp overlap with TE sequence and determine if it supports the TE insertion around the location mapped by one of read pair.  In theory, by inspecting both cross read pairs and clipped reads at the same time, ITIS will have a higher sensitivity than other tools

---
---


##Table of Contents
### <a href="#dep">Dependencies</a><br>
### <a href="#cmd">Command line options</a>
### <a href="#qck">Quick start with a sample dataset</a>
### <a href="#iss">Report an Issue</a>

---
---
### <a name="dep">Dependencies:

   The following programs need to be installed and the executable should be in your path:
	
	samtools (v 0.1.19)
	bwa      (v 0.7.7-r441)
	bedtools (v 2.17.0)
	Bio::Perl
	R
	
	Other usefull tool:
	IGV
	
-------------

### <a name="cmd">Comamnd Line Options

--------------------

#### perl itis.pl	

USAGE:
    /psc/home/jiangchuan/Code/itis.pl  
	
	
	REQUIRED -g the genome sequence file in fasta format  
	REQUIRED -t the TE sequence file in fasta format  
	REQUIRED -l the average length of fragments in library  	
	REQUIRED -N the name of you project  
	REQUIRED -1 the paired read file 1  
	REQUIRED -2 the paired read file 2  	
		  
		-f gff file. if provided, ITIS will check if TE inserted in gentic or intergeneic region	 
		-F <Y|N: default N> run scripts in 'FAST' mode; It will not align all reads to reference genome,caculate the average bg depth 
		     and estimate if insertion is homo or heter
			
			##  parameters specific to  '-F N'  :
			-B use your previous sorted and indexed bam file of all clean reads align to reference genome; on condition of '-F N'
			-R the minimum ratio of support fragments  and depth of 200 bp around the insertion site; default 0.2
			-D <2,200>, the depth range to filter candidate insertion site. 

		-q default: 1  the minimum average mapping quality of all supporting reads

		-e <Y|N: default N> if TE sequence have homolog in genome. using blast to hard mask repeat sequence is required
		
		-a <10> the allow number of base can be lost during transposon

		-b in the form /t=3/TS=1/TE=1/ , the minimum requried:
			t:total reads supporting insertion  /3/
			CS:clipped reads cover TE start site /0/
			CE:clipped reads cover TE end site  /0/
			cs:cross reads cover TE start  /0/
			ce:cross reads cover TE end    /0/
			TS:total reads cover TE start  /1/
			TE:total reads cover TE end    /1/
		
		-c FORMAT:\d,\d,\d; for  cpu number for 'BWA mem', 'samtools view'  and 'samtools sort'    defualt 8,2,2
		
		-w window size for cluster you support reads: DEFAULT : default: lib_len/2
		
		-T use this specifed temperate directory or use the DEFAULT one :[project].[aStringOfNumbers]
		
		-m <Y|N: default F> Only print out all commands to STDERR
	         
		-h print this help message    

	
		eg: perl itis.pl -g genome.fa -t tnt1.fa -l 300  -N test_run -1 reads.fq1 -2 reads.fq2 -f medicago.gff3 

		BWA samtools should in you PATH


-------------


### <a name="#qck">Quick start with a sample dataset
this test dataset derived from the genome resequencing project of Japonica A123(SRR631734), which have transposon mping be activted.

All PE reads mapped at chr1:1-2000000 were extracted and saved in file sample.fq1 and sample.fq2. 

First of all, untar the sample dataset:       
    
    cd test_dir
    tar xvzf sample_data.tar.gz     

####Input Files  
	PE reads:
		sample.fq1
		sample.fq1
	reference genome:
		rice_chr1_200k.fa
	Transposon sequence:
		mping.fa

####command to detect mping insertions in reference genome
	perl path/to/itis.pl -g rice_chr1_200k.fa -t mping.fa  -l 500 -N test -1 sample.fq1  -2 sample.fq2 -e Y    

	\#-e Y : to tell itis.pl that there are mping homologous sequence in reference genome

####Output Files
	itis will produce a lot of files in a directory named test.[aStringOfNumbers]
	
	The important files included:

		test.mping.filtered.bed  
			This is a list of confident insertion sites. 
		test.mping.raw.bed  
			This is all insertion sites, some of which may be false 
		test.mping.support.reads.sam and test.mping.support.reads.sorted.bam
			This is alignment file of all supportive reads
		test.all_reads_aln_ref_and_te.sort.bam
			This is alignment file of all reads
		commands_rcd
			A record of all the command used by itis.pl to identify TE insertions.
	
	If you want to filter the raw insertion list by personalized criteria, you can rerun the script filter_insertion.pl, just as shown in command_rcd


	
-------------

### <a name="#iss">Report an Issue
If you have any questions or suggestion, please feel free to contact me :chjiang at sibs.ac.cn
-----------




