#! /bin/env perl
require 5.004;
my @test_links=();
my %the_circuit              = ();
use FindBin;    # New in Perl5.004
use Data::Dumper;
use List::Util qw/shuffle/;
require "/TODO/theCircuit.pm";
use File::Path qw( make_path );
use File::Spec;
my $dir_store="";
my @affected_gates=();
my @locked_gates=();
my $key_size=0;
my $locked_nets=0;
my $type_of_mux=2;
my $input_file="";
my $key_count=0;
my $code,$inputs,$outputs,$key_inputs="";
my $verbose=0;
my $assign_count=0;
my $dump=0;
my $first=1;
my $ml_count=0;
my $only_one=0;
my @functions=();
my %features_map=();

$features_map{"xor"}=3; 
$features_map{"xnor"}=4; 
$features_map{"and"}=5; 
$features_map{"or"}=6; 
$features_map{"nand"}=7; 
$features_map{"nor"}=8; 
$features_map{"not"}=9; 
$features_map{"buf"}=2; 
$features_map{"XOR"}=3; 
$features_map{"XNOR"}=4; 
$features_map{"AND"}=5; 
$features_map{"OR"}=6; 
$features_map{"NAND"}=7;
$features_map{"NOR"}=8;
$features_map{"NOT"}=9;
$features_map{"BUF"}=2;
$features_map{"PI"}=0;
$features_map{"PO"}=1; 
my $start_time               = time;

my ($rel_num)                = '$Revision: 1.7 $' =~ /\: ([\w\.\-]+) \$$/;
my ($rel_date) = '$Date: 2022/03/17 20:38:38 $' =~ /\: ([\d\/]+) /;
my $prog_name = $FindBin::Script;

my $hc_version = '0.1';

my $help_msg = <<HELP_MSG;
Random MUX Locking an Graph Conversion
Usage: $prog_name [options] verilog_file ...

    Options:	-h | -help		Display this info

		-v | -version		Display version & release date


                -i input file name      Input verilog gate level netlist file name

    Example:

    UNIX-SHELL> $prog_name -k 256  -i ../test_c7552/ > log.txt


HELP_MSG

format INFO_MSG =
     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     $prog_name
     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     "Version $rel_num  Released on $rel_date"
     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     'Lilas Alrahis <lma387@nyu.edu>'
     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     'NYU Abu Dhabi, Abu Dhabi, UAE'

     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     "\'$prog_name -help\' for help"

.

use subs
  qw(PrintWarning PrintError PrintFatalError PrintInternalError PrintDebug);

my $error            = 0;

my $input_dir;
my $comment = 0;
while ( $_ = $ARGV[0], /^-/ ) {              # Get command line options
    shift;
    if (/^-h(elp)?$/) { $~ = "INFO_MSG"; write; print $help_msg; exit 0 }
    elsif (/^-v(ersion)?$/) { print "$prog_name $rel_num $rel_date\n"; exit 0 }
    elsif (/^-k(ey)?$/)   { $key_size         = shift; }
    elsif (/^-c(omment)?$/)   { $comment          = 1; }
    elsif (/^-m(ux)?$/)   { $type_of_mux         = shift; }
    elsif (/^-dum(p)?$/)     { $dump       = 1; }
    elsif (/^-i(nput)?$/)     { $input_dir       = shift; }
    elsif (/^-ver(bose)?$/)     { $verbose       = 1; }
    elsif (/^-debug$/)        { $debug            = 1 }        # Hidden option
    else                      { PrintError "Unknown option: '$_'!" }
}

if ( !( defined($input_dir) ) ) {
    PrintError "Expect an input Bench file!";
}



if ( $error > 0 ) {
    warn "\n$help_msg";
    exit 1;
}

select( ( select(STDERR), $~ = "INFO_MSG" )[0] ), write STDERR;
my $status = 0;

