#! /usr/bin/perl
use strict;
use warnings;

my @wrong_keys=();
my @correct_keys=();
my $file_name=$ARGV[0];
my $th=0;
my $upper=0;
my %connect_from=();
my %connect_to=();
my %seen_correct=();
my %connect_from_correct=();
my %connect_to_correct=();
my %links=();
my @corrects=();
my @wrongs=();
my @maybe_corrects=();
open (FH,'<', "./data/${file_name}/links_test.txt") or die $!;
while (<FH>){
my $line= $_;
my @columns=split(/\s+/,$line);
push @{$connect_from_correct{$columns[0]}}, $columns[0]." ".$columns[1];
print "WARNING Exists for $columns[1]\n"    if exists $connect_to_correct{$columns[1]};
$connect_to_correct{$columns[1]}=$columns[0]." ".$columns[1];
}
close(FH);
open (FH,'<', "./data/${file_name}/link_test_n_2__pred.txt") or die $!;
while (<FH>){
my $line= $_;
my @columns=split(/\s+/,$line);
$links{$columns[1]}=$columns[2];

$connect_to{$columns[1]}=$columns[0]." ".$columns[1];
push @{$connect_from{$columns[0]}}, $columns[0]." ".$columns[1];
}

close(FH);
my $correct=0;
my $wrong=0;
my $tie=0;
open (FH,'<', "./data/${file_name}/links_test_2__pred.txt") or die $!;
while (<FH>){
my $line= $_;
my @columns=split(/\s+/,$line);
my $val=$links{$columns[1]};
if ($val<$columns[2])
{
my $diff=$columns[2]-$val;
if ($columns[2]>=$upper && $diff>$th){
	#print "Correct $line";
push @correct_keys, $columns[0];
push @corrects, $columns[0]." ".$columns[1] ;
my @other_corrects=@{$connect_from_correct{$columns[0]}};
foreach my $correct_found (@other_corrects){
	#print "Which makes $correct_found also correct\n";
push @corrects, $correct_found;

}
if (exists($connect_to{$columns[1]})){
	#print "A connection to $columns[1] was made wrong and removing $connect_to{$columns[1]}\n";
push @wrongs, $connect_to{$columns[1]};
my @checks=();
my $check=$connect_to{$columns[1]};
@checks=split(/\s+/,$check);
my @other_wrongs=@{$connect_from{$checks[0]}};
foreach my $wrong_found (@other_wrongs){
	#print "Which makes $wrong_found wrong\n";
push @wrongs, $wrong_found;

}


}
$correct=$correct+1;
}
}
elsif($val>$columns[2]){

my $diff=$val-$columns[2];
if($val>=$upper && $diff>$th){
push @wrong_keys, $columns[0];
push @maybe_corrects, $connect_to{$columns[1]}; 
$wrong=$wrong+1;}
}
else{
$tie=$tie+1;
}

}
@corrects=uniq(@corrects);
@wrongs=uniq(@wrongs);
@maybe_corrects=uniq(@maybe_corrects);
my %count=();
foreach my $element (@wrongs, @maybe_corrects){$count{$element}++}
my $length=@corrects;
close(FH);

@wrong_keys=uniq(@wrong_keys);
my $wrong_key=@wrong_keys;
@correct_keys=uniq(@correct_keys);
my $correct_key=@correct_keys;
my @union=();
my @isect=();
my %union=();
my %isect=();

foreach my $e (@correct_keys) { $union{$e} = 1 }

foreach my $e (@wrong_keys) {
    if ( $union{$e} ) { $isect{$e} = 1 }
    $union{$e} = 1;
}
@union = keys %union;
@isect = keys %isect;
my $conflict_length=@isect;

print "Correct key-bits: $correct_key, wrong keys are: $wrong_key. Undeciphered are $conflict_length\n";
print "Correct connections are $correct, wrong connections are $wrong and tie are $tie\n";
sub uniq{
my %seen;
grep !$seen{$_}++,@_;

}
