#!/usr/bin/perl
#
use strict;
use Getopt::Long;

my ($infile, $outfile, $overwrite, $adapterseq, $help, $verbose, $debug, $fastq,$idlist,$idlistfile,$printall,$notwoadapters,$id2adapters);

my $options = GetOptions(
  "infile=s"      =>  \$infile,
  "outfile=s"     =>  \$outfile,
  "overwrite"     =>  \$overwrite,
  "adapterseq=s"   =>  \$adapterseq,
  "help"          =>  \$help,
  "verbose"       =>  \$verbose,
  "debug"         =>  \$debug,
  "fastq"         =>  \$fastq,
  "idlist"        =>  \$idlist,
  "idlistfile=s"  =>  \$idlistfile,
  "printall"      =>  \$printall,
  "notwoadapters"    =>  \$notwoadapters,
  "id2adapters"      =>  \$id2adapters,
);

if (!$options) {
  print "couldn't parse options\n";
  exit();
}

if ($help) {
print <<HELP;

  "infile=s"      =>  \$infile,
  "outfile=s"     =>  \$outfile,
  "overwrite"     =>  \$overwrite,
  "adapterseq=s"   =>  \$adapterseq,
  "help"          =>  \$help,
  "verbose"       =>  \$verbose,
  "debug"         =>  \$debug,
  "fastq"         =>  \$fastq,
  "idlist"        =>  \$idlist,
  "idlistfile=s"  =>  \$idlistfile,
  "printall"      =>  \$printall, # print all sequences, even if they don't contain adapter sequence
  "notwoadapters"  =>  \$notwoadapters, # skip sequences that contain > 1 adapter sequence, even if --printall
  "id2adapters"    =>  \$id2adapters, # output sequences with >1 adapter to STDERR, requires --notwoadapters

notes:

--notwoadapters filters out sequences with more than one adapter sequence. Typically, these reads are composed
almost exclusively of adapter sequence, so "two" usually means "at least two". You can see the sequences that
are filtered using --id2adapters, which directs those sequences to STDERR.

ie:  adapter_trim.pl --infile set1.fq --fastq --outfile trimmed1.fq --adapterseq AAGCAGTGGTATCAACGCAGAGTAC --notwoadapters --id2adapters >& 2adapters.txt

HELP
exit;
}

$infile = 'infile' unless ($infile);
$outfile = 'outfile' unless ($outfile);
$idlistfile = 'idlist' unless ($idlistfile);

if (-e $outfile && !$overwrite) {
  print "$outfile already exists and you didn't specify to overwrite\n";
  exit();
}

if (!$adapterseq) {
  print "you must enter a adapter sequence using the --adapterseq argument\n";
  exit();
}

open(IN,$infile) or die "can't open '$infile': $!";
open(OUT,">$outfile") or die "can't open '$outfile': $!";

if ($idlist) {
  open(ID,">$idlistfile") or die "can't open 'idlist': $!";
}

my ($seqname, $seq, $parsed);

if (!$fastq) {
  while (<IN>) {
    print $_ if ($debug);
    
    if ($_ =~ /^>(.+)\n/) {
      $seqname = $1;
      next;
    }
    
    chomp($_);
    $seq = \$_;
  #  print "seq '$seqname' = '" . $$seq . "'\n" if ($debug);
    
    if ($$seq =~ /^$adapterseq/) {
      print "parsed read:\n" if ($debug);
      $parsed = $$seq;
      $parsed =~ s/^$adapterseq//;
      print "\t>$seqname\n\t$parsed\n" if ($debug);
      print OUT ">$seqname\n$parsed\n";
    }
    
  }
} else {

  my ($initial,$gotseqname,$gotqual,$getqual,$getseq,$trim) = (0,0,0,0,0);
  my ($quality,$sequence,$qualname);
  #
  # loop through file, collect sequence ID, sequence and quality string
  # trim sequence if necessary
  # if sequence gets trimmed, trim same number of characters from quality string
  # print trimmed fastq sequence and quality string
  #
  
  while (<IN>) {    
    if ($_ =~ /^\@(.+)\n/) {
      $seqname = $1;
       
      $sequence = <IN>;
      chomp($sequence);
      $qualname = <IN>;
      $qualname =~ s/[\+\n]//g;
      $quality = <IN>;
      chomp($quality);
    if ($debug) {
        print "sequence: '$sequence'\n";
        print "quality:  '$quality'\n";
    }
      
      
      if ($sequence =~ /^$adapterseq/) {
      
        print "seqname:\t'$seqname'\nsequence:\t'$sequence'\nqualname:\t'$qualname'\nquality:\t'$quality'\n\n" if ($debug);
        
        $sequence =~ s/$adapterseq//;
        $quality = substr($quality,length($adapterseq));

        if ($notwoadapters) {
            #next if (!$printall && $sequence =~ /$adapterseq/);
            #next if (!$printall && (index($sequence,$adapterseq) >= 0));
            if (index($sequence,$adapterseq) >= 0) {
                print STDERR "\@$seqname\n$sequence\n\+$seqname\n$quality\n" if ($id2adapters);
                next;
            }
        }

#        $quality = substr($quality,length($adapterseq));
        print "seqname:\t'$seqname'\nsequence:\t'$sequence'\nqualname:\t'$qualname'\nquality:\t'$quality'\n\n" if ($debug);
        
        print OUT "\@$seqname\n$sequence\n\+$seqname\n$quality\n"; 
        print ID "$seqname\n" if ($idlist);
      
      } elsif ($printall) {

        print OUT "\@$seqname\n$sequence\n\+$seqname\n$quality\n"; 
          
      } 
  
    }
  }

}


close(IN);
close(OUT);
close(ID) if ($idlist);