opendir my $dh, $input_dir or die "Cannot open $input_dir: $!";
my @input_files = sort grep { ! -d } readdir $dh;
closedir $dh;
foreach  $input_file (@input_files) {
$first=1;
next if ($input_file=~m/^\./);
my $short_name=$input_file;
$short_name=~s/\.bench//g;
$dir_store="../../data/${short_name}_MUX_K${key_size}";
system("mkdir -p $dir_store");
open (fh, ">", $dir_store.'/locked_MUX_'.$type_of_mux.'_K_'.$key_size.'_'.$short_name.'.bench');
my @list_of_gates=();
my %Netlist_Outputs_Hash =();
my %Netlist_Inputs_Hash=();
my $line                = "";
my @Netlist_Inputs      = ();
my @Netlist_Outputs     = ();
my @Module_Inputs      = ();
my @Module_Outputs     = ();


local *INPUT_FH;     # Only way to declare a non-global filehandler.

my $filename_cell = $dir_store.'/cell.txt';
my $filename_count=$dir_store."/count.txt";
open(FH_LINK_TEST_NEG, '>', $dir_store.'/link_test_n.txt') or die $!;
open(FH_LINKS_TRAIN, '>', $dir_store."/links_train.txt") or die $!;
open(FH_LINKS_TEST, '>', $dir_store."/links_test.txt") or die $!;
open(FH_CELL, '>', $filename_cell) or die $!;
open(FH_COUNT, '>', $filename_count) or die $!;
my $filename_feat = $dir_store.'/feat.txt';
open(FH_FEAT, '>', $filename_feat) or die $!;
open INPUT_FH, "${input_dir}/${input_file}"
      or PrintFatalError "Can't open input file '$input_file': $!!";

#READING THE INPUT FILE
 while (<INPUT_FH>) {
        $line = $_;

        if ( $line =~ /^\s*INPUT\((\w*)\)\s?$/ ) {    #############check inputs
my $found_inputs=$1;
if ($verbose==1){
print "This is the found input $found_inputs\n";}
                push @Module_Inputs, $found_inputs;
        }

        elsif ( $line =~/^\s*OUTPUT\((\w*)\)\s?$/ ) {    #############check outputs
my $found_outputs=$1;

                push @Module_Outputs,   $found_outputs;

            }
elsif ($line=~/^\s*(\w+)\s+\=\s+(\w+)\(\s*(\w+)\s*\)/){
my $out=$1;
my $func=$2;
my $in=$3;
if ($verbose==1){
print "Detected one in is $in and func is $func and out is $out\n";}
if ($first==1){
@Netlist_Inputs=@Module_Inputs  ;   
@Netlist_Outputs= @Module_Outputs ; 
   
    %Netlist_Outputs_Hash = map { $_ => 1 } @Netlist_Outputs;
     %Netlist_Inputs_Hash  = map { $_ => 1 } @Netlist_Inputs;

				$first=2;
				}

my $modified_name="assign_${assign_count}_${out}";
my $current_object;
push @list_of_gates,$modified_name;
my @current_gate_inputs=();
push @current_gate_inputs, $in;
my @current_gate_outputs=();
push @current_gate_outputs, $out;
my $valv=0;
if ($func=~/NOT|not/)
{
#	print "It is an INV\n";
	$valv=1;
}
elsif ($func=~/BUF|buf/){
#	print "It is a BUF\n";
	$valv=1;	
	
}





                    $current_object = theCircuit->new(
                        {	
                            name          => $modified_name, #$instance_name,
                            bool_func     => $func,
                            inputs        => \@current_gate_inputs,
                            outputs        => \@current_gate_outputs,
                            fwdgates => [undef],
			    processed => $valv,
                            fwdgates_inst => [undef],
                            count =>$ml_count,
                        }
                    );
			my $indicator=0;
	 	foreach my $current_gate_output (@current_gate_outputs){
					my @temp=();
					my @temp_inst=();
                    if ( exists( $Netlist_Outputs_Hash{$current_gate_output} ) )
                    { #print "It is a PO\n";
					if ($indicator==0){
                    push @temp, "PO";
                    
                    push @temp_inst, $current_gate_output;
					}
					else{
					@temp=$current_object->get_fwdgates();
					@temp_inst=$current_object->get_fwdgates_inst();
					push @temp, "PO";
                    
                    push @temp_inst, $current_gate_output;
					}
					$indicator++;
					
                      $current_object->set_fwdgates(\@temp);
                      $current_object->set_fwdgates_inst(\@temp_inst);

                      $the_circuit{$modified_name} = $current_object;
                    }
					}
                                    $the_circuit{$modified_name} = $current_object;
$ml_count++;
$assign_count++;
}

elsif ($line=~/^\s*(\w+)\s+\=\s+(\w+)\((.+)\)/){
my $out=$1;
my $func=$2;
my $ins=$3;

my @current_gate_inputs=();
if ($verbose==1){
print "Detected in is $ins and func is $func and out is $out with count $assign_count\n";
} 
 my @inss = split(/,/,$ins);

my $valv=0;
my $count_inputs=0;
if ($first==1){
									@Netlist_Inputs=@Module_Inputs  ;   
@Netlist_Outputs= @Module_Outputs ; 
    %Netlist_Outputs_Hash = map { $_ => 1 } @Netlist_Outputs;
     %Netlist_Inputs_Hash  = map { $_ => 1 } @Netlist_Inputs;

				$first=2;
				}


foreach my $in (@inss){
$in=~ s/^\s+|\s+$//g;
chomp($in);
$count_inputs++;
if ($verbose==1){
print "This is individual $in\n";}

push @current_gate_inputs, $in;
if ($count_inputs>2){$valv=1;}

}
if ($verbose==1){
print "Those are the inputs @current_gate_inputs\n";}

my $modified_name="assign_${assign_count}_${out}";
push @list_of_gates,$modified_name;
my $current_object;
my @current_gate_outputs=();
push @current_gate_outputs, $out;


                    $current_object = theCircuit->new(
                        {	
                            name          => $modified_name, #$instance_name,
                            bool_func     => $func,
                            inputs        => \@current_gate_inputs,
                            outputs        => \@current_gate_outputs,
                            fwdgates => [undef],
			    processed => $valv,
                            fwdgates_inst => [undef],
                            count =>$ml_count,
                        }
                    );
			my $indicator=0;
	 	foreach my $current_gate_output (@current_gate_outputs){
					my @temp=();
					my @temp_inst=();
                    if ( exists( $Netlist_Outputs_Hash{$current_gate_output} ) )
                    { #print "It is a PO\n";
					if ($indicator==0){
                    push @temp, "PO";
                    
                    push @temp_inst, $current_gate_output;
					}
					else{
					@temp=$current_object->get_fwdgates();
					@temp_inst=$current_object->get_fwdgates_inst();
					push @temp, "PO";
                    
                    push @temp_inst, $current_gate_output;
					}
					$indicator++;
					
                      $current_object->set_fwdgates(\@temp);
                      $current_object->set_fwdgates_inst(\@temp_inst);

                                    $the_circuit{$modified_name} = $current_object;
                    }
					}
                                    $the_circuit{$modified_name} = $current_object;
$ml_count++;
$assign_count++;
}
      }


        #######end of opening file again
    close INPUT_FH;
    ############################

 
foreach my $object ( values %the_circuit ) {  ##### loop through the gates
my $name="";
$name= $object->get_name();
if ($verbose==1){
print "the name is $name\n";}
my @current_inputss=$object->get_inputs();
if ($verbose==1){
print "the inputs are @current_inputss\n"; }


my $limit=0;
$limit=@current_inputss;
my @current_inputs=();
my @current_gate_inputs=();
my @current_gate_inputs_inst=();
if ($verbose==1){
print "original limit is $limit\n";}
my $outer_gate_type=$object->get_bool_func();

for my $i_index (0 .. $#current_inputss)
{
my $in=   $current_inputss[$i_index];

if ( exists( $Netlist_Inputs_Hash{$in} ) )
 {	
 
	if ($verbose==1){ print "Input $in is a PI\n";}
 push @current_gate_inputs, "PI";
 push @current_gate_inputs_inst,$in;
 $limit--;	
}#end if it is a PI
else{
if ($verbose==1){	print "Input $in is not a PI\n";}
push @current_inputs, $in;	
}#end if it is not a PI
}# end of looping through the inputs


 if ($limit!=0){ #if my input array is not empty
OUTER: 
foreach my $instance (@list_of_gates)
  {
		   my $current_objectt ="";
		   my @current_outputs=();
	
                   $current_objectt = $the_circuit{$instance};
	  @current_outputs= $current_objectt->get_outputs();
		   my $current_gate_type="";
		   
               
                   
                   $current_gate_type=$current_objectt->get_bool_func();

		   foreach my $current_output (@current_outputs){
		                      foreach my $input (@current_inputs)
                   {

                   if ($input eq $current_output)
                   { if ($verbose==1){print "found a match from isnatnce $instance with output $current_output that matches my input $input\n";
                   }
				   push @current_gate_inputs, $current_gate_type;
                   push @current_gate_inputs_inst, $instance;
                   my @temp=();
                   my @temp_inst=();
                    if ($current_objectt->get_fwdgates()){
                   @temp=$current_objectt->get_fwdgates();
                   @temp_inst=$current_objectt->get_fwdgates_inst();
                   }
                   push @temp, $outer_gate_type;
                   push @temp_inst, $name;
                   @temp = grep defined, @temp;
                   @temp_inst = grep defined, @temp_inst;
                    $current_objectt->set_fwdgates(\@temp);
                    $current_objectt->set_fwdgates_inst(\@temp_inst);
     
                       $the_circuit{ $instance } = $current_objectt;
                   }#the input is a primary output of a gate
                   
                   }
}
}
}#end if my input array is not empty
$object->set_fedbygates(\@current_gate_inputs);

$object->set_fedbygates_inst(\@current_gate_inputs_inst);
  $the_circuit{ $name } = $object;
  
}#end of the outer loop through the gates
my @shuffled_indexes = shuffle(0..$#list_of_gates);

# Get just N of them.
my $num_picks=$key_size*($type_of_mux-1);
my @pick_indexes = @shuffled_indexes[ 0 .. $num_picks - 1 ];  
#
# # Pick cards from @deck
my @picks = @list_of_gates[ @pick_indexes ];	
#print "Those are the selected false wires @picks\n";
my %params = map { $_ => 1 } @picks;
foreach my $object ( values %the_circuit ) {  ##### loop through the gates
if ($locked_nets<$key_size){

my $lock_count=$object->get_count();
my $lock_gate=$object->get_name();
if(exists($params{$lock_gate})) { print"This gate is in false wires $lock_gate\n"; next; }
    if ($lock_gate=~m/assign\_(\d+)\_(\S+)$/){
        my $gate_type=$object->get_bool_func();
        my @next_gates=$object->get_fwdgates_inst();
        my %params_assumption = map { $_ => 1 } @affected_gates;
        my $yes_next=0;
        my @temp_push=();
        foreach my $elem (@next_gates){
        push @temp_push, $elem;
        if(exists($params_assumption{$elem})) { print "This gate is already affected $elem\n"; $yes_next=1; }
        }
        if ($yes_next==1){next;}
        else{
        push @affected_gates, @temp_push;
        }
        my @inputss=$object->get_inputs();
        my $out_string2=$1;
        my $out_string=$2;
        push @locked_gates, $out_string;
        my $false_gate=$picks[$locked_nets];
        my $false_count=0;
        my $false_wire="";
        if ($false_gate=~m/assign\_(\d+)\_(\S+)$/){
             $false_count=$1;
             $false_wire=$2;
            }
        if ($type_of_mux==2){
            $code.="${out_string}_to_mux = $gate_type(";
            my $end=@inputss;
            my $i=0;
            foreach my $input (@inputss){
                if ($i<($end-1)){
                    $code.="$input, ";}
                else{$code.="$input)\n";} 
                $i++;
            }
            $key_inputs.="INPUT(keyinput${locked_nets})\n";
            $code.="${out_string}= MUX(keyinput${locked_nets}, ${out_string}_to_mux, $false_wire)\n";
            my @current_fwd_gates=();
            foreach my $elem (@next_gates){
                if (exists ($the_circuit{$elem}))  {
                    my $current_ob=$the_circuit{$elem};
                    my $current_count=$current_ob->get_count();
                    print FH_LINKS_TEST "$lock_count $current_count\n";
                    print FH_LINK_TEST_NEG "$false_count $current_count\n";
}
}
            }
        else {#TODO for MUX4
             }
        }
$locked_nets++;
}else {last;}


}
print fh $key_inputs;
open INPUT_FH, "${input_dir}/${input_file}"
      or PrintFatalError "Can't open input file '$input_file': $!!";
 while (<INPUT_FH>) {
	
	  my $line = $_;
	  chomp($line);
          my $flago=0;
	  foreach my $checkingg (@locked_gates){
		if ($line=~/^\s*$checkingg\s*\=/){
$flago=1;

		}	
	  }
if ($flago==0){		
		print fh "$line\n";
}

	  }
	  
 
close INPUT_FH;
  print fh $code;
  close fh;

$graph=1;
if ($graph==1){
foreach my $object ( values %the_circuit ) {  ##### loop through the gates
my @OUts=$object->get_fwdgates();
my @features_array=(0) x 10;#34;#22;
my $prev=$features_array[$features_map{$object->get_bool_func()}];
$features_array[$features_map{$object->get_bool_func()}]=($prev+1);
my @INputs=$object->get_fedbygates();
my @current_fed_gates=();
@current_fed_gates=$object->get_fedbygates_inst();
my %params = map { $_ => 1 } @INputs;
if(exists($params{"PI"})) { 
my $prev=0;
$features_array[$features_map{"PI"}]=($prev+1);
 }
my $name="";
$name= $object->get_name();
my $count=$object->get_count();
my @current_fwd_gates=();
@current_fwd_gates=$object->get_fwdgates_inst();
foreach my $elem (@current_fwd_gates){
if (exists ($the_circuit{$elem}))  {
my $current_ob=$the_circuit{$elem};
my $current_count=$current_ob->get_count();
my $inputt=$current_ob->get_bool_func();
my @INNputs=$current_ob->get_fwdgates();

print FH_LINKS_TRAIN "$count $current_count\n";
}
}
%params=();
%params = map { $_ => 1 } @OUts;
if(exists($params{"PO"})) {
$features_array[$features_map{"PO"}]=1;
}
print FH_CELL "$count $name from file $input_file\n";
print FH_COUNT "$count\n";
print FH_FEAT "@features_array\n";
}#end of the outer loop through the gates
}
}#end if check if i want to create a graph or not
close(FH_LINKS_TEST);
close(FH_LINKS_TRAIN);
close(FH_LINK_TEST_NEG);
system("grep -Fvx -f ${dir_store}/links_test.txt ${dir_store}/links_train.txt > ${dir_store}/remaining.txt && mv ${dir_store}/remaining.txt ${dir_store}/links_train.txt");
close(FH_FEAT);
close(FH_CELL);
close(FH_COUNT);
my $run_time = time - $start_time;
print STDERR "\nProgram completed in $run_time sec ";

if ($error) {
    print STDERR "with total $error errors.\n\n" and $status = 1;
}
else {
    print STDERR "without error.\n\n";
}

exit $status;
sub write_sw{
	my ($input1,$input2,$ex1,$ex2,$key0,$key1,$key2,$output1,$output2,$inst,$f1,$f2)=@_;
    $key_inputs.="INPUT(".$key0.")\n";
    $key_inputs.="INPUT(".$key1.")\n";
    
    $key_inputs.="INPUT(".$key2.")\n";
    $code.="mux1_".$inst."= mux(".$key0.", ".$input1.",".$input2.")\n";
    $code.="f1_".$inst."= ${f1}(mux1_".$inst.", ${ex1})\n";
    $code.="mux2_".$inst."= mux(".$key0.", ".$input2.",".$input1.")\n";
    $code.="f2_".$inst."= ${f2}(mux2_".$inst.", ${ex2})\n";
    $code.=$output1."= mux(".$key1.", f1_".$inst.", mux2_".$inst.")\n";
    $code.=$output2."= mux(".$key2.", mux1_".$inst.", f2_".$inst.")\n";
}

sub log_base {
    my ($base, $value) = @_;
    return log($value)/log($base);
}
sub PrintWarning {
    warn "WARNING: @_\a\n";
}

sub PrintError {
    ++$error;
    warn "ERROR: @_\a\n";
}

sub PrintFatalError {
    ++$error;
    die "FATAL ERROR: @_\a\n";
}

sub PrintInternalError {
    ++$error;
    die "INTERNAL ERROR: ", (caller)[2], ": @_\a\n";
}
sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}
sub PrintDebug {
    my $orig_list_separator = $";
    $" =
      ',';   # To print with separator, @some_list must be outside double-quotes
    warn "DEBUG: ", (caller)[2], ": @_\n" if ($debug);
    $" = $orig_list_separator;    # Dummy " for perl-mode in Emacs
}



__END__

