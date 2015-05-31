#!/usr/bin/perl
#
#	Filename: genesis.pl Version 1.01.300
#	Description: This program accepts a Genesis program 
#		and generates instance programs.
#

use warnings; use strict;

use Scalar::Util qw(looks_like_number);
use File::Copy qw(move);
use File::Compare;
use POSIX;
use Time::HiRes qw/ time sleep /;


#This is needed when using genesis on Linux, maybe?
#$/ = "\r\n";

my $versionnumber = "1.01.300";

##?##?## REGEX SIMPLIFICATIONS ##?##?##
my $interegex= "\^\[\-\]\?\[\\d\]\*";
my $mathregex= "\\\+\\\-\\\*\\\/\\\(\\\)\\\.\\\%";
my $equaregex= "\\w\\\"\\\'$mathregex";
my $ineqregex= "!&\\\|><=\\s$equaregex";
my $referegex= "\\w\\\$\\\{\\\}\\\[\\\]";
my $generegex= "$equaregex$referegex";
my $refqregex= "$referegex$ineqregex";

##?##?## FILENAME VARIABLES ##?##?##
my $filename;   				#the filename of the Genesis program
my $filename2;					#the filename of the template program, if needed
my $outDir = "Gen";				#the directory to put the instance programs
my $outname1 = "gen";			#the format of the instance program 1
my $outname2 = ".c";			#the format of the instance program 2

my $libfilename = "varlist_c.lib";
my $dataoutfilename;			#Outputting the terminal info to a file, if needed
my $dataoutfile;				#the actual dataout handle

##?##?## TIMING VARIABLES ##?##?##
my $starttime = 0;
my $endtime = 0;

my $replacestarttime = 0;
my $replaceendtime = 0;

my $timeparse = 0;
my $timecreate = 0;
my $timereplace = 0;
my $timegen = 0;

##?##?## LINE TYPE COUNTERS ##?##?##
my $constructscount = 0;
my $distscount = 0;
my $valuescount = 0;
my $varlistscount = 0;
my $variablescount = 0;
my $storedscount = 0;
my $addscount = 0;
my $removescount = 0;
my $genmathscount = 0;
my $genassertscount = 0;
my $genifscount = 0;
my $genloopscount = 0;
my $codescount = 0;
my $linescount = 0;
my $replacecount = 0;
my $valreplacecount = 0;
my $varreplacecount = 0;
my $varlistreplacecount = 0;
my $storedreplacecount = 0;
my $featreplacecount = 0;
my $featargreplacecount = 0;
my $genifreplacecount = 0;
my $genloopreplacecount = 0;
my $genloopvarreplacecount = 0;


##?##?## USER INPUTTED FLAGS ##?##?##
my $timingflag = 0;
my $ignorevertspaceflag = 0;		#ignore vertical spacing
my $generateflag = 1; 				#generate at all vs just parse
my $printintroflag = 1;
my $printParsingflag = 2;			#print information during parsing
my $printGenerateflag = 2;			#print information during generation
my $printGlobalcountersflag = 0;	#print global counters of values at the end
my $printerrorsflag = 1;
my $chisquaredtestflag = 0;			#print chi-squared information
my $dtestflag = 0;					#print d information
my $emptyvarlistactionflag = 1;		#control the action when varlist is empty
my $headercommentsflag = 0;			#allow any line in header outside features
my $recursionflag = 0;				#allow feature recursion
my $headerflag = 0;					#make no assumptions about the 
my $referencecheck = 1;				#All references need to be fixed

my $printlocalcountersflag = 0; 	#$#protip: this is broken right now;

##?##?## CONTROL FLOW FLAGS ##?##?##
my $parsingflag = 1;		# Just tells if its parsing or generating
my $samplewarningflag = 0;	# Sampled at end of feature
my $checkoneheaderflag = 0; # A check there is one genesis header
my $badflag = 0;			# Warning redo flag
my $varlistinitflag = 0;	# Initializes the varlists
my $lastlevelflag = 1;		# for proper spacing
my $inagenifflag = 0;		# used for genif/genelsif/genelse
my $genifevaledflag = 0;	# used if a genif is taken
my $varinitflag = 0;		# if 1, init the variables
my $generatetouchflag = 1;  # if 1, touch vars at end
my $valuereportedflag = 0;  # if a value is reported, set to 1
my $distlineflag = 0;		# Helps with distribution removal
my $reportlineflag = 0;		# Adds "Sampled Values" line to header
my $equalWithoutGenmathFlag = 0;
my $referencereplaced = 1;

##?##?## STORAGE VARIABLES ##?##?##
my @globalcodelines;			# Storing the untouched global code lines
my @programcodelines;			# Storing the untouched program code lines
my @templateproglines;			# Storing the untouched target code lines

##?##?## FINAL FILE STORAGE VARIABLES ##?##?##
my @headertemplines;			# Storing the header lines for the final file
my @headerprogramtemplines;		# Storing the header prog lines for the final file 
my @templines;					# Storing the lines for the final file

##?##?## LIBRARY FILE STUFFS ##?##?##
my $reportcharacter = "//"; # Comment character based on instance program file type
my $librarycounter = 0;
my @librarylinename;
my @librarylinefind;
my @librarylinecancel;
my @librarylineactivate;
my @librarylinelocation;
my @librarylineadd;

##?##?## LINE PARSING STORAGE AND USE ##?##?##

##Genesis names
my @namesforlocality;			# List of distribution names for each depth

##Parameters pariter
#  evalflag 1: value name sample parametersdistvar
#  evalflag 0: value name = parametersequalvar
my @parametersnumber;			# Index Number
my @parameters;					# Name of the parameter
my @parametersfeature;			# If in a feature, the feature name
my @parametersdistvar;			# The distribution variable name
my @parametersequalpar;			# The equal parameter name
my @parametersevalflag;			# Eval or =
my @parametersfullflag;			# sample or enumerate
my @parametersreportflag;		# Value modifier: Reporting
my @parametersnoreplaceflag;	# Value modifier: Sampling Replacement
my @parametersarrayflag;		# If this is an array
my @parametersarraybrackets;

my @parameterscounters;			# Counter changes based on depth
my @parameterssampled;			# Sampled?
my @parametersglobalcounter;	# Global counts of values
#my @parametersstartcounter;	#$#protip: this is broken right now;
#my @parameterslocalcounter;	#$#protip: this is broken right now;
my @parametersrealflag;			# If it is a real value
my @parameterschisflag;			# Print the chi squared stats for this value

my @parametersglobalflag;		# Deprecated: Global flag

my @genmathdistvar;

##Varlists vliter
# evalflag 1: varlist varlistname[varlistarg]  <-- sampled varlistarg = distval
# evalflag 0: varlist varlistname = varlistequalvar
my @varlistname;				# Name of the Varlist
my @varlistvarname; 			# Name of the Varlist vars
my @varlistarg;					# The Value Varlist is based on
my @varlistequalvar;			# The equal parameter name
my @varlistevalflag;			# Eval or =
my @varlisttype;				# Varlist modifier: type
my @varlistinitvalue;			# Varlist modifier: init values
my @varlistinitallflag;			# Varlist modifier: initall value
my @varlistendtouch;			# Varlist modifier: endtouch flag

my @varlistvalidity;			# Tells which level the varlist is declared
my @varlistavailability;		# Tells which values in the varlist are available


##Variables variter
# evalflag 1: variable variables from variablesvarlistvar
# evalflag 0: variable variables = variablesequalpar
my @variablesnumber;			# Index Number
my @variables;					# Name of the variable
my @variablesfeature;			# If in a feature, the feature namey
my @variablesvarlistvar;		# Name of the varlist attached
my @variablesequalpar;			# The equal parameter name
my @variablesevalflag;			# Eval or =
my @variablesreportflag;		# Variable modifier: Reporting

my @variablescounters;			# counter changes based on depth

my @variablesglobalflag;		# Deprecated: Global flag


##AddVariables additer
my @addvariablesnumber;			# Index Number
my @addvariables;				# Name of the variable
my @addvariablesvarlistvar;		# Name of the varlist attached
my @addvariablesfeature;		# If in a feature, the feature name

##RemVariables remiter
my @remvariablesnumber;			# Index Number
my @remvariables;				# Name of the variable
my @remvariablesvarlistvar;		# Name of the varlist attached
my @remvariablesfeature;		# If in a feature, the feature name

##Distributions disiter
my @globaldistributions;		# Distributions declared on its own line
my @localdistributions;			# Distributions declared with values = {}
my @distvalidlocality;			# Number indicating which dist index valid at depth

my @distributions;				# Name of the distribution during processing
my @distributionsvalues;		# List of all the values during processing
my @distributionsprob;			# List of all the probabilities during processing
my @distributionsreal;			# If real, how many decimals

##Features feaiter
my @features;					# List of all the feature names
my @featureslist;				# What the feature consists of (the definition)
my @featuresparams;				# List of parameters in declaration
my @featuressinglelineflag; 	# Variable modifier: Reporting

my @featuresparameterlist;		# Stores the parameters passed in during processing
my @featuresparamsvalid;		# Tells that the list is valid
my @featuresvalid;				# Inside a feature. Used to test recursion

my @storednumber;				# Index Number
my @stored;						# Stored feature name
my @storedvar;					# Which feature it is processing from
my @storedfeature;				# Where this is declared (the scope)
my @storedsampled;				# Sampled?

my @storedprocessed;			# Code after it is processed

my @storedglobalflag;			# Deprecated: Global flag	

my $globalexistsflag = 0;		# A global section exists
my @globalenum;					# Which lines have enumerated values
my @globaldist;				# Which lines have distributions
my @globalreport;				# Which lines have reported values
my @globalnames;

my $programexistsflag = 0;		# A program section exists
my @programenum;				# Which lines have enumerated values
my @programdist;				# Which lines have distributions
my @programreport;				# Which lines have reported values
my @programnames;

#genifs
my @genifid;					# Index Number
my @genifinequality;			# Associated variable/inequality
my @geniffeature;				# Which function it is in
my @geniftype;					# Genif, genelsif or genelse
my @geniflist;					# The contents of the genif

#genloops
my @genloopid;					# Index Number
my @genloopvar;					# The loop iterator
my @genloopstart;				# Start value
my @genloopend;					# End value
my @genloopstride;				# Increment
my @genloopinequality;			# Genloop type 2: the inequality
my @genloopvalid;				# Inside a feature. Used to allow loop iterator replacement
my @genloopfeature;				# Which function it is in
my @genlooplist;				# The contents of the genloop

my @genloopvalue;				# Current loop iterator value during processing

#generates
my @generates;					# Number to generate
my @gendistribute;				# Distributions for each generate line
my @gentouch;					# Notouch modifier

##?##?## PARSING FLOW ##?##?##
## counters 
my $linenumber = 0;				# Line number while parsing file
my $valuecounter = 0;			# Current number of Values
my $varlistcounter = 0;			# Current number of Varlists
my $variablecounter = 0;		# Current number of Variables
my $storedcounter = 0;			# Current number of Stored Features
my $addcounter = 0;				# Current number of Adds
my $remcounter = 0;				# Current number of Removes
my $genloopcounter = 0;			# Current number of Genloops
my $genifcounter = 0;			# Current number of Genifs
my $noreplacementcounter = 0;	# Current number of Values with the noreplacement modifier
my $generatecounter = 0;		# Current number of Generates
my $warningcounter = 0;			# Current number of warnings generated
my $setcounter = 0;				# Current number of sets generated
my $dotcounter = 10;			# Output dot counter
my $foldercounter = 1;			# Folder counter

#Parsing variables
my $currentfeature = "";		# Current feature
my @currentgens;				# depth based thing inside brackets
my @currentbracket;				# Things after "genloop"
my @brackettype;				# genif, genloop, etc
my $parsebracketcounter = -1;		# To determine locations of vars
my $genbracketcounter = -1;

##?##?## GENERATING FLOW ##?##?##
my $numtoenumerate = 0;			# Number of enum instances per gen
my $duplicatecounter = 0;		# Counts dups for "too many dup file" warning
my @errorlist;					# Iteration (set) that caused errors 1
my @errorlist2;					# Iteration (enumerate) that caused errors 2
my @warninglist;				# List of warnings

my $currentdepth = 0;			# current depth
my @currentindent;				# spacing changes on depth
$currentindent[0] = "";			# initial state for lineindenting

my @insingleline;
$insingleline[0] = 0;

my $currentreplace = 0;			# check the id for sampling already
my @sampledalready;				# sampled already for noreplace	

##?##?## COMMAND LINE ARGUMENTS ##?##?##

##Varlist arguments
# Name, Doubles counter(set to 0), Duplicate error, Bad value error, Number of possible values, Possible value #1, Possible value #2...
my @varlistarguments = (
["init",     0, "AN", "CB", 0, "Any charstring"],
["initall",  0, "AO", "CC", 0, "Any charstring"],
["type",     0, "AM", "CA", 0, "Any charstring"],
["name",     0, "FB", "FC", 0, "Any charstring"],
["endtouch", 0, "AP", "CD", 2, "1", "0"]
);

##Varlist argument set functions
my %varlistchange = (
 "init"        => sub { $varlistinitvalue[scalar @varlistinitvalue -1] = $_[0]; },
 "initall"     => sub { $varlistinitvalue[scalar @varlistinitvalue -1] = $_[0]; $varlistinitallflag[scalar @varlistinitallflag -1] = 1;},
 "type"        => sub { $varlisttype[scalar @varlisttype -1] = $_[0]; },
 "name"        => sub { $varlistvarname[scalar @varlistvarname -1] = $_[0]; },
 "endtouch"    => sub { $varlistendtouch[scalar @varlistendtouch -1] = $_[0]; }
);

##Value arguments
# Name, Doubles counter(set to 0), Duplicate error, Bad value error, Number of possible values, Possible value #1, Possible value #2...
my @valuearguments = (
["report",        0, "AQ", "CE", 2, "1", "0"],
["noreplacement", 0, "AR", "CF", 2, "1", "0"]
);

##Value argument set functions
my %valuechange = (
 "report"        => sub { $parametersreportflag[scalar @parametersreportflag-1] = $_[0]; if ($_[0] eq "1") {$reportlineflag = 1;}},
 "noreplacement" => sub { if ($_[0] eq "1") {$parametersnoreplaceflag[scalar @parametersnoreplaceflag-1] = $noreplacementcounter;} else {$parametersnoreplaceflag[scalar @parametersnoreplaceflag-1] = 0;} }
);

##Variable arguments
# Name, Doubles counter(set to 0), Duplicate error, Bad value error, Number of possible values, Possible value #1, Possible value #2...
my @vararguments = (
["report", 0, "BC", "CG", 2, "1", "0"]
);

##Variable argument set functions
my %varchange = (
 "report"  => sub { $variablesreportflag[scalar @variablesreportflag-1] = $_[0]; if ($_[0] eq "1") {$reportlineflag = 1;}}
);

##Feature arguments
# Name, Doubles counter(set to 0), Duplicate error, Bad value error, Number of possible values, Possible value #1, Possible value #2...
my @featurearguments = (
["singleline", 0, "AS", "CH", 2, "1", "0"]
);

##Feature argument set functions
my %featurechange = (
 "singleline"        => sub { $featuressinglelineflag[scalar @featuressinglelineflag-1] = $_[0]; }
);

##Command line arguments
# Name, Doubles counter(set to 0), Duplicate error, Bad value error, Number of possible values, Possible value #1, Possible value #2...
my @commandlinearguments = (
["dataoutfile",     0, "EC", "ED", 0, "Any Charstring"],
["outfile",         0, "EE", "EF", -1],
["outdir",          0, "EG", "EH", 0, "Any Charstring"],
["ignorevertspace", 0, "EI", "EJ", 2, "0", "1"],
["generate",        0, "EK", "EL", 2, "1", "0"],
["printParsing",    0, "EM", "EN", 4, "2", "1", "3", "0"],
["printGenerate",   0, "EW", "EX", 4, "2", "1", "3", "0"],
["globalcounters",  0, "EQ", "ER", 2, "0", "1"],
["chisquared",      0, "EU", "EV", 2, "0", "1"],
["headercomments",  0, "EY", "EZ", 2, "0", "1"],
["recursion",       0, "ES", "ET", 2, "1", "0"],
["header",          0, "FA", "DB", 2, "1", "0"],
["seed",            0, "EO", "EP", 0, "a number"]
);

##Command line argument set functions
my %commandlinechange = (
  "dataoutfile"     => sub { $dataoutfilename = $_[0]; },
  "outdir"          => sub { $outDir = $_[0]; },
  "outfile"         => sub { $outname1 = $_[0]; $outname2 = $_[1]; },
  "ignorevertspace" => sub { $ignorevertspaceflag = $_[0]; },
  "generate"        => sub { $generateflag = $_[0]; },
  "printParsing"    => sub { $printParsingflag = $_[0]; },
  "printGenerate"   => sub { $printGenerateflag = $_[0]; },
  "globalcounters"  => sub { $printGlobalcountersflag = $_[0]; },
  "localcounters"   => sub { $printlocalcountersflag = $_[0]; },
  "chisquared"      => sub { $chisquaredtestflag = $_[0]; },
  "headercomments"  => sub { $headercommentsflag = $_[0]; },
  "recursion"       => sub { $recursionflag = $_[0]; },
  "header"          => sub { $headerflag = $_[0]; },
  "seed"            => sub { srand($_[0]); }
);

##?##?## CHI SQUARED VALUE ##?##?##
my @chisquared;				# Calculated chi-squared value for each Gen Value
my @confidenceindex;		# Alpha value for each Gen Value
my @dValue;					# D-value, a different test

##Possible alpha values
my @chisquaredlookupalpha = (100,99,98,97,96,95,94,93,92,91,90,89,88,87,86,85,84,83,82,81,80,79,78,77,76,75,74,73,72,71,70,69,68,67,66,65,64,63,62,61,60,59,58,57,56,55,54,53,52,51,50,49,48,47,46,45,44,43,42,41,40,39,38,37,36,35,34,33,32,31,30,29,28,27,26,25,24,23,22,21,20,19,18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0);

##Lookup table
# Sorted by: 
# Each row is a degree of freedom (1d 1st row, 2d 2nd row, etc, up to 200 degrees)
# Each column corresponds to an alpha value (0 to 99, 100 would be infinite)
my @chisquaredlookup = ([0,0.00015709,0.00062845,0.0014144,0.0025154,0.0039321,0.0056656,0.0077167,0.010087,0.012778,0.015791,0.019128,0.022792,0.026784,0.031108,0.035766,0.040761,0.046097,0.051777,0.057805,0.064185,0.070921,0.078019,0.085483,0.093319,0.10153,0.11013,0.11911,0.12849,0.13828,0.14847,0.15909,0.17013,0.18160,0.19352,0.20590,0.21874,0.23206,0.24587,0.26017,0.27500,0.29034,0.30623,0.32268,0.33970,0.35732,0.37554,0.39439,0.41389,0.43407,0.45494,0.47653,0.49886,0.52198,0.54589,0.57065,0.59628,0.62282,0.65032,0.67880,0.70833,0.73894,0.77070,0.80366,0.83789,0.87346,0.91043,0.94890,0.98895,1.0307,1.0742,1.1196,1.1671,1.2167,1.2688,1.3233,1.3806,1.4409,1.5044,1.5714,1.6424,1.7176,1.7976,1.8829,1.9742,2.0723,2.1780,2.2925,2.4173,2.5542,2.7055,2.8744,3.0649,3.2830,3.5374,3.8415,4.2179,4.7093,5.4119,6.6349],
[0,0.020101,0.040405,0.060918,0.081644,0.10259,0.12375,0.14514,0.16676,0.18862,0.21072,0.23307,0.25567,0.27852,0.30165,0.32504,0.34871,0.37266,0.39690,0.42144,0.44629,0.47144,0.49692,0.52273,0.54887,0.57536,0.60221,0.62942,0.65701,0.68498,0.71335,0.74213,0.77132,0.80096,0.83103,0.86157,0.89257,0.92407,0.95607,0.98859,1.0217,1.0553,1.0895,1.1242,1.1596,1.1957,1.2324,1.2698,1.3079,1.3467,1.3863,1.4267,1.4679,1.5100,1.5531,1.5970,1.6420,1.6879,1.7350,1.7832,1.8326,1.8832,1.9352,1.9885,2.0433,2.0996,2.1576,2.2173,2.2789,2.3424,2.4079,2.4757,2.5459,2.6187,2.6941,2.7726,2.8542,2.9394,3.0283,3.1213,3.2189,3.3215,3.4296,3.5439,3.6652,3.7942,3.9322,4.0804,4.2405,4.4145,4.6052,4.8159,5.0515,5.3185,5.6268,5.9915,6.4378,7.0131,7.8240,9.2103],
[0,0.11483,0.18483,0.24510,0.30015,0.35185,0.40117,0.44874,0.49495,0.54009,0.58438,0.62797,0.67101,0.71361,0.75583,0.79777,0.83949,0.88104,0.92248,0.96384,1.0052,1.0465,1.0879,1.1293,1.1709,1.2125,1.2544,1.2963,1.3385,1.3810,1.4237,1.4666,1.5098,1.5534,1.5973,1.6416,1.6862,1.7313,1.7768,1.8227,1.8692,1.9161,1.9636,2.0116,2.0602,2.1095,2.1593,2.2099,2.2612,2.3132,2.3660,2.4196,2.4740,2.5294,2.5857,2.6430,2.7013,2.7608,2.8213,2.8831,2.9462,3.0106,3.0764,3.1437,3.2125,3.2831,3.3554,3.4297,3.5059,3.5842,3.6649,3.7479,3.8336,3.9221,4.0136,4.1083,4.2066,4.3087,4.4150,4.5258,4.6416,4.7630,4.8904,5.0247,5.1665,5.3171,5.4773,5.6489,5.8335,6.0333,6.2514,6.4915,6.7587,7.0603,7.4069,7.8147,8.3112,8.9473,9.8374,11.345],
[0,0.29711,0.42940,0.53505,0.62715,0.71072,0.78837,0.86163,0.93149,0.99865,1.0636,1.1268,1.1884,1.2488,1.3081,1.3665,1.4241,1.4810,1.5374,1.5933,1.6488,1.7040,1.7589,1.8136,1.8681,1.9226,1.9769,2.0313,2.0857,2.1402,2.1947,2.2494,2.3042,2.3593,2.4146,2.4701,2.5259,2.5821,2.6386,2.6955,2.7528,2.8106,2.8689,2.9277,2.9870,3.0469,3.1075,3.1687,3.2306,3.2933,3.3567,3.4209,3.4861,3.5521,3.6191,3.6871,3.7562,3.8265,3.8979,3.9706,4.0446,4.1201,4.1970,4.2755,4.3557,4.4377,4.5216,4.6074,4.6954,4.7857,4.8784,4.9738,5.0719,5.1730,5.2774,5.3853,5.4969,5.6127,5.7329,5.8581,5.9886,6.1251,6.2681,6.4185,6.5770,6.7449,6.9233,7.1137,7.3182,7.5390,7.7794,8.0434,8.3365,8.6664,9.0444,9.4877,10.026,10.712,11.668,13.277],
[0,0.55430,0.75189,0.90306,1.0313,1.1455,1.2499,1.3472,1.4390,1.5264,1.6103,1.6912,1.7697,1.8461,1.9207,1.9938,2.0656,2.1362,2.2058,2.2745,2.3425,2.4099,2.4767,2.5430,2.6090,2.6746,2.7400,2.8051,2.8701,2.9350,2.9999,3.0648,3.1297,3.1947,3.2598,3.3251,3.3906,3.4564,3.5224,3.5888,3.6555,3.7226,3.7902,3.8582,3.9268,3.9959,4.0657,4.1360,4.2071,4.2789,4.3515,4.4249,4.4991,4.5743,4.6505,4.7278,4.8061,4.8856,4.9664,5.0484,5.1319,5.2168,5.3033,5.3914,5.4813,5.5731,5.6668,5.7627,5.8608,5.9613,6.0644,6.1703,6.2791,6.3911,6.5065,6.6257,6.7488,6.8764,7.0086,7.1461,7.2893,7.4388,7.5952,7.7595,7.9324,8.1152,8.3092,8.5160,8.7376,8.9766,9.2364,9.5211,9.8366,10.191,10.596,11.070,11.644,12.375,13.388,15.086],
[0,0.87209,1.1344,1.3296,1.4924,1.6354,1.7649,1.8846,1.9967,2.1029,2.2041,2.3014,2.3953,2.4863,2.5748,2.6613,2.7459,2.8289,2.9104,2.9908,3.0701,3.1484,3.2260,3.3028,3.3789,3.4546,3.5298,3.6046,3.6792,3.7534,3.8276,3.9015,3.9754,4.0493,4.1233,4.1973,4.2714,4.3457,4.4203,4.4950,4.5701,4.6456,4.7215,4.7978,4.8746,4.9519,5.0298,5.1083,5.1875,5.2674,5.3481,5.4296,5.5121,5.5954,5.6798,5.7652,5.8518,5.9395,6.0286,6.1189,6.2108,6.3041,6.3991,6.4958,6.5943,6.6948,6.7973,6.9021,7.0092,7.1188,7.2311,7.3464,7.4647,7.5864,7.7116,7.8408,7.9742,8.1122,8.2552,8.4036,8.5581,8.7192,8.8876,9.0642,9.2500,9.4461,9.6540,9.8754,10.112,10.368,10.645,10.948,11.284,11.660,12.090,12.592,13.198,13.968,15.033,16.812],
[0,1.2390,1.5643,1.8016,1.9971,2.1673,2.3205,2.4611,2.5922,2.7157,2.8331,2.9455,3.0536,3.1581,3.2595,3.3583,3.4547,3.5491,3.6417,3.7327,3.8223,3.9107,3.9981,4.0845,4.1700,4.2549,4.3391,4.4227,4.5060,4.5888,4.6713,4.7536,4.8357,4.9177,4.9997,5.0816,5.1636,5.2458,5.3280,5.4105,5.4932,5.5763,5.6597,5.7435,5.8277,5.9125,5.9978,6.0838,6.1704,6.2577,6.3458,6.4347,6.5245,6.6153,6.7071,6.8000,6.8940,6.9893,7.0858,7.1838,7.2832,7.3842,7.4869,7.5914,7.6977,7.8061,7.9167,8.0295,8.1448,8.2627,8.3834,8.5072,8.6341,8.7646,8.8988,9.0372,9.1799,9.3273,9.4801,9.6385,9.8033,9.9749,10.154,10.342,10.540,10.748,10.968,11.203,11.454,11.724,12.017,12.337,12.691,13.088,13.540,14.067,14.703,15.509,16.622,18.475],
[0,1.6465,2.0325,2.3101,2.5366,2.7326,2.9080,3.0683,3.2172,3.3570,3.4895,3.6160,3.7375,3.8546,3.9680,4.0782,4.1856,4.2906,4.3934,4.4943,4.5936,4.6913,4.7878,4.8830,4.9773,5.0706,5.1632,5.2551,5.3463,5.4371,5.5274,5.6174,5.7071,5.7966,5.8860,5.9753,6.0646,6.1539,6.2433,6.3329,6.4226,6.5127,6.6031,6.6938,6.7850,6.8766,6.9688,7.0616,7.1551,7.2492,7.3441,7.4399,7.5365,7.6341,7.7328,7.8325,7.9334,8.0356,8.1391,8.2441,8.3505,8.4586,8.5684,8.6801,8.7937,8.9094,9.0273,9.1476,9.2704,9.3960,9.5245,9.6561,9.7910,9.9296,10.072,10.219,10.370,10.526,10.688,10.856,11.030,11.212,11.401,11.599,11.808,12.027,12.259,12.506,12.770,13.054,13.362,13.697,14.068,14.484,14.956,15.507,16.171,17.010,18.168,20.090],
[0,2.0879,2.5324,2.8485,3.1047,3.3251,3.5215,3.7005,3.8661,4.0214,4.1682,4.3080,4.4419,4.5709,4.6955,4.8165,4.9343,5.0492,5.1616,5.2718,5.3800,5.4866,5.5915,5.6951,5.7975,5.8988,5.9992,6.0987,6.1975,6.2957,6.3933,6.4905,6.5873,6.6838,6.7801,6.8763,6.9723,7.0684,7.1645,7.2607,7.3570,7.4536,7.5505,7.6477,7.7453,7.8434,7.9420,8.0412,8.1410,8.2415,8.3428,8.4450,8.5480,8.6520,8.7570,8.8632,8.9705,9.0792,9.1892,9.3006,9.4136,9.5283,9.6448,9.7631,9.8835,10.006,10.131,10.258,10.388,10.521,10.656,10.795,10.938,11.084,11.234,11.389,11.548,11.713,11.883,12.059,12.242,12.433,12.632,12.840,13.058,13.288,13.531,13.790,14.066,14.363,14.684,15.034,15.421,15.854,16.346,16.919,17.608,18.480,19.679,21.666],
[0,2.5582,3.0591,3.4121,3.6965,3.9403,4.1567,4.3534,4.5351,4.7049,4.8652,5.0176,5.1634,5.3036,5.4389,5.5701,5.6976,5.8219,5.9433,6.0623,6.1791,6.2939,6.4069,6.5183,6.6284,6.7372,6.8449,6.9517,7.0576,7.1627,7.2672,7.3712,7.4747,7.5778,7.6806,7.7832,7.8857,7.9881,8.0905,8.1929,8.2955,8.3982,8.5012,8.6045,8.7082,8.8124,8.9170,9.0222,9.1280,9.2345,9.3418,9.4499,9.5590,9.6690,9.7800,9.8922,10.006,10.120,10.236,10.354,10.473,10.594,10.717,10.841,10.968,11.097,11.228,11.362,11.499,11.638,11.781,11.927,12.076,12.229,12.387,12.549,12.716,12.888,13.066,13.251,13.442,13.641,13.849,14.066,14.294,14.534,14.788,15.057,15.344,15.653,15.987,16.352,16.753,17.203,17.713,18.307,19.021,19.922,21.161,23.209],
[0,3.0535,3.6087,3.9972,4.3087,4.5748,4.8104,5.0240,5.2209,5.4046,5.5778,5.7422,5.8993,6.0501,6.1956,6.3364,6.4732,6.6064,6.7365,6.8638,6.9887,7.1113,7.2320,7.3509,7.4682,7.5841,7.6988,7.8124,7.9251,8.0368,8.1479,8.2583,8.3681,8.4775,8.5865,8.6952,8.8038,8.9122,9.0205,9.1288,9.2373,9.3459,9.4547,9.5638,9.6732,9.7831,9.8934,10.004,10.116,10.228,10.341,10.455,10.570,10.685,10.802,10.920,11.039,11.159,11.281,11.405,11.530,11.657,11.785,11.916,12.049,12.184,12.321,12.461,12.604,12.750,12.899,13.051,13.207,13.367,13.532,13.701,13.875,14.054,14.240,14.432,14.631,14.839,15.055,15.281,15.518,15.767,16.031,16.310,16.609,16.929,17.275,17.653,18.069,18.533,19.061,19.675,20.412,21.342,22.618,24.725],
[0,3.5706,4.1783,4.6009,4.9386,5.2260,5.4800,5.7098,5.9212,6.1183,6.3038,6.4797,6.6475,6.8086,6.9638,7.1138,7.2595,7.4012,7.5395,7.6748,7.8073,7.9374,8.0654,8.1914,8.3157,8.4384,8.5598,8.6799,8.7989,8.9170,9.0343,9.1508,9.2667,9.3820,9.4970,9.6115,9.7258,9.8399,9.9540,10.068,10.182,10.296,10.410,10.525,10.640,10.755,10.871,10.987,11.104,11.222,11.340,11.460,11.580,11.701,11.823,11.946,12.071,12.197,12.324,12.453,12.584,12.716,12.851,12.987,13.125,13.266,13.409,13.555,13.704,13.856,14.011,14.170,14.332,14.499,14.670,14.845,15.026,15.213,15.406,15.605,15.812,16.027,16.251,16.485,16.731,16.989,17.262,17.552,17.860,18.191,18.549,18.939,19.369,19.849,20.393,21.026,21.785,22.742,24.054,26.217],
[0,4.1069,4.7655,5.2210,5.5838,5.8919,6.1635,6.4089,6.6343,6.8442,7.0415,7.2284,7.4066,7.5774,7.7419,7.9008,8.0550,8.2049,8.3511,8.4939,8.6339,8.7711,8.9061,9.0389,9.1698,9.2991,9.4268,9.5532,9.6784,9.8025,9.9257,10.048,10.170,10.291,10.411,10.532,10.651,10.771,10.890,11.010,11.129,11.249,11.368,11.488,11.608,11.729,11.850,11.971,12.093,12.216,12.340,12.464,12.589,12.716,12.843,12.972,13.102,13.233,13.365,13.500,13.636,13.773,13.913,14.055,14.199,14.345,14.494,14.646,14.800,14.958,15.119,15.283,15.452,15.625,15.802,15.984,16.171,16.365,16.564,16.771,16.985,17.207,17.439,17.681,17.935,18.202,18.484,18.783,19.101,19.443,19.812,20.214,20.657,21.151,21.711,22.362,23.142,24.125,25.472,27.688],
[0,4.6604,5.3682,5.8556,6.2426,6.5706,6.8593,7.1197,7.3587,7.5809,7.7895,7.9870,8.1752,8.3554,8.5288,8.6963,8.8586,9.0164,9.1701,9.3203,9.4673,9.6115,9.7531,9.8925,10.030,10.165,10.299,10.432,10.563,10.693,10.821,10.949,11.077,11.203,11.329,11.455,11.580,11.705,11.829,11.954,12.078,12.203,12.328,12.453,12.578,12.703,12.829,12.956,13.083,13.211,13.339,13.469,13.599,13.730,13.863,13.996,14.131,14.267,14.405,14.544,14.685,14.828,14.973,15.120,15.269,15.421,15.575,15.732,15.892,16.055,16.222,16.392,16.567,16.745,16.929,17.117,17.311,17.510,17.716,17.930,18.151,18.380,18.620,18.869,19.131,19.406,19.697,20.004,20.333,20.684,21.064,21.478,21.933,22.441,23.017,23.685,24.485,25.493,26.873,29.141],
[0,5.2294,5.9849,6.5032,6.9137,7.2609,7.5661,7.8410,8.0930,8.3271,8.5468,8.7545,8.9523,9.1416,9.3236,9.4993,9.6695,9.8348,9.9959,10.153,10.307,10.458,10.606,10.752,10.895,11.037,11.176,11.314,11.451,11.587,11.721,11.855,11.987,12.119,12.250,12.381,12.511,12.641,12.771,12.900,13.030,13.159,13.289,13.419,13.549,13.679,13.810,13.941,14.073,14.206,14.339,14.473,14.608,14.744,14.881,15.020,15.159,15.300,15.443,15.587,15.733,15.881,16.031,16.183,16.337,16.494,16.653,16.816,16.981,17.150,17.322,17.498,17.677,17.862,18.051,18.245,18.445,18.651,18.863,19.083,19.311,19.547,19.793,20.051,20.320,20.603,20.902,21.218,21.555,21.917,22.307,22.732,23.199,23.720,24.311,24.996,25.816,26.848,28.259,30.578],
[0,5.8122,6.6142,7.1625,7.5958,7.9616,8.2827,8.5717,8.8363,9.0820,9.3122,9.5299,9.7369,9.9350,10.125,10.309,10.487,10.659,10.828,10.992,11.152,11.309,11.464,11.615,11.765,11.912,12.058,12.201,12.344,12.485,12.624,12.763,12.901,13.038,13.174,13.310,13.445,13.580,13.714,13.848,13.983,14.117,14.251,14.386,14.520,14.655,14.791,14.927,15.063,15.201,15.338,15.477,15.617,15.758,15.899,16.042,16.187,16.333,16.480,16.629,16.780,16.932,17.087,17.244,17.403,17.565,17.729,17.896,18.067,18.241,18.418,18.599,18.784,18.974,19.169,19.369,19.574,19.786,20.005,20.231,20.465,20.708,20.961,21.226,21.502,21.793,22.100,22.425,22.771,23.142,23.542,23.977,24.456,24.990,25.595,26.296,27.136,28.191,29.633,32.000],
[0,6.4078,7.2550,7.8324,8.2878,8.6718,9.0083,9.3109,9.5878,9.8446,10.085,10.312,10.528,10.735,10.934,11.125,11.310,11.490,11.665,11.835,12.002,12.166,12.326,12.484,12.639,12.792,12.943,13.092,13.240,13.386,13.531,13.674,13.817,13.959,14.100,14.241,14.381,14.520,14.659,14.798,14.937,15.076,15.215,15.354,15.493,15.633,15.773,15.913,16.054,16.196,16.338,16.481,16.626,16.771,16.917,17.065,17.213,17.364,17.516,17.669,17.824,17.982,18.141,18.303,18.466,18.633,18.802,18.974,19.150,19.329,19.511,19.697,19.888,20.083,20.283,20.489,20.700,20.918,21.142,21.374,21.615,21.864,22.124,22.395,22.679,22.977,23.291,23.625,23.979,24.359,24.769,25.215,25.705,26.251,26.870,27.587,28.445,29.523,30.995,33.409],
[0,7.0149,7.9062,8.5120,8.9889,9.3905,9.7421,10.058,10.347,10.614,10.865,11.101,11.326,11.541,11.747,11.946,12.139,12.325,12.507,12.684,12.857,13.026,13.193,13.356,13.517,13.675,13.832,13.986,14.139,14.290,14.440,14.589,14.736,14.883,15.029,15.174,15.318,15.463,15.606,15.750,15.893,16.037,16.180,16.323,16.467,16.611,16.755,16.900,17.045,17.191,17.338,17.485,17.634,17.783,17.934,18.086,18.239,18.394,18.550,18.708,18.868,19.030,19.194,19.360,19.528,19.699,19.873,20.050,20.230,20.414,20.601,20.793,20.988,21.189,21.394,21.605,21.822,22.045,22.275,22.513,22.760,23.015,23.282,23.559,23.850,24.155,24.477,24.818,25.181,25.570,25.989,26.445,26.947,27.505,28.137,28.869,29.745,30.845,32.346,34.805],
[0,7.6327,8.5670,9.2004,9.6983,10.117,10.483,10.812,11.112,11.391,11.651,11.897,12.130,12.353,12.567,12.773,12.972,13.165,13.353,13.537,13.716,13.891,14.063,14.232,14.398,14.562,14.724,14.883,15.041,15.197,15.352,15.505,15.657,15.809,15.959,16.109,16.258,16.407,16.555,16.703,16.850,16.998,17.146,17.293,17.441,17.589,17.738,17.887,18.037,18.187,18.338,18.489,18.642,18.796,18.951,19.107,19.264,19.423,19.584,19.746,19.910,20.076,20.245,20.415,20.588,20.764,20.942,21.124,21.309,21.497,21.689,21.885,22.086,22.291,22.502,22.718,22.940,23.169,23.404,23.648,23.900,24.162,24.435,24.719,25.016,25.329,25.658,26.007,26.378,26.775,27.204,27.669,28.181,28.751,29.396,30.144,31.037,32.158,33.687,36.191],
[0,8.2604,9.2367,9.8971,10.415,10.851,11.231,11.573,11.884,12.173,12.443,12.697,12.939,13.169,13.391,13.604,13.810,14.010,14.204,14.393,14.578,14.759,14.937,15.111,15.283,15.452,15.618,15.783,15.945,16.106,16.266,16.424,16.581,16.737,16.892,17.046,17.199,17.352,17.505,17.657,17.809,17.961,18.112,18.264,18.416,18.569,18.721,18.874,19.028,19.182,19.337,19.493,19.650,19.808,19.967,20.127,20.289,20.452,20.617,20.783,20.951,21.122,21.294,21.469,21.646,21.826,22.009,22.195,22.385,22.578,22.775,22.975,23.181,23.391,23.607,23.828,24.055,24.289,24.530,24.779,25.038,25.305,25.584,25.874,26.178,26.498,26.834,27.190,27.569,27.975,28.412,28.887,29.410,29.991,30.649,31.410,32.321,33.462,35.020,37.566],
[0,8.8972,9.9146,10.601,11.140,11.591,11.986,12.339,12.662,12.961,13.240,13.503,13.752,13.991,14.219,14.439,14.652,14.858,15.059,15.254,15.445,15.631,15.814,15.994,16.170,16.344,16.516,16.685,16.853,17.018,17.182,17.345,17.506,17.666,17.826,17.984,18.142,18.299,18.456,18.612,18.768,18.924,19.080,19.236,19.392,19.548,19.705,19.862,20.020,20.178,20.337,20.497,20.658,20.820,20.983,21.147,21.313,21.480,21.649,21.819,21.991,22.166,22.343,22.522,22.703,22.888,23.075,23.265,23.459,23.656,23.858,24.063,24.273,24.488,24.709,24.935,25.167,25.406,25.653,25.907,26.171,26.445,26.729,27.026,27.336,27.662,28.005,28.369,28.755,29.169,29.615,30.100,30.632,31.225,31.895,32.671,33.597,34.759,36.343,38.932],
[0,9.5425,10.600,11.313,11.870,12.338,12.746,13.112,13.445,13.753,14.041,14.313,14.571,14.816,15.052,15.279,15.498,15.710,15.917,16.118,16.314,16.506,16.694,16.879,17.061,17.240,17.416,17.590,17.762,17.932,18.101,18.268,18.433,18.598,18.762,18.924,19.086,19.247,19.408,19.569,19.729,19.889,20.049,20.208,20.369,20.529,20.689,20.850,21.012,21.174,21.337,21.501,21.665,21.831,21.998,22.166,22.336,22.507,22.680,22.854,23.031,23.209,23.390,23.573,23.759,23.947,24.139,24.333,24.531,24.733,24.939,25.149,25.364,25.583,25.808,26.039,26.276,26.521,26.772,27.032,27.301,27.581,27.871,28.174,28.490,28.822,29.173,29.543,29.937,30.359,30.813,31.307,31.849,32.453,33.135,33.924,34.867,36.049,37.660,40.289],
[0,10.196,11.293,12.030,12.607,13.091,13.512,13.889,14.233,14.551,14.848,15.128,15.393,15.646,15.889,16.122,16.347,16.566,16.778,16.985,17.187,17.384,17.577,17.767,17.954,18.137,18.318,18.497,18.674,18.848,19.021,19.192,19.362,19.531,19.699,19.866,20.032,20.197,20.362,20.526,20.690,20.854,21.018,21.182,21.345,21.510,21.674,21.839,22.004,22.170,22.337,22.504,22.673,22.842,23.013,23.185,23.359,23.534,23.710,23.889,24.069,24.251,24.436,24.623,24.813,25.006,25.201,25.400,25.602,25.808,26.018,26.233,26.452,26.676,26.906,27.141,27.383,27.632,27.889,28.154,28.429,28.713,29.009,29.318,29.641,29.979,30.336,30.713,31.115,31.544,32.007,32.510,33.062,33.675,34.370,35.172,36.131,37.332,38.968,41.638],
[0,10.856,11.992,12.754,13.350,13.848,14.283,14.672,15.026,15.353,15.659,15.946,16.219,16.479,16.729,16.969,17.200,17.425,17.642,17.855,18.062,18.264,18.463,18.657,18.849,19.037,19.223,19.406,19.587,19.766,19.943,20.119,20.293,20.466,20.638,20.808,20.978,21.148,21.316,21.485,21.652,21.820,21.988,22.155,22.323,22.491,22.659,22.827,22.997,23.166,23.337,23.508,23.680,23.854,24.028,24.204,24.381,24.560,24.740,24.922,25.106,25.293,25.481,25.672,25.866,26.063,26.262,26.465,26.671,26.882,27.096,27.315,27.538,27.767,28.001,28.241,28.488,28.742,29.003,29.274,29.553,29.843,30.145,30.459,30.788,31.132,31.496,31.880,32.288,32.725,33.196,33.708,34.269,34.893,35.599,36.415,37.389,38.609,40.270,42.980],
[0,11.524,12.697,13.484,14.098,14.611,15.059,15.459,15.823,16.159,16.473,16.769,17.049,17.316,17.572,17.818,18.056,18.286,18.510,18.727,18.940,19.147,19.351,19.550,19.746,19.939,20.129,20.317,20.502,20.686,20.867,21.047,21.225,21.402,21.578,21.752,21.926,22.099,22.272,22.444,22.616,22.787,22.958,23.130,23.301,23.472,23.644,23.816,23.989,24.163,24.337,24.512,24.687,24.864,25.042,25.222,25.403,25.585,25.769,25.955,26.143,26.333,26.525,26.720,26.918,27.118,27.322,27.529,27.739,27.953,28.172,28.395,28.623,28.856,29.094,29.339,29.590,29.849,30.115,30.390,30.675,30.970,31.277,31.597,31.932,32.282,32.652,33.043,33.458,33.903,34.382,34.902,35.472,36.106,36.824,37.652,38.642,39.880,41.566,44.314],
[0,12.198,13.409,14.219,14.851,15.379,15.839,16.250,16.624,16.970,17.292,17.595,17.883,18.157,18.419,18.671,18.915,19.151,19.380,19.603,19.820,20.033,20.241,20.445,20.646,20.843,21.038,21.230,21.419,21.607,21.792,21.976,22.158,22.339,22.519,22.697,22.875,23.052,23.228,23.404,23.579,23.755,23.929,24.104,24.279,24.454,24.630,24.806,24.982,25.159,25.336,25.515,25.694,25.875,26.057,26.240,26.424,26.610,26.798,26.987,27.179,27.373,27.569,27.767,27.969,28.173,28.380,28.591,28.806,29.024,29.246,29.473,29.705,29.942,30.185,30.435,30.690,30.954,31.225,31.505,31.795,32.095,32.407,32.733,33.073,33.429,33.805,34.203,34.625,35.077,35.563,36.091,36.671,37.315,38.044,38.885,39.889,41.146,42.856,45.642],
[0,12.879,14.125,14.959,15.609,16.151,16.624,17.045,17.429,17.783,18.114,18.425,18.719,19.000,19.269,19.527,19.777,20.018,20.252,20.480,20.703,20.920,21.133,21.342,21.548,21.749,21.948,22.144,22.338,22.530,22.719,22.907,23.093,23.278,23.461,23.644,23.825,24.006,24.186,24.365,24.544,24.723,24.901,25.080,25.258,25.437,25.616,25.795,25.975,26.155,26.336,26.518,26.701,26.885,27.070,27.257,27.445,27.634,27.826,28.019,28.214,28.411,28.611,28.814,29.019,29.227,29.438,29.652,29.871,30.093,30.319,30.550,30.786,31.028,31.275,31.528,31.789,32.056,32.332,32.617,32.912,33.217,33.534,33.865,34.211,34.574,34.955,35.359,35.788,36.247,36.741,37.278,37.866,38.520,39.259,40.113,41.132,42.407,44.140,46.963],
[0,13.565,14.847,15.704,16.371,16.928,17.412,17.844,18.238,18.601,18.939,19.258,19.559,19.846,20.121,20.386,20.641,20.888,21.127,21.361,21.588,21.810,22.028,22.241,22.451,22.657,22.860,23.061,23.258,23.454,23.647,23.839,24.029,24.218,24.405,24.591,24.776,24.960,25.144,25.327,25.509,25.691,25.873,26.055,26.237,26.419,26.602,26.785,26.968,27.152,27.336,27.522,27.708,27.895,28.084,28.274,28.465,28.658,28.853,29.050,29.249,29.450,29.653,29.859,30.067,30.279,30.494,30.712,30.934,31.160,31.391,31.626,31.866,32.111,32.363,32.620,32.885,33.157,33.438,33.727,34.027,34.337,34.659,34.995,35.347,35.715,36.103,36.513,36.949,37.414,37.916,38.460,39.058,39.721,40.471,41.337,42.370,43.662,45.419,48.278],
[0,14.256,15.574,16.454,17.138,17.708,18.204,18.647,19.050,19.421,19.768,20.093,20.402,20.695,20.977,21.247,21.507,21.760,22.005,22.243,22.475,22.702,22.924,23.142,23.356,23.567,23.774,23.978,24.180,24.380,24.577,24.772,24.966,25.158,25.349,25.539,25.728,25.916,26.103,26.289,26.475,26.661,26.846,27.032,27.217,27.402,27.588,27.774,27.961,28.148,28.336,28.525,28.715,28.905,29.097,29.291,29.486,29.682,29.880,30.080,30.283,30.487,30.694,30.903,31.115,31.331,31.549,31.771,31.997,32.227,32.461,32.700,32.944,33.194,33.449,33.711,33.980,34.256,34.541,34.835,35.139,35.455,35.782,36.123,36.480,36.854,37.247,37.664,38.106,38.579,39.087,39.640,40.246,40.919,41.679,42.557,43.604,44.913,46.693,49.588],
[0,14.953,16.306,17.208,17.908,18.493,19.000,19.453,19.865,20.245,20.599,20.932,21.247,21.547,21.834,22.110,22.377,22.634,22.884,23.127,23.364,23.596,23.822,24.045,24.263,24.478,24.689,24.897,25.103,25.307,25.508,25.707,25.904,26.100,26.295,26.488,26.680,26.872,27.062,27.252,27.442,27.631,27.820,28.008,28.197,28.386,28.575,28.764,28.954,29.145,29.336,29.528,29.721,29.915,30.111,30.307,30.505,30.705,30.907,31.110,31.316,31.524,31.734,31.947,32.163,32.382,32.604,32.829,33.059,33.292,33.530,33.773,34.021,34.274,34.534,34.800,35.073,35.354,35.643,35.941,36.250,36.570,36.903,37.249,37.611,37.990,38.390,38.812,39.260,39.740,40.256,40.816,41.430,42.113,42.883,43.773,44.834,46.160,47.962,50.892],
[0,15.655,17.042,17.966,18.683,19.281,19.800,20.263,20.684,21.072,21.434,21.773,22.095,22.401,22.695,22.976,23.248,23.510,23.765,24.013,24.255,24.491,24.722,24.949,25.171,25.390,25.606,25.818,26.028,26.235,26.440,26.643,26.844,27.043,27.241,27.438,27.634,27.829,28.023,28.216,28.409,28.601,28.793,28.985,29.177,29.369,29.562,29.754,29.948,30.141,30.336,30.531,30.728,30.925,31.124,31.323,31.525,31.728,31.933,32.140,32.349,32.560,32.774,32.990,33.209,33.431,33.657,33.886,34.119,34.356,34.598,34.845,35.096,35.354,35.617,35.887,36.164,36.449,36.743,37.046,37.359,37.684,38.021,38.372,38.739,39.124,39.529,39.958,40.412,40.899,41.422,41.989,42.612,43.303,44.084,44.985,46.059,47.402,49.226,52.191],
[0,16.362,17.783,18.727,19.461,20.072,20.602,21.075,21.505,21.902,22.271,22.617,22.946,23.258,23.557,23.844,24.121,24.389,24.649,24.901,25.148,25.388,25.624,25.855,26.081,26.304,26.523,26.740,26.953,27.164,27.373,27.579,27.784,27.987,28.189,28.389,28.588,28.786,28.984,29.180,29.376,29.572,29.767,29.963,30.158,30.353,30.549,30.745,30.941,31.138,31.336,31.534,31.734,31.934,32.136,32.339,32.544,32.750,32.959,33.169,33.381,33.595,33.812,34.032,34.255,34.480,34.710,34.942,35.179,35.420,35.665,35.915,36.171,36.432,36.699,36.973,37.254,37.543,37.841,38.149,38.466,38.796,39.138,39.494,39.866,40.256,40.667,41.101,41.562,42.055,42.585,43.160,43.791,44.491,45.282,46.194,47.282,48.641,50.487,53.486],
[0,17.074,18.527,19.493,20.242,20.867,21.408,21.891,22.330,22.734,23.110,23.464,23.799,24.117,24.422,24.714,24.996,25.269,25.534,25.791,26.042,26.287,26.527,26.762,26.993,27.219,27.443,27.663,27.880,28.095,28.307,28.517,28.725,28.932,29.137,29.340,29.543,29.744,29.945,30.145,30.344,30.543,30.742,30.940,31.139,31.337,31.536,31.735,31.935,32.135,32.336,32.537,32.740,32.944,33.149,33.355,33.563,33.772,33.984,34.197,34.413,34.630,34.851,35.074,35.300,35.529,35.761,35.997,36.237,36.482,36.731,36.984,37.244,37.509,37.780,38.058,38.343,38.636,38.938,39.250,39.572,39.906,40.252,40.613,40.991,41.386,41.802,42.242,42.709,43.208,43.745,44.328,44.966,45.675,46.476,47.400,48.500,49.876,51.743,54.776],
[0,17.789,19.275,20.262,21.027,21.664,22.217,22.709,23.157,23.569,23.952,24.313,24.654,24.978,25.288,25.586,25.874,26.152,26.421,26.683,26.938,27.188,27.432,27.671,27.905,28.136,28.363,28.587,28.808,29.026,29.242,29.456,29.667,29.877,30.086,30.293,30.499,30.703,30.907,31.110,31.313,31.515,31.717,31.919,32.120,32.322,32.524,32.726,32.929,33.132,33.336,33.540,33.746,33.953,34.161,34.371,34.582,34.794,35.009,35.225,35.444,35.665,35.888,36.115,36.344,36.576,36.812,37.052,37.295,37.543,37.795,38.053,38.316,38.584,38.859,39.141,39.430,39.727,40.033,40.349,40.676,41.014,41.365,41.731,42.113,42.514,42.935,43.381,43.854,44.359,44.903,45.493,46.140,46.857,47.667,48.602,49.716,51.107,52.995,56.061],
[0,18.509,20.027,21.035,21.815,22.465,23.028,23.530,23.986,24.406,24.797,25.164,25.511,25.841,26.157,26.460,26.753,27.035,27.310,27.576,27.836,28.089,28.338,28.581,28.819,29.054,29.285,29.512,29.737,29.959,30.178,30.395,30.610,30.824,31.035,31.246,31.455,31.663,31.870,32.076,32.282,32.487,32.692,32.897,33.102,33.306,33.511,33.717,33.922,34.129,34.336,34.543,34.752,34.962,35.173,35.386,35.600,35.816,36.033,36.253,36.475,36.699,36.925,37.155,37.387,37.623,37.862,38.105,38.352,38.603,38.859,39.120,39.386,39.659,39.937,40.223,40.516,40.817,41.127,41.447,41.778,42.121,42.477,42.847,43.234,43.640,44.067,44.518,44.997,45.508,46.059,46.656,47.310,48.036,48.856,49.802,50.928,52.335,54.244,57.342],
[0,19.233,20.783,21.811,22.607,23.269,23.843,24.354,24.818,25.245,25.643,26.017,26.370,26.706,27.028,27.336,27.634,27.921,28.200,28.471,28.735,28.993,29.245,29.492,29.735,29.973,30.208,30.439,30.667,30.892,31.115,31.336,31.554,31.771,31.986,32.200,32.412,32.623,32.833,33.043,33.252,33.460,33.668,33.876,34.084,34.291,34.499,34.708,34.916,35.126,35.336,35.546,35.758,35.971,36.185,36.401,36.618,36.837,37.057,37.280,37.505,37.732,37.962,38.195,38.430,38.669,38.912,39.158,39.408,39.663,39.922,40.186,40.456,40.732,41.014,41.304,41.600,41.906,42.220,42.544,42.879,43.226,43.586,43.961,44.353,44.764,45.196,45.653,46.137,46.655,47.212,47.816,48.478,49.213,50.042,50.998,52.137,53.560,55.489,58.619],
[0,19.960,21.542,22.589,23.401,24.075,24.659,25.180,25.652,26.087,26.492,26.872,27.232,27.573,27.900,28.214,28.516,28.808,29.092,29.367,29.635,29.897,30.154,30.405,30.651,30.893,31.132,31.366,31.598,31.827,32.053,32.277,32.499,32.719,32.937,33.154,33.369,33.584,33.797,34.010,34.222,34.433,34.644,34.855,35.066,35.276,35.487,35.699,35.910,36.123,36.336,36.549,36.764,36.980,37.197,37.416,37.636,37.858,38.081,38.307,38.535,38.765,38.998,39.234,39.473,39.715,39.960,40.210,40.463,40.721,40.984,41.252,41.525,41.804,42.090,42.383,42.684,42.993,43.311,43.639,43.978,44.330,44.694,45.074,45.471,45.886,46.324,46.786,47.276,47.800,48.363,48.974,49.644,50.387,51.225,52.192,53.344,54.781,56.730,59.892],
[0,20.691,22.304,23.371,24.197,24.884,25.479,26.008,26.489,26.931,27.343,27.729,28.095,28.442,28.774,29.093,29.400,29.697,29.985,30.265,30.537,30.803,31.064,31.319,31.569,31.815,32.056,32.295,32.530,32.762,32.992,33.219,33.444,33.667,33.889,34.109,34.328,34.545,34.761,34.977,35.192,35.406,35.620,35.834,36.048,36.262,36.476,36.690,36.904,37.120,37.335,37.552,37.770,37.989,38.209,38.430,38.653,38.878,39.105,39.333,39.564,39.798,40.034,40.273,40.514,40.760,41.008,41.261,41.518,41.779,42.045,42.316,42.593,42.876,43.165,43.462,43.766,44.079,44.401,44.733,45.076,45.432,45.801,46.185,46.587,47.007,47.450,47.917,48.413,48.943,49.513,50.130,50.807,51.559,52.406,53.384,54.547,56.000,57.969,61.162],
[0,21.426,23.069,24.156,24.997,25.695,26.301,26.839,27.328,27.777,28.196,28.588,28.960,29.313,29.650,29.974,30.286,30.587,30.880,31.164,31.441,31.711,31.975,32.234,32.487,32.737,32.982,33.224,33.463,33.699,33.932,34.162,34.390,34.617,34.841,35.064,35.286,35.507,35.726,35.945,36.163,36.380,36.597,36.814,37.031,37.247,37.464,37.681,37.899,38.117,38.335,38.555,38.776,38.997,39.220,39.445,39.671,39.898,40.128,40.360,40.593,40.830,41.069,41.311,41.556,41.804,42.056,42.312,42.572,42.836,43.105,43.380,43.660,43.946,44.239,44.539,44.847,45.164,45.490,45.826,46.173,46.533,46.906,47.295,47.701,48.126,48.574,49.046,49.548,50.084,50.660,51.284,51.969,52.728,53.584,54.572,55.748,57.215,59.204,62.428],
[0,22.164,23.838,24.944,25.799,26.509,27.125,27.672,28.169,28.625,29.051,29.449,29.826,30.185,30.528,30.856,31.173,31.479,31.776,32.064,32.345,32.619,32.887,33.150,33.407,33.660,33.909,34.155,34.397,34.636,34.872,35.106,35.337,35.567,35.794,36.021,36.245,36.469,36.691,36.913,37.134,37.354,37.574,37.794,38.013,38.233,38.453,38.672,38.893,39.114,39.335,39.558,39.781,40.006,40.232,40.459,40.688,40.918,41.151,41.385,41.622,41.862,42.103,42.348,42.596,42.848,43.103,43.362,43.625,43.892,44.165,44.443,44.726,45.016,45.312,45.616,45.928,46.248,46.577,46.917,47.269,47.632,48.010,48.403,48.814,49.244,49.696,50.174,50.681,51.223,51.805,52.436,53.128,53.895,54.761,55.758,56.946,58.428,60.436,63.691],
[0,22.906,24.609,25.734,26.603,27.326,27.951,28.507,29.011,29.475,29.907,30.312,30.695,31.059,31.407,31.740,32.062,32.372,32.673,32.966,33.251,33.529,33.800,34.067,34.328,34.585,34.837,35.086,35.331,35.574,35.813,36.050,36.285,36.517,36.748,36.977,37.205,37.432,37.657,37.882,38.105,38.329,38.551,38.774,38.996,39.219,39.441,39.664,39.887,40.111,40.335,40.561,40.787,41.014,41.243,41.473,41.705,41.938,42.173,42.411,42.651,42.893,43.138,43.386,43.637,43.891,44.149,44.411,44.677,44.948,45.224,45.505,45.792,46.085,46.384,46.692,47.007,47.331,47.664,48.008,48.363,48.731,49.113,49.510,49.925,50.360,50.817,51.300,51.813,52.360,52.949,53.586,54.285,55.060,55.934,56.942,58.142,59.638,61.665,64.950],
[0,23.650,25.383,26.527,27.410,28.144,28.779,29.344,29.856,30.327,30.765,31.177,31.565,31.934,32.287,32.626,32.952,33.267,33.572,33.869,34.157,34.439,34.715,34.985,35.250,35.510,35.766,36.018,36.267,36.512,36.755,36.995,37.233,37.469,37.702,37.935,38.165,38.395,38.623,38.851,39.077,39.303,39.529,39.754,39.980,40.205,40.430,40.656,40.882,41.108,41.335,41.563,41.792,42.022,42.254,42.487,42.721,42.958,43.196,43.436,43.679,43.924,44.172,44.422,44.676,44.934,45.195,45.460,45.729,46.003,46.282,46.566,46.856,47.152,47.456,47.766,48.085,48.412,48.749,49.097,49.456,49.828,50.214,50.616,51.035,51.475,51.937,52.425,52.943,53.496,54.090,54.735,55.441,56.223,57.106,58.124,59.335,60.845,62.892,66.206],
[0,24.398,26.159,27.322,28.220,28.965,29.610,30.183,30.703,31.181,31.625,32.043,32.437,32.811,33.169,33.512,33.843,34.162,34.472,34.773,35.065,35.351,35.630,35.904,36.172,36.436,36.695,36.951,37.203,37.452,37.698,37.941,38.182,38.420,38.657,38.892,39.126,39.359,39.590,39.820,40.050,40.279,40.507,40.735,40.963,41.191,41.419,41.647,41.876,42.105,42.335,42.566,42.798,43.031,43.265,43.501,43.738,43.977,44.218,44.461,44.706,44.954,45.205,45.459,45.715,45.976,46.240,46.508,46.780,47.057,47.339,47.626,47.920,48.219,48.526,48.840,49.162,49.493,49.834,50.185,50.548,50.924,51.314,51.720,52.144,52.588,53.055,53.548,54.071,54.630,55.230,55.881,56.594,57.385,58.276,59.304,60.526,62.050,64.116,67.459],
[0,25.148,26.939,28.119,29.031,29.787,30.442,31.024,31.551,32.036,32.487,32.910,33.310,33.689,34.052,34.400,34.735,35.059,35.373,35.678,35.974,36.264,36.547,36.824,37.096,37.363,37.626,37.885,38.140,38.392,38.641,38.887,39.131,39.373,39.613,39.851,40.087,40.323,40.557,40.790,41.022,41.254,41.485,41.716,41.947,42.177,42.408,42.639,42.871,43.102,43.335,43.569,43.803,44.039,44.276,44.514,44.754,44.996,45.240,45.485,45.734,45.984,46.238,46.494,46.754,47.017,47.284,47.555,47.831,48.111,48.396,48.686,48.983,49.286,49.596,49.913,50.238,50.573,50.917,51.272,51.639,52.019,52.413,52.823,53.251,53.700,54.171,54.669,55.198,55.762,56.369,57.026,57.746,58.544,59.444,60.481,61.714,63.253,65.337,68.710],
[0,25.901,27.720,28.919,29.845,30.612,31.276,31.866,32.401,32.893,33.350,33.779,34.184,34.569,34.937,35.290,35.629,35.957,36.275,36.584,36.884,37.178,37.464,37.745,38.021,38.291,38.557,38.819,39.078,39.333,39.585,39.834,40.081,40.326,40.568,40.809,41.049,41.287,41.524,41.760,41.995,42.229,42.463,42.697,42.930,43.164,43.397,43.631,43.865,44.100,44.335,44.571,44.808,45.047,45.286,45.527,45.770,46.015,46.261,46.510,46.761,47.014,47.271,47.530,47.792,48.058,48.328,48.602,48.881,49.164,49.452,49.745,50.045,50.351,50.664,50.985,51.314,51.652,52.000,52.358,52.729,53.112,53.511,53.925,54.357,54.810,55.287,55.790,56.323,56.893,57.505,58.169,58.895,59.701,60.609,61.656,62.901,64.453,66.555,69.957],
[0,26.657,28.505,29.722,30.660,31.439,32.112,32.711,33.253,33.752,34.215,34.650,35.060,35.450,35.823,36.180,36.524,36.856,37.178,37.491,37.795,38.092,38.383,38.667,38.946,39.220,39.489,39.754,40.016,40.274,40.529,40.782,41.032,41.279,41.525,41.769,42.011,42.252,42.492,42.730,42.968,43.205,43.442,43.678,43.914,44.150,44.387,44.623,44.860,45.097,45.335,45.574,45.814,46.055,46.297,46.541,46.786,47.033,47.282,47.534,47.787,48.044,48.303,48.565,48.830,49.099,49.372,49.649,49.930,50.216,50.507,50.804,51.107,51.416,51.732,52.056,52.389,52.730,53.081,53.443,53.818,54.205,54.607,55.026,55.462,55.920,56.401,56.909,57.447,58.022,58.641,59.310,60.044,60.857,61.773,62.830,64.085,65.652,67.771,71.201],
[0,27.416,29.291,30.526,31.478,32.268,32.950,33.557,34.107,34.612,35.081,35.522,35.938,36.333,36.710,37.072,37.420,37.757,38.083,38.399,38.708,39.008,39.302,39.590,39.872,40.149,40.422,40.690,40.955,41.216,41.474,41.730,41.983,42.233,42.482,42.728,42.974,43.217,43.460,43.701,43.942,44.182,44.421,44.660,44.899,45.137,45.376,45.615,45.854,46.094,46.335,46.577,46.819,47.063,47.307,47.554,47.802,48.052,48.303,48.557,48.814,49.073,49.335,49.600,49.868,50.139,50.415,50.695,50.979,51.268,51.562,51.862,52.167,52.480,52.799,53.127,53.462,53.807,54.162,54.528,54.906,55.297,55.703,56.125,56.566,57.028,57.514,58.026,58.570,59.150,59.774,60.450,61.190,62.011,62.936,64.001,65.268,66.847,68.985,72.443],
[0,28.177,30.080,31.332,32.298,33.098,33.790,34.405,34.962,35.473,35.949,36.395,36.816,37.216,37.598,37.965,38.317,38.658,38.988,39.309,39.621,39.925,40.222,40.513,40.799,41.079,41.355,41.627,41.895,42.159,42.420,42.678,42.934,43.188,43.439,43.689,43.936,44.183,44.428,44.672,44.915,45.158,45.400,45.642,45.883,46.124,46.366,46.607,46.849,47.092,47.335,47.579,47.824,48.070,48.318,48.567,48.817,49.070,49.324,49.581,49.840,50.102,50.366,50.634,50.905,51.179,51.458,51.740,52.027,52.319,52.616,52.919,53.228,53.543,53.866,54.196,54.535,54.883,55.242,55.611,55.993,56.388,56.797,57.224,57.669,58.135,58.625,59.142,59.691,60.277,60.907,61.589,62.335,63.163,64.096,65.171,66.448,68.041,70.197,73.683],
[0,28.941,30.871,32.141,33.119,33.930,34.631,35.254,35.818,36.337,36.818,37.270,37.696,38.101,38.488,38.859,39.216,39.561,39.894,40.219,40.534,40.842,41.143,41.438,41.727,42.010,42.289,42.564,42.835,43.102,43.366,43.628,43.886,44.143,44.397,44.649,44.900,45.149,45.397,45.644,45.889,46.135,46.379,46.623,46.867,47.111,47.355,47.600,47.844,48.089,48.335,48.582,48.829,49.078,49.328,49.580,49.833,50.088,50.345,50.604,50.866,51.130,51.397,51.668,51.941,52.219,52.500,52.785,53.075,53.370,53.670,53.975,54.287,54.606,54.932,55.265,55.608,55.959,56.321,56.694,57.079,57.477,57.891,58.321,58.771,59.241,59.736,60.258,60.811,61.402,62.038,62.726,63.479,64.314,65.255,66.339,67.627,69.233,71.406,74.919],
[0,29.707,31.664,32.951,33.943,34.764,35.474,36.105,36.676,37.201,37.689,38.146,38.577,38.987,39.379,39.754,40.115,40.464,40.802,41.130,41.449,41.761,42.065,42.363,42.655,42.942,43.224,43.502,43.776,44.046,44.313,44.577,44.839,45.098,45.355,45.610,45.863,46.115,46.366,46.615,46.864,47.112,47.359,47.606,47.852,48.099,48.345,48.592,48.839,49.087,49.335,49.584,49.834,50.086,50.338,50.592,50.848,51.106,51.365,51.627,51.892,52.159,52.428,52.701,52.978,53.258,53.541,53.830,54.122,54.420,54.723,55.031,55.346,55.668,55.997,56.334,56.679,57.034,57.399,57.775,58.164,58.566,58.984,59.418,59.871,60.346,60.845,61.372,61.930,62.526,63.167,63.861,64.621,65.463,66.412,67.505,68.804,70.423,72.613,76.154],
[0,30.475,32.459,33.763,34.768,35.600,36.319,36.957,37.536,38.067,38.560,39.023,39.460,39.874,40.270,40.650,41.016,41.368,41.710,42.042,42.365,42.680,42.988,43.289,43.584,43.874,44.160,44.441,44.717,44.991,45.261,45.528,45.792,46.054,46.314,46.571,46.827,47.082,47.335,47.587,47.838,48.089,48.339,48.588,48.837,49.086,49.335,49.584,49.834,50.084,50.335,50.587,50.839,51.093,51.348,51.605,51.863,52.123,52.386,52.650,52.917,53.187,53.459,53.735,54.014,54.296,54.583,54.874,55.169,55.470,55.775,56.087,56.405,56.729,57.061,57.401,57.750,58.108,58.476,58.856,59.248,59.654,60.075,60.514,60.971,61.450,61.953,62.484,63.048,63.649,64.295,64.995,65.761,66.611,67.567,68.669,69.979,71.611,73.818,77.386],
[0,31.246,33.256,34.577,35.595,36.437,37.165,37.811,38.396,38.934,39.433,39.901,40.343,40.763,41.163,41.547,41.917,42.274,42.619,42.955,43.281,43.600,43.911,44.216,44.514,44.807,45.096,45.380,45.660,45.936,46.209,46.478,46.746,47.010,47.273,47.533,47.792,48.049,48.305,48.559,48.813,49.066,49.318,49.570,49.822,50.073,50.325,50.577,50.829,51.082,51.335,51.589,51.844,52.100,52.358,52.617,52.878,53.141,53.406,53.673,53.942,54.214,54.489,54.767,55.049,55.334,55.624,55.917,56.216,56.519,56.827,57.142,57.463,57.790,58.125,58.468,58.820,59.181,59.553,59.936,60.332,60.741,61.166,61.608,62.070,62.553,63.060,63.596,64.164,64.771,65.422,66.128,66.901,67.757,68.721,69.832,71.152,72.797,75.021,78.616],
[0,32.019,34.055,35.393,36.423,37.276,38.013,38.667,39.259,39.802,40.308,40.781,41.228,41.652,42.057,42.446,42.819,43.180,43.529,43.869,44.199,44.521,44.835,45.143,45.445,45.741,46.033,46.320,46.602,46.881,47.157,47.430,47.700,47.967,48.232,48.495,48.756,49.016,49.275,49.532,49.788,50.044,50.299,50.553,50.807,51.061,51.315,51.569,51.824,52.079,52.335,52.591,52.849,53.108,53.368,53.630,53.893,54.158,54.425,54.695,54.967,55.242,55.519,55.800,56.084,56.372,56.664,56.961,57.261,57.567,57.879,58.196,58.520,58.850,59.188,59.534,59.889,60.254,60.629,61.015,61.414,61.827,62.256,62.702,63.167,63.654,64.166,64.707,65.280,65.891,66.548,67.260,68.039,68.902,69.874,70.993,72.324,73.981,76.223,79.843],
[0,32.793,34.856,36.211,37.253,38.116,38.862,39.523,40.122,40.672,41.183,41.662,42.114,42.543,42.952,43.345,43.722,44.087,44.440,44.783,45.117,45.442,45.760,46.071,46.376,46.676,46.970,47.260,47.546,47.827,48.106,48.381,48.654,48.924,49.192,49.458,49.722,49.984,50.245,50.505,50.764,51.022,51.279,51.536,51.792,52.049,52.305,52.562,52.819,53.077,53.335,53.594,53.854,54.115,54.378,54.642,54.908,55.175,55.445,55.717,55.992,56.269,56.549,56.832,57.119,57.410,57.704,58.003,58.307,58.616,58.930,59.250,59.577,59.910,60.251,60.600,60.958,61.326,61.704,62.094,62.496,62.913,63.345,63.795,64.264,64.755,65.271,65.816,66.394,67.010,67.673,68.390,69.175,70.045,71.025,72.153,73.494,75.164,77.422,81.069],
[0,33.570,35.659,37.030,38.085,38.958,39.712,40.381,40.987,41.543,42.060,42.544,43.000,43.434,43.848,44.245,44.627,44.995,45.352,45.698,46.036,46.364,46.685,47.000,47.308,47.610,47.908,48.201,48.489,48.774,49.055,49.334,49.609,49.882,50.152,50.420,50.687,50.952,51.215,51.478,51.739,52.000,52.259,52.519,52.778,53.037,53.296,53.555,53.814,54.074,54.335,54.596,54.859,55.122,55.387,55.654,55.922,56.192,56.465,56.739,57.016,57.296,57.578,57.864,58.154,58.447,58.744,59.046,59.352,59.663,59.980,60.303,60.633,60.969,61.313,61.665,62.026,62.397,62.778,63.171,63.577,63.997,64.433,64.887,65.360,65.855,66.375,66.925,67.507,68.129,68.796,69.519,70.310,71.187,72.174,73.311,74.662,76.345,78.619,82.292],
[0,34.350,36.464,37.851,38.918,39.801,40.564,41.240,41.853,42.415,42.937,43.427,43.888,44.327,44.745,45.146,45.532,45.904,46.265,46.615,46.955,47.287,47.612,47.929,48.240,48.546,48.846,49.142,49.434,49.721,50.005,50.286,50.564,50.840,51.113,51.384,51.653,51.920,52.186,52.451,52.715,52.978,53.240,53.502,53.763,54.025,54.286,54.547,54.809,55.072,55.335,55.599,55.864,56.130,56.397,56.666,56.937,57.209,57.484,57.761,58.040,58.322,58.608,58.896,59.188,59.484,59.784,60.088,60.397,60.711,61.031,61.356,61.688,62.028,62.374,62.729,63.093,63.467,63.852,64.248,64.658,65.081,65.521,65.978,66.455,66.954,67.479,68.032,68.619,69.246,69.919,70.647,71.444,72.328,73.323,74.468,75.829,77.524,79.815,83.513],
[0,35.131,37.270,38.674,39.753,40.646,41.417,42.101,42.720,43.288,43.816,44.311,44.777,45.220,45.643,46.048,46.438,46.814,47.178,47.532,47.876,48.211,48.539,48.859,49.174,49.482,49.785,50.084,50.378,50.669,50.956,51.239,51.520,51.798,52.074,52.347,52.619,52.889,53.157,53.425,53.691,53.956,54.221,54.485,54.749,55.013,55.276,55.540,55.805,56.069,56.335,56.601,56.868,57.137,57.406,57.678,57.951,58.226,58.503,58.782,59.064,59.349,59.637,59.927,60.222,60.520,60.823,61.129,61.441,61.758,62.080,62.409,62.744,63.086,63.435,63.793,64.160,64.537,64.925,65.325,65.737,66.164,66.607,67.068,67.549,68.052,68.581,69.139,69.730,70.362,71.040,71.774,72.577,73.467,74.470,75.624,76.994,78.702,81.009,84.733],
[0,35.913,38.078,39.498,40.589,41.492,42.271,42.963,43.588,44.163,44.696,45.196,45.667,46.114,46.541,46.951,47.344,47.724,48.092,48.449,48.797,49.135,49.466,49.790,50.107,50.419,50.725,51.027,51.324,51.617,51.906,52.193,52.476,52.757,53.035,53.311,53.585,53.858,54.129,54.398,54.667,54.935,55.202,55.469,55.735,56.001,56.267,56.533,56.800,57.067,57.335,57.603,57.873,58.144,58.416,58.690,58.965,59.242,59.522,59.804,60.088,60.375,60.665,60.959,61.256,61.556,61.861,62.171,62.485,62.804,63.129,63.461,63.798,64.143,64.496,64.857,65.227,65.607,65.997,66.400,66.816,67.247,67.693,68.158,68.642,69.149,69.682,70.244,70.841,71.477,72.160,72.900,73.709,74.606,75.615,76.778,78.158,79.878,82.201,85.950],
[0,36.698,38.888,40.323,41.427,42.339,43.127,43.826,44.458,45.038,45.577,46.082,46.558,47.010,47.441,47.854,48.252,48.635,49.007,49.367,49.718,50.060,50.394,50.721,51.042,51.356,51.665,51.970,52.269,52.565,52.858,53.146,53.432,53.716,53.996,54.275,54.552,54.827,55.100,55.372,55.643,55.914,56.183,56.452,56.721,56.989,57.258,57.526,57.795,58.065,58.335,58.606,58.878,59.151,59.425,59.701,59.979,60.259,60.541,60.825,61.111,61.401,61.694,61.989,62.289,62.592,62.900,63.212,63.528,63.850,64.178,64.512,64.852,65.200,65.555,65.919,66.292,66.675,67.069,67.475,67.894,68.328,68.778,69.246,69.735,70.246,70.782,71.349,71.950,72.591,73.279,74.024,74.839,75.743,76.760,77.931,79.321,81.052,83.391,87.166],
[0,37.485,39.699,41.150,42.266,43.188,43.984,44.690,45.328,45.915,46.459,46.969,47.449,47.906,48.341,48.759,49.160,49.548,49.923,50.287,50.641,50.986,51.323,51.653,51.976,52.294,52.606,52.913,53.216,53.514,53.809,54.101,54.389,54.675,54.958,55.239,55.519,55.796,56.072,56.346,56.620,56.893,57.164,57.436,57.707,57.978,58.248,58.519,58.791,59.062,59.335,59.608,59.882,60.158,60.434,60.713,60.993,61.275,61.559,61.846,62.135,62.427,62.722,63.020,63.322,63.628,63.938,64.252,64.572,64.896,65.227,65.563,65.906,66.257,66.615,66.981,67.357,67.743,68.140,68.550,68.972,69.409,69.863,70.334,70.826,71.341,71.882,72.453,73.058,73.704,74.397,75.148,75.969,76.879,77.903,79.082,80.482,82.225,84.580,88.379],
[0,38.273,40.512,41.979,43.106,44.038,44.842,45.555,46.200,46.792,47.342,47.856,48.342,48.803,49.243,49.664,50.069,50.460,50.839,51.206,51.564,51.912,52.252,52.585,52.912,53.232,53.547,53.857,54.162,54.464,54.761,55.055,55.346,55.635,55.921,56.204,56.486,56.766,57.044,57.321,57.597,57.872,58.146,58.420,58.693,58.966,59.239,59.512,59.786,60.060,60.335,60.610,60.887,61.164,61.444,61.724,62.007,62.291,62.578,62.867,63.158,63.452,63.750,64.050,64.355,64.663,64.975,65.292,65.614,65.942,66.274,66.614,66.959,67.313,67.674,68.043,68.422,68.811,69.211,69.623,70.049,70.489,70.946,71.421,71.917,72.436,72.981,73.556,74.165,74.816,75.514,76.270,77.097,78.013,79.045,80.232,81.642,83.397,85.767,89.591],
[0,39.063,41.327,42.809,43.948,44.889,45.701,46.421,47.073,47.671,48.226,48.745,49.236,49.701,50.145,50.570,50.979,51.374,51.756,52.127,52.487,52.839,53.182,53.518,53.848,54.171,54.489,54.801,55.109,55.413,55.714,56.010,56.304,56.595,56.883,57.169,57.453,57.735,58.016,58.296,58.574,58.851,59.128,59.404,59.679,59.955,60.230,60.505,60.781,61.058,61.335,61.612,61.891,62.171,62.453,62.736,63.020,63.307,63.596,63.887,64.181,64.478,64.777,65.080,65.387,65.698,66.013,66.332,66.657,66.986,67.322,67.664,68.012,68.368,68.732,69.104,69.486,69.878,70.281,70.696,71.125,71.569,72.029,72.508,73.007,73.530,74.079,74.658,75.272,75.927,76.630,77.392,78.225,79.147,80.186,81.381,82.800,84.567,86.953,90.802],
[0,39.855,42.143,43.640,44.791,45.741,46.562,47.289,47.947,48.550,49.111,49.635,50.130,50.600,51.048,51.477,51.890,52.288,52.673,53.048,53.412,53.766,54.113,54.452,54.784,55.110,55.431,55.746,56.057,56.364,56.666,56.966,57.262,57.555,57.846,58.134,58.421,58.706,58.989,59.270,59.551,59.831,60.109,60.388,60.666,60.943,61.221,61.499,61.777,62.055,62.335,62.615,62.896,63.178,63.462,63.747,64.034,64.323,64.614,64.908,65.204,65.503,65.805,66.110,66.419,66.733,67.050,67.372,67.699,68.031,68.369,68.714,69.065,69.423,69.790,70.165,70.550,70.944,71.351,71.769,72.201,72.648,73.112,73.594,74.097,74.623,75.176,75.759,76.378,77.037,77.745,78.512,79.351,80.280,81.325,82.529,83.957,85.736,88.137,92.010],
[0,40.649,42.960,44.473,45.635,46.595,47.423,48.157,48.821,49.431,49.996,50.526,51.025,51.499,51.951,52.384,52.801,53.203,53.592,53.969,54.337,54.694,55.044,55.386,55.721,56.050,56.373,56.691,57.005,57.314,57.620,57.921,58.220,58.516,58.809,59.100,59.389,59.676,59.961,60.245,60.528,60.810,61.091,61.372,61.652,61.932,62.212,62.492,62.772,63.053,63.335,63.617,63.900,64.185,64.471,64.758,65.047,65.339,65.632,65.928,66.226,66.528,66.832,67.140,67.451,67.767,68.087,68.411,68.740,69.075,69.416,69.763,70.117,70.478,70.847,71.225,71.613,72.010,72.419,72.841,73.276,73.726,74.193,74.679,75.185,75.715,76.272,76.860,77.482,78.147,78.860,79.632,80.476,81.411,82.464,83.675,85.113,86.903,89.320,93.217],
[0,41.444,43.779,45.307,46.480,47.450,48.286,49.027,49.697,50.312,50.883,51.417,51.921,52.399,52.856,53.293,53.713,54.118,54.511,54.892,55.262,55.623,55.976,56.321,56.659,56.990,57.316,57.637,57.953,58.265,58.573,58.877,59.179,59.477,59.773,60.066,60.357,60.647,60.934,61.221,61.506,61.790,62.073,62.356,62.639,62.921,63.203,63.485,63.768,64.051,64.335,64.619,64.905,65.191,65.480,65.769,66.061,66.354,66.650,66.948,67.249,67.552,67.859,68.169,68.483,68.801,69.123,69.450,69.782,70.119,70.462,70.812,71.168,71.532,71.904,72.285,72.675,73.076,73.488,73.912,74.351,74.804,75.274,75.763,76.273,76.807,77.368,77.959,78.586,79.255,79.973,80.750,81.600,82.542,83.601,84.821,86.268,88.069,90.501,94.422],
[0,42.240,44.599,46.142,47.327,48.305,49.149,49.897,50.574,51.195,51.770,52.310,52.818,53.301,53.761,54.202,54.626,55.035,55.430,55.814,56.188,56.552,56.908,57.256,57.596,57.931,58.260,58.583,58.902,59.216,59.527,59.834,60.138,60.438,60.736,61.032,61.326,61.617,61.907,62.196,62.484,62.770,63.056,63.341,63.625,63.910,64.194,64.479,64.763,65.049,65.335,65.621,65.909,66.198,66.488,66.780,67.074,67.370,67.668,67.968,68.271,68.577,68.886,69.198,69.515,69.835,70.159,70.489,70.823,71.163,71.508,71.861,72.220,72.586,72.961,73.344,73.737,74.141,74.556,74.983,75.424,75.881,76.355,76.847,77.361,77.898,78.463,79.058,79.689,80.363,81.085,81.868,82.724,83.671,84.738,85.965,87.421,89.234,91.681,95.626],
[0,43.038,45.421,46.979,48.174,49.162,50.014,50.769,51.452,52.078,52.659,53.203,53.716,54.202,54.667,55.111,55.539,55.951,56.351,56.738,57.115,57.482,57.840,58.191,58.535,58.872,59.204,59.530,59.851,60.168,60.481,60.791,61.097,61.400,61.700,61.998,62.294,62.588,62.881,63.172,63.461,63.750,64.038,64.325,64.612,64.899,65.185,65.472,65.759,66.046,66.335,66.623,66.913,67.205,67.497,67.791,68.087,68.385,68.685,68.988,69.293,69.601,69.913,70.227,70.546,70.868,71.195,71.527,71.864,72.206,72.554,72.909,73.270,73.639,74.017,74.403,74.799,75.205,75.623,76.053,76.498,76.958,77.434,77.930,78.447,78.988,79.557,80.156,80.792,81.470,82.197,82.985,83.846,84.800,85.873,87.108,88.574,90.398,92.860,96.828],
[0,43.838,46.244,47.816,49.023,50.020,50.880,51.642,52.330,52.962,53.548,54.097,54.614,55.105,55.573,56.022,56.453,56.869,57.271,57.662,58.042,58.412,58.774,59.127,59.474,59.814,60.148,60.477,60.801,61.120,61.436,61.748,62.056,62.362,62.665,62.965,63.263,63.560,63.854,64.148,64.440,64.730,65.021,65.310,65.599,65.888,66.177,66.466,66.755,67.044,67.335,67.626,67.918,68.211,68.506,68.802,69.100,69.400,69.703,70.008,70.315,70.625,70.939,71.256,71.577,71.902,72.231,72.565,72.904,73.249,73.600,73.957,74.321,74.692,75.072,75.461,75.860,76.269,76.690,77.123,77.571,78.034,78.514,79.013,79.533,80.078,80.650,81.254,81.893,82.576,83.308,84.101,84.967,85.927,87.007,88.250,89.725,91.560,94.037,98.028],
[0,44.639,47.068,48.655,49.873,50.879,51.746,52.515,53.210,53.847,54.438,54.991,55.513,56.008,56.480,56.933,57.367,57.787,58.193,58.587,58.970,59.343,59.707,60.064,60.413,60.756,61.093,61.424,61.751,62.073,62.391,62.705,63.016,63.324,63.629,63.932,64.232,64.531,64.828,65.124,65.418,65.711,66.003,66.295,66.586,66.877,67.168,67.459,67.750,68.042,68.334,68.628,68.922,69.218,69.514,69.813,70.113,70.415,70.720,71.027,71.337,71.649,71.965,72.285,72.608,72.935,73.266,73.603,73.944,74.291,74.645,75.004,75.371,75.745,76.128,76.519,76.920,77.332,77.756,78.192,78.643,79.109,79.592,80.095,80.619,81.167,81.743,82.350,82.994,83.681,84.418,85.216,86.088,87.054,88.141,89.391,90.875,92.721,95.213,99.228],
[0,45.442,47.893,49.495,50.724,51.739,52.614,53.389,54.090,54.733,55.329,55.887,56.413,56.912,57.388,57.844,58.283,58.706,59.115,59.512,59.898,60.274,60.641,61.001,61.353,61.698,62.038,62.372,62.701,63.026,63.346,63.663,63.976,64.286,64.594,64.899,65.202,65.503,65.802,66.100,66.396,66.691,66.986,67.280,67.573,67.866,68.159,68.453,68.746,69.040,69.334,69.630,69.926,70.224,70.523,70.824,71.126,71.431,71.737,72.046,72.358,72.673,72.991,73.313,73.638,73.968,74.302,74.640,74.984,75.334,75.689,76.051,76.421,76.797,77.182,77.577,77.981,78.395,78.822,79.261,79.715,80.184,80.670,81.176,81.703,82.255,82.835,83.446,84.094,84.785,85.527,86.330,87.208,88.179,89.273,90.531,92.024,93.881,96.388,100.43],
[0,46.246,48.720,50.337,51.576,52.600,53.483,54.265,54.971,55.619,56.221,56.783,57.314,57.817,58.297,58.757,59.199,59.625,60.037,60.437,60.827,61.206,61.576,61.938,62.293,62.641,62.983,63.320,63.652,63.979,64.302,64.621,64.937,65.249,65.559,65.866,66.172,66.475,66.776,67.076,67.375,67.672,67.969,68.265,68.560,68.856,69.151,69.446,69.742,70.038,70.334,70.632,70.930,71.230,71.531,71.834,72.139,72.445,72.754,73.066,73.380,73.697,74.017,74.341,74.669,75.000,75.337,75.678,76.024,76.376,76.734,77.098,77.470,77.849,78.237,78.634,79.040,79.458,79.887,80.329,80.786,81.258,81.748,82.257,82.788,83.343,83.926,84.542,85.194,85.889,86.635,87.443,88.326,89.304,90.404,91.670,93.172,95.040,97.561,101.62],
[0,47.051,49.548,51.179,52.430,53.462,54.352,55.141,55.853,56.507,57.113,57.680,58.215,58.722,59.206,59.670,60.115,60.545,60.960,61.364,61.756,62.138,62.511,62.876,63.234,63.585,63.929,64.268,64.603,64.932,65.258,65.579,65.897,66.212,66.524,66.834,67.141,67.447,67.750,68.053,68.353,68.653,68.952,69.250,69.548,69.845,70.142,70.440,70.738,71.036,71.334,71.634,71.935,72.237,72.540,72.845,73.151,73.460,73.771,74.085,74.401,74.720,75.043,75.369,75.699,76.033,76.371,76.715,77.063,77.417,77.778,78.145,78.519,78.901,79.291,79.690,80.100,80.520,80.952,81.397,81.857,82.332,82.825,83.337,83.871,84.430,85.017,85.636,86.292,86.992,87.743,88.556,89.444,90.428,91.535,92.808,94.319,96.198,98.733,102.82],
[0,47.858,50.377,52.022,53.284,54.325,55.223,56.018,56.736,57.395,58.006,58.578,59.117,59.628,60.116,60.583,61.032,61.465,61.884,62.290,62.686,63.071,63.447,63.814,64.175,64.528,64.876,65.217,65.554,65.886,66.214,66.538,66.858,67.175,67.490,67.802,68.111,68.419,68.725,69.029,69.332,69.634,69.935,70.235,70.535,70.835,71.134,71.434,71.733,72.034,72.334,72.636,72.939,73.243,73.548,73.855,74.164,74.475,74.788,75.104,75.422,75.744,76.068,76.397,76.729,77.065,77.406,77.751,78.102,78.459,78.821,79.191,79.567,79.952,80.345,80.747,81.159,81.582,82.017,82.464,82.927,83.405,83.901,84.417,84.954,85.517,86.107,86.730,87.390,88.094,88.850,89.668,90.561,91.551,92.665,93.945,95.465,97.355,99.904,104.01],
[0,48.666,51.208,52.867,54.139,55.189,56.094,56.896,57.620,58.284,58.900,59.476,60.020,60.535,61.027,61.497,61.950,62.386,62.808,63.218,63.616,64.004,64.383,64.753,65.116,65.472,65.822,66.166,66.506,66.840,67.170,67.497,67.819,68.139,68.456,68.770,69.082,69.392,69.700,70.006,70.311,70.615,70.918,71.221,71.523,71.824,72.126,72.427,72.729,73.031,73.334,73.638,73.943,74.249,74.557,74.866,75.177,75.490,75.805,76.123,76.443,76.767,77.094,77.424,77.758,78.097,78.440,78.788,79.141,79.500,79.865,80.237,80.616,81.003,81.398,81.803,82.217,82.643,83.081,83.531,83.997,84.478,84.977,85.496,86.037,86.602,87.197,87.823,88.488,89.196,89.956,90.779,91.678,92.673,93.793,95.081,96.610,98.510,101.07,105.20],
[0,49.475,52.039,53.712,54.995,56.054,56.966,57.774,58.504,59.174,59.795,60.375,60.923,61.442,61.938,62.412,62.868,63.307,63.733,64.145,64.547,64.937,65.319,65.692,66.058,66.417,66.769,67.116,67.458,67.794,68.127,68.456,68.781,69.103,69.422,69.738,70.052,70.364,70.674,70.983,71.290,71.596,71.902,72.206,72.510,72.814,73.117,73.421,73.725,74.029,74.334,74.640,74.947,75.255,75.565,75.876,76.189,76.504,76.821,77.141,77.464,77.790,78.119,78.451,78.788,79.129,79.474,79.824,80.179,80.541,80.908,81.282,81.664,82.053,82.451,82.858,83.275,83.704,84.144,84.598,85.066,85.550,86.052,86.574,87.118,87.688,88.286,88.916,89.584,90.297,91.061,91.889,92.793,93.795,94.921,96.217,97.753,99.665,102.24,106.39],
[0,50.286,52.872,54.559,55.852,56.920,57.839,58.654,59.390,60.064,60.690,61.275,61.827,62.350,62.849,63.327,63.786,64.229,64.658,65.074,65.478,65.872,66.256,66.632,67.000,67.362,67.717,68.066,68.410,68.749,69.084,69.415,69.743,70.067,70.388,70.707,71.023,71.337,71.649,71.960,72.270,72.578,72.885,73.192,73.498,73.804,74.109,74.415,74.721,75.027,75.334,75.642,75.951,76.261,76.573,76.886,77.201,77.519,77.838,78.160,78.485,78.813,79.144,79.478,79.817,80.160,80.507,80.860,81.218,81.581,81.951,82.328,82.711,83.103,83.504,83.913,84.333,84.764,85.207,85.664,86.135,86.622,87.127,87.652,88.200,88.772,89.374,90.008,90.680,91.397,92.166,92.998,93.908,94.915,96.048,97.351,98.896,100.82,103.41,107.58],
[0,51.097,53.705,55.407,56.710,57.786,58.713,59.534,60.276,60.955,61.586,62.176,62.732,63.259,63.762,64.243,64.706,65.152,65.584,66.002,66.409,66.806,67.193,67.572,67.943,68.307,68.664,69.016,69.363,69.704,70.042,70.375,70.705,71.031,71.354,71.675,71.994,72.310,72.625,72.937,73.249,73.559,73.869,74.177,74.486,74.793,75.101,75.409,75.717,76.025,76.334,76.644,76.955,77.267,77.581,77.896,78.214,78.533,78.854,79.178,79.505,79.835,80.169,80.505,80.846,81.191,81.541,81.896,82.256,82.621,82.994,83.372,83.759,84.153,84.556,84.968,85.391,85.824,86.270,86.729,87.203,87.693,88.201,88.730,89.280,89.857,90.462,91.100,91.776,92.497,93.270,94.107,95.022,96.035,97.174,98.484,100.04,101.97,104.58,108.77],
[0,51.910,54.540,56.255,57.570,58.654,59.588,60.415,61.162,61.847,62.483,63.077,63.637,64.168,64.675,65.159,65.625,66.075,66.510,66.931,67.341,67.741,68.131,68.512,68.886,69.252,69.612,69.967,70.316,70.660,70.999,71.335,71.667,71.995,72.321,72.644,72.965,73.283,73.600,73.915,74.228,74.541,74.852,75.163,75.473,75.783,76.093,76.403,76.713,77.023,77.334,77.646,77.959,78.274,78.589,78.907,79.226,79.547,79.871,80.197,80.526,80.858,81.193,81.532,81.875,82.222,82.574,82.931,83.293,83.661,84.036,84.417,84.806,85.202,85.608,86.022,86.447,86.884,87.332,87.794,88.271,88.764,89.275,89.807,90.361,90.940,91.549,92.190,92.871,93.596,94.374,95.215,96.135,97.154,98.300,99.617,101.18,103.12,105.74,109.96],
[0,52.725,55.376,57.105,58.429,59.522,60.463,61.297,62.050,62.740,63.380,63.979,64.543,65.078,65.588,66.076,66.546,66.998,67.436,67.861,68.274,68.676,69.069,69.453,69.829,70.198,70.561,70.918,71.269,71.615,71.957,72.295,72.629,72.960,73.288,73.613,73.936,74.257,74.575,74.892,75.208,75.523,75.836,76.149,76.461,76.773,77.085,77.397,77.709,78.021,78.334,78.648,78.963,79.280,79.597,79.917,80.238,80.561,80.887,81.215,81.546,81.880,82.218,82.559,82.904,83.253,83.607,83.966,84.331,84.701,85.078,85.462,85.852,86.252,86.659,87.077,87.504,87.943,88.394,88.859,89.338,89.834,90.349,90.883,91.440,92.023,92.635,93.281,93.965,94.694,95.476,96.323,97.248,98.272,99.424,100.75,102.32,104.27,106.91,111.14],
[0,53.540,56.213,57.955,59.290,60.391,61.340,62.179,62.938,63.633,64.278,64.881,65.449,65.988,66.502,66.994,67.467,67.922,68.363,68.791,69.207,69.612,70.007,70.394,70.773,71.145,71.510,71.869,72.222,72.571,72.915,73.256,73.592,73.925,74.255,74.582,74.907,75.230,75.551,75.870,76.188,76.504,76.820,77.135,77.449,77.763,78.077,78.391,78.705,79.019,79.334,79.650,79.967,80.286,80.605,80.927,81.250,81.575,81.903,82.233,82.566,82.902,83.242,83.585,83.932,84.284,84.640,85.001,85.368,85.741,86.120,86.506,86.899,87.300,87.711,88.130,88.560,89.002,89.456,89.923,90.405,90.904,91.421,91.959,92.519,93.106,93.721,94.370,95.058,95.791,96.578,97.429,98.360,99.389,100.55,101.88,103.46,105.42,108.07,112.33],
[0,54.357,57.051,58.807,60.152,61.261,62.217,63.063,63.827,64.527,65.176,65.784,66.356,66.899,67.416,67.912,68.388,68.847,69.291,69.722,70.140,70.548,70.946,71.336,71.717,72.091,72.459,72.820,73.176,73.527,73.874,74.216,74.555,74.890,75.222,75.552,75.879,76.204,76.527,76.848,77.168,77.486,77.804,78.121,78.437,78.753,79.069,79.385,79.701,80.017,80.334,80.652,80.971,81.292,81.613,81.937,82.262,82.589,82.919,83.251,83.586,83.925,84.266,84.612,84.961,85.314,85.673,86.036,86.405,86.780,87.161,87.549,87.945,88.349,88.761,89.184,89.616,90.060,90.517,90.987,91.472,91.974,92.494,93.035,93.598,94.188,94.807,95.460,96.151,96.888,97.680,98.536,99.471,100.51,101.67,103.01,104.60,106.57,109.23,113.51],
[0,55.174,57.890,59.659,61.014,62.132,63.095,63.947,64.716,65.422,66.076,66.687,67.264,67.810,68.331,68.830,69.310,69.772,70.219,70.653,71.074,71.485,71.886,72.278,72.661,73.038,73.408,73.772,74.130,74.484,74.833,75.177,75.518,75.856,76.190,76.522,76.851,77.178,77.503,77.826,78.148,78.469,78.788,79.107,79.425,79.743,80.061,80.379,80.697,81.015,81.334,81.654,81.975,82.297,82.621,82.946,83.274,83.603,83.935,84.269,84.606,84.947,85.290,85.638,85.989,86.345,86.705,87.071,87.442,87.819,88.202,88.593,88.991,89.397,89.812,90.237,90.672,91.118,91.577,92.050,92.538,93.043,93.566,94.110,94.676,95.269,95.892,96.548,97.244,97.985,98.780,99.641,100.58,101.62,102.79,104.14,105.73,107.72,110.39,114.69],
[0,55.993,58.729,60.512,61.878,63.004,63.973,64.832,65.607,66.317,66.976,67.592,68.172,68.722,69.247,69.749,70.232,70.697,71.147,71.584,72.008,72.422,72.825,73.220,73.606,73.985,74.358,74.724,75.085,75.440,75.792,76.138,76.482,76.821,77.158,77.492,77.823,78.152,78.479,78.804,79.128,79.451,79.772,80.093,80.413,80.733,81.053,81.373,81.693,82.013,82.334,82.656,82.979,83.303,83.629,83.956,84.285,84.617,84.951,85.287,85.626,85.968,86.314,86.664,87.017,87.375,87.738,88.105,88.479,88.858,89.243,89.636,90.036,90.445,90.862,91.289,91.727,92.176,92.638,93.113,93.604,94.111,94.637,95.184,95.754,96.350,96.976,97.636,98.335,99.081,99.880,100.75,101.69,102.74,103.91,105.27,106.87,108.87,111.55,115.88],
[0,56.813,59.570,61.367,62.742,63.876,64.853,65.717,66.498,67.213,67.876,68.496,69.081,69.635,70.163,70.669,71.155,71.623,72.076,72.516,72.943,73.359,73.765,74.162,74.551,74.933,75.308,75.676,76.039,76.397,76.751,77.100,77.445,77.787,78.126,78.462,78.795,79.126,79.455,79.782,80.108,80.433,80.757,81.079,81.402,81.724,82.045,82.367,82.689,83.011,83.334,83.658,83.983,84.309,84.637,84.966,85.297,85.631,85.966,86.305,86.646,86.990,87.338,87.689,88.045,88.405,88.770,89.139,89.515,89.896,90.284,90.679,91.082,91.493,91.912,92.342,92.782,93.234,93.698,94.176,94.669,95.180,95.709,96.258,96.831,97.431,98.060,98.724,99.427,100.18,100.98,101.85,102.80,103.85,105.03,106.39,108.01,110.01,112.71,117.06],
[0,57.634,60.412,62.222,63.607,64.749,65.733,66.603,67.389,68.109,68.777,69.402,69.990,70.548,71.080,71.589,72.078,72.549,73.006,73.448,73.878,74.297,74.706,75.105,75.497,75.881,76.258,76.629,76.994,77.355,77.710,78.062,78.409,78.753,79.094,79.432,79.767,80.100,80.431,80.761,81.089,81.415,81.741,82.066,82.390,82.714,83.037,83.361,83.685,84.009,84.334,84.660,84.987,85.315,85.644,85.976,86.309,86.644,86.982,87.322,87.665,88.012,88.361,88.715,89.073,89.435,89.801,90.173,90.551,90.935,91.325,91.722,92.127,92.540,92.962,93.394,93.836,94.291,94.757,95.238,95.734,96.247,96.779,97.332,97.908,98.511,99.144,99.811,100.52,101.27,102.08,102.95,103.91,104.97,106.15,107.52,109.14,111.16,113.87,118.24],
[0,58.456,61.255,63.078,64.473,65.623,66.613,67.490,68.281,69.007,69.679,70.308,70.900,71.462,71.997,72.509,73.001,73.476,73.935,74.381,74.813,75.235,75.646,76.048,76.442,76.829,77.209,77.582,77.950,78.312,78.670,79.023,79.373,79.719,80.062,80.402,80.740,81.075,81.408,81.739,82.069,82.398,82.726,83.052,83.378,83.704,84.030,84.355,84.681,85.007,85.334,85.662,85.991,86.321,86.652,86.985,87.320,87.658,87.997,88.340,88.685,89.033,89.385,89.740,90.100,90.464,90.833,91.207,91.587,91.973,92.365,92.764,93.172,93.587,94.011,94.446,94.891,95.347,95.817,96.300,96.799,97.315,97.849,98.405,98.984,99.590,100.23,100.90,101.61,102.36,103.18,104.06,105.02,106.08,107.27,108.65,110.28,112.30,115.03,119.41],
[0,59.279,62.098,63.934,65.339,66.498,67.495,68.377,69.174,69.904,70.581,71.214,71.810,72.376,72.914,73.430,73.926,74.403,74.865,75.313,75.749,76.173,76.587,76.992,77.389,77.777,78.159,78.535,78.905,79.270,79.630,79.986,80.337,80.686,81.031,81.373,81.712,82.049,82.385,82.718,83.050,83.381,83.710,84.039,84.367,84.695,85.022,85.350,85.677,86.005,86.334,86.664,86.995,87.326,87.660,87.995,88.332,88.671,89.013,89.357,89.704,90.054,90.408,90.766,91.127,91.494,91.865,92.241,92.623,93.011,93.405,93.807,94.216,94.634,95.061,95.497,95.945,96.404,96.876,97.362,97.863,98.382,98.919,99.478,100.06,100.67,101.31,101.98,102.70,103.46,104.28,105.16,106.12,107.19,108.39,109.77,111.41,113.44,116.18,120.59],
[0,60.103,62.943,64.792,66.207,67.373,68.377,69.266,70.068,70.803,71.484,72.121,72.721,73.290,73.832,74.351,74.850,75.331,75.796,76.247,76.685,77.112,77.529,77.936,78.335,78.726,79.111,79.489,79.861,80.228,80.590,80.948,81.302,81.652,81.999,82.343,82.685,83.024,83.361,83.697,84.031,84.363,84.695,85.025,85.355,85.685,86.014,86.344,86.674,87.004,87.334,87.666,87.998,88.332,88.667,89.004,89.343,89.685,90.028,90.374,90.723,91.076,91.431,91.791,92.155,92.523,92.896,93.274,93.658,94.048,94.445,94.849,95.260,95.680,96.109,96.548,96.998,97.460,97.934,98.423,98.927,99.448,99.989,100.55,101.14,101.75,102.39,103.07,103.79,104.55,105.37,106.26,107.23,108.30,109.51,110.90,112.54,114.59,117.34,121.77],
[0,60.928,63.788,65.650,67.075,68.249,69.260,70.154,70.962,71.702,72.387,73.028,73.632,74.205,74.751,75.273,75.775,76.259,76.727,77.181,77.622,78.051,78.470,78.880,79.282,79.675,80.062,80.442,80.817,81.186,81.550,81.910,82.267,82.619,82.968,83.314,83.658,83.999,84.338,84.676,85.012,85.346,85.680,86.012,86.344,86.676,87.007,87.338,87.670,88.002,88.334,88.668,89.002,89.338,89.675,90.014,90.355,90.698,91.043,91.391,91.742,92.097,92.454,92.816,93.182,93.552,93.927,94.307,94.693,95.086,95.484,95.890,96.304,96.727,97.158,97.599,98.052,98.516,98.993,99.484,99.991,100.51,101.06,101.62,102.21,102.83,103.47,104.15,104.88,105.64,106.47,107.36,108.34,109.41,110.63,112.02,113.67,115.73,118.49,122.94],
[0,61.754,64.635,66.509,67.944,69.126,70.143,71.044,71.856,72.601,73.291,73.936,74.544,75.121,75.670,76.195,76.700,77.187,77.658,78.115,78.558,78.991,79.412,79.825,80.229,80.625,81.014,81.396,81.773,82.145,82.511,82.873,83.231,83.586,83.937,84.285,84.631,84.974,85.315,85.655,85.993,86.329,86.664,86.999,87.333,87.666,87.999,88.333,88.666,89.000,89.334,89.670,90.006,90.343,90.683,91.023,91.366,91.711,92.058,92.408,92.761,93.118,93.477,93.841,94.209,94.581,94.958,95.340,95.728,96.123,96.524,96.932,97.348,97.772,98.206,98.650,99.105,99.571,100.05,100.54,101.05,101.58,102.13,102.69,103.29,103.90,104.55,105.24,105.96,106.74,107.57,108.46,109.44,110.53,111.74,113.15,114.81,116.87,119.65,124.12],
[0,62.581,65.482,67.369,68.813,70.003,71.027,71.934,72.752,73.501,74.196,74.845,75.457,76.037,76.589,77.118,77.626,78.116,78.590,79.049,79.496,79.930,80.355,80.770,81.176,81.574,81.966,82.351,82.730,83.103,83.472,83.836,84.196,84.553,84.906,85.257,85.604,85.949,86.293,86.634,86.974,87.312,87.649,87.986,88.321,88.657,88.992,89.327,89.662,89.998,90.334,90.671,91.010,91.349,91.690,92.033,92.377,92.724,93.073,93.425,93.780,94.138,94.500,94.866,95.235,95.610,95.989,96.373,96.763,97.160,97.563,97.973,98.391,98.818,99.254,99.700,100.16,100.63,101.11,101.60,102.12,102.65,103.19,103.77,104.36,104.98,105.63,106.32,107.05,107.83,108.66,109.56,110.55,111.64,112.86,114.27,115.94,118.01,120.80,125.29],
[0,63.409,66.330,68.230,69.684,70.882,71.912,72.824,73.647,74.402,75.100,75.754,76.370,76.953,77.509,78.041,78.552,79.045,79.522,79.984,80.433,80.871,81.297,81.715,82.123,82.524,82.918,83.305,83.686,84.062,84.433,84.799,85.162,85.520,85.876,86.228,86.578,86.925,87.270,87.613,87.955,88.295,88.634,88.973,89.310,89.647,89.984,90.321,90.658,90.996,91.334,91.673,92.013,92.355,92.698,93.042,93.389,93.737,94.088,94.442,94.799,95.159,95.523,95.890,96.262,96.638,97.019,97.406,97.798,98.197,98.602,99.014,99.435,99.864,100.30,100.75,101.21,101.68,102.17,102.66,103.18,103.71,104.26,104.84,105.43,106.06,106.71,107.41,108.14,108.92,109.76,110.66,111.65,112.74,113.98,115.39,117.07,119.15,121.95,126.46],
[0,64.238,67.179,69.091,70.555,71.760,72.798,73.715,74.544,75.303,76.006,76.663,77.283,77.870,78.429,78.965,79.479,79.975,80.454,80.919,81.371,81.811,82.240,82.660,83.071,83.474,83.870,84.260,84.643,85.021,85.394,85.763,86.127,86.488,86.845,87.200,87.551,87.900,88.247,88.593,88.936,89.278,89.619,89.960,90.299,90.638,90.977,91.316,91.655,91.994,92.334,92.675,93.017,93.360,93.705,94.051,94.400,94.750,95.103,95.459,95.818,96.180,96.545,96.915,97.288,97.667,98.050,98.438,98.833,99.233,99.641,100.06,100.48,100.91,101.35,101.80,102.26,102.74,103.22,103.72,104.24,104.78,105.33,105.91,106.51,107.13,107.79,108.49,109.22,110.01,110.85,111.76,112.75,113.85,115.09,116.51,118.19,120.29,123.10,127.63],
[0,65.068,68.028,69.954,71.426,72.640,73.684,74.607,75.441,76.204,76.912,77.573,78.197,78.787,79.350,79.889,80.406,80.905,81.387,81.855,82.309,82.752,83.184,83.606,84.019,84.425,84.823,85.215,85.600,85.981,86.356,86.726,87.093,87.456,87.815,88.171,88.525,88.876,89.225,89.572,89.917,90.262,90.605,90.947,91.288,91.629,91.970,92.310,92.651,92.992,93.334,93.677,94.021,94.366,94.712,95.061,95.411,95.763,96.118,96.476,96.836,97.200,97.568,97.939,98.315,98.695,99.080,99.471,99.867,100.27,100.68,101.10,101.52,101.95,102.40,102.85,103.31,103.79,104.28,104.78,105.30,105.84,106.40,106.98,107.58,108.21,108.87,109.57,110.31,111.10,111.94,112.86,113.86,114.96,116.20,117.63,119.32,121.42,124.26,128.80],
[0,65.898,68.879,70.817,72.299,73.520,74.570,75.500,76.338,77.107,77.818,78.484,79.111,79.705,80.271,80.813,81.334,81.835,82.320,82.791,83.248,83.693,84.127,84.552,84.968,85.376,85.776,86.170,86.558,86.940,87.317,87.690,88.059,88.423,88.785,89.143,89.499,89.852,90.203,90.552,90.899,91.245,91.590,91.934,92.277,92.620,92.962,93.305,93.647,93.990,94.334,94.679,95.024,95.371,95.720,96.070,96.422,96.776,97.133,97.492,97.855,98.221,98.590,98.963,99.341,99.723,100.11,100.50,100.90,101.31,101.72,102.14,102.56,103.00,103.44,103.90,104.37,104.84,105.34,105.84,106.36,106.90,107.46,108.05,108.65,109.29,109.95,110.65,111.40,112.19,113.04,113.96,114.96,116.07,117.32,118.75,120.45,122.56,125.40,129.97],
[0,66.730,69.730,71.680,73.172,74.401,75.457,76.392,77.236,78.009,78.725,79.395,80.026,80.623,81.193,81.738,82.261,82.766,83.254,83.727,84.187,84.634,85.071,85.498,85.917,86.327,86.729,87.126,87.516,87.900,88.279,88.654,89.025,89.392,89.755,90.115,90.473,90.828,91.180,91.531,91.881,92.228,92.575,92.921,93.266,93.611,93.955,94.299,94.644,94.989,95.334,95.681,96.028,96.377,96.727,97.079,97.433,97.789,98.148,98.509,98.873,99.241,99.612,99.987,100.37,100.75,101.14,101.53,101.94,102.34,102.76,103.18,103.61,104.04,104.49,104.95,105.42,105.90,106.39,106.90,107.43,107.97,108.53,109.12,109.72,110.36,111.03,111.74,112.48,113.28,114.13,115.05,116.06,117.18,118.43,119.87,121.58,123.70,126.55,131.14],
[0,67.562,70.582,72.545,74.045,75.282,76.345,77.286,78.135,78.912,79.633,80.306,80.941,81.542,82.115,82.663,83.189,83.697,84.188,84.664,85.126,85.576,86.015,86.445,86.866,87.278,87.683,88.081,88.473,88.860,89.241,89.618,89.991,90.360,90.725,91.087,91.447,91.804,92.158,92.511,92.862,93.212,93.560,93.908,94.255,94.601,94.948,95.294,95.640,95.987,96.334,96.682,97.032,97.382,97.734,98.088,98.444,98.802,99.162,99.525,99.892,100.26,100.63,101.01,101.39,101.78,102.17,102.57,102.97,103.38,103.79,104.22,104.65,105.09,105.54,106.00,106.47,106.95,107.45,107.96,108.49,109.03,109.60,110.18,110.80,111.44,112.11,112.82,113.57,114.37,115.22,116.15,117.16,118.28,119.54,120.99,122.70,124.83,127.70,132.31],
[0,68.396,71.434,73.410,74.920,76.164,77.234,78.180,79.034,79.816,80.541,81.218,81.856,82.461,83.037,83.588,84.118,84.628,85.122,85.600,86.065,86.518,86.960,87.392,87.815,88.229,88.637,89.037,89.432,89.820,90.204,90.583,90.957,91.328,91.695,92.060,92.421,92.780,93.136,93.491,93.844,94.196,94.546,94.895,95.244,95.592,95.940,96.288,96.636,96.985,97.334,97.684,98.035,98.388,98.741,99.097,99.455,99.814,100.18,100.54,100.91,101.28,101.66,102.04,102.42,102.81,103.20,103.60,104.00,104.41,104.83,105.26,105.69,106.13,106.58,107.05,107.52,108.00,108.50,109.02,109.55,110.09,110.66,111.25,111.87,112.51,113.19,113.90,114.65,115.45,116.32,117.25,118.26,119.39,120.65,122.11,123.83,125.97,128.85,133.48],
[0,69.230,72.288,74.275,75.795,77.046,78.123,79.075,79.934,80.720,81.449,82.131,82.772,83.381,83.960,84.514,85.047,85.560,86.057,86.538,87.005,87.460,87.905,88.339,88.764,89.181,89.591,89.993,90.390,90.781,91.166,91.547,91.924,92.297,92.666,93.032,93.395,93.756,94.115,94.471,94.826,95.179,95.532,95.883,96.233,96.583,96.933,97.283,97.633,97.983,98.334,98.686,99.039,99.393,99.749,100.11,100.47,100.83,101.19,101.56,101.93,102.30,102.68,103.06,103.44,103.83,104.23,104.63,105.04,105.45,105.87,106.30,106.73,107.18,107.63,108.09,108.57,109.06,109.56,110.07,110.61,111.16,111.73,112.32,112.94,113.59,114.26,114.98,115.74,116.54,117.41,118.34,119.36,120.49,121.77,123.23,124.95,127.10,130.00,134.64],
[0,70.065,73.142,75.142,76.671,77.929,79.012,79.970,80.834,81.625,82.358,83.043,83.689,84.300,84.883,85.441,85.976,86.492,86.991,87.475,87.945,88.403,88.850,89.286,89.714,90.133,90.545,90.950,91.348,91.741,92.129,92.512,92.891,93.265,93.637,94.005,94.370,94.732,95.093,95.451,95.808,96.163,96.517,96.870,97.223,97.574,97.926,98.278,98.629,98.981,99.334,99.688,100.04,100.40,100.76,101.11,101.48,101.84,102.21,102.57,102.95,103.32,103.70,104.08,104.47,104.86,105.26,105.66,106.07,106.48,106.91,107.34,107.77,108.22,108.67,109.14,109.62,110.11,110.61,111.13,111.67,112.22,112.79,113.39,114.01,114.66,115.34,116.06,116.82,117.63,118.50,119.44,120.46,121.60,122.88,124.34,126.08,128.24,131.14,135.81],
[0,70.901,73.997,76.009,77.547,78.813,79.902,80.865,81.734,82.530,83.267,83.957,84.606,85.221,85.807,86.367,86.906,87.425,87.927,88.413,88.886,89.346,89.795,90.234,90.664,91.085,91.499,91.906,92.307,92.702,93.092,93.477,93.857,94.234,94.607,94.977,95.344,95.709,96.071,96.431,96.790,97.147,97.503,97.858,98.212,98.566,98.919,99.272,99.626,99.980,100.33,100.69,101.05,101.40,101.76,102.12,102.49,102.85,103.22,103.59,103.96,104.34,104.72,105.11,105.50,105.89,106.29,106.69,107.10,107.52,107.94,108.37,108.81,109.26,109.72,110.19,110.67,111.16,111.67,112.19,112.73,113.28,113.86,114.46,115.08,115.73,116.42,117.14,117.90,118.72,119.59,120.53,121.56,122.70,123.99,125.46,127.20,129.37,132.29,136.97],
[0,71.738,74.853,76.877,78.424,79.698,80.793,81.762,82.636,83.436,84.177,84.870,85.523,86.141,86.731,87.294,87.836,88.358,88.862,89.351,89.826,90.289,90.741,91.182,91.614,92.038,92.454,92.863,93.266,93.663,94.055,94.442,94.824,95.203,95.578,95.950,96.319,96.685,97.050,97.412,97.772,98.131,98.489,98.845,99.201,99.557,99.912,100.27,100.62,100.98,101.33,101.69,102.05,102.41,102.77,103.13,103.50,103.86,104.23,104.61,104.98,105.36,105.74,106.13,106.52,106.92,107.32,107.72,108.14,108.55,108.98,109.41,109.85,110.31,110.77,111.24,111.72,112.21,112.72,113.25,113.79,114.34,114.92,115.52,116.15,116.81,117.49,118.22,118.98,119.80,120.68,121.63,122.66,123.81,125.10,126.57,128.33,130.50,133.43,138.13],
[0,72.575,75.709,77.745,79.301,80.582,81.684,82.658,83.537,84.342,85.088,85.784,86.441,87.063,87.655,88.222,88.766,89.291,89.798,90.290,90.767,91.233,91.687,92.130,92.565,92.991,93.409,93.820,94.225,94.624,95.018,95.407,95.792,96.172,96.549,96.923,97.294,97.662,98.028,98.392,98.754,99.115,99.474,99.833,100.19,100.55,100.90,101.26,101.62,101.98,102.33,102.69,103.05,103.41,103.78,104.14,104.51,104.88,105.25,105.62,106.00,106.38,106.76,107.15,107.55,107.94,108.35,108.75,109.17,109.59,110.02,110.45,110.90,111.35,111.81,112.28,112.77,113.27,113.78,114.30,114.84,115.41,115.99,116.59,117.22,117.88,118.57,119.30,120.07,120.89,121.77,122.72,123.76,124.91,126.20,127.69,129.45,131.63,134.57,139.30],
[0,73.413,76.567,78.614,80.179,81.468,82.576,83.555,84.439,85.249,85.998,86.699,87.359,87.984,88.580,89.149,89.697,90.224,90.734,91.228,91.709,92.176,92.633,93.079,93.515,93.944,94.364,94.777,95.184,95.586,95.981,96.372,96.759,97.142,97.521,97.896,98.269,98.639,99.007,99.373,99.737,100.10,100.46,100.82,101.18,101.54,101.90,102.26,102.62,102.97,103.33,103.69,104.06,104.42,104.78,105.15,105.52,105.89,106.26,106.64,107.02,107.40,107.79,108.18,108.57,108.97,109.37,109.78,110.20,110.62,111.05,111.49,111.94,112.39,112.86,113.33,113.82,114.32,114.83,115.36,115.90,116.47,117.05,117.66,118.29,118.95,119.64,120.37,121.15,121.97,122.86,123.81,124.86,126.01,127.31,128.80,130.57,132.76,135.72,140.46],
[0,74.252,77.424,79.484,81.058,82.354,83.468,84.453,85.342,86.156,86.909,87.614,88.277,88.906,89.505,90.077,90.628,91.158,91.671,92.168,92.650,93.120,93.579,94.027,94.466,94.897,95.319,95.735,96.144,96.547,96.945,97.338,97.727,98.111,98.492,98.869,99.244,99.616,99.986,100.35,100.72,101.08,101.45,101.81,102.17,102.53,102.89,103.25,103.61,103.97,104.33,104.70,105.06,105.42,105.79,106.16,106.53,106.90,107.28,107.65,108.03,108.42,108.81,109.20,109.60,110.00,110.40,110.82,111.23,111.66,112.09,112.53,112.98,113.43,113.90,114.38,114.87,115.37,115.88,116.41,116.96,117.53,118.11,118.72,119.36,120.02,120.72,121.45,122.23,123.06,123.95,124.91,125.96,127.12,128.42,129.92,131.69,133.89,136.86,141.62],
[0,75.092,78.283,80.354,81.937,83.240,84.361,85.351,86.245,87.063,87.821,88.529,89.196,89.828,90.430,91.006,91.559,92.092,92.607,93.107,93.592,94.065,94.526,94.976,95.418,95.850,96.275,96.693,97.104,97.509,97.909,98.304,98.694,99.081,99.463,99.843,100.22,100.59,100.96,101.33,101.70,102.07,102.43,102.80,103.16,103.52,103.88,104.25,104.61,104.97,105.33,105.70,106.06,106.43,106.80,107.17,107.54,107.91,108.29,108.67,109.05,109.44,109.83,110.22,110.62,111.02,111.43,111.85,112.27,112.69,113.13,113.57,114.02,114.48,114.94,115.42,115.92,116.42,116.94,117.47,118.02,118.59,119.18,119.79,120.43,121.09,121.79,122.53,123.31,124.14,125.04,126.00,127.05,128.22,129.53,131.03,132.81,135.02,138.00,142.78],
[0,75.933,79.142,81.225,82.817,84.127,85.254,86.250,87.148,87.971,88.733,89.445,90.115,90.751,91.356,91.935,92.491,93.027,93.545,94.047,94.534,95.009,95.473,95.926,96.369,96.804,97.231,97.650,98.064,98.471,98.873,99.270,99.662,100.05,100.44,100.82,101.19,101.57,101.94,102.31,102.68,103.05,103.42,103.78,104.15,104.51,104.88,105.24,105.60,105.97,106.33,106.70,107.07,107.43,107.80,108.18,108.55,108.93,109.30,109.69,110.07,110.46,110.85,111.24,111.64,112.05,112.46,112.88,113.30,113.73,114.16,114.61,115.06,115.52,115.99,116.47,116.96,117.47,117.99,118.53,119.08,119.65,120.24,120.85,121.50,122.16,122.87,123.61,124.39,125.23,126.12,127.09,128.15,129.32,130.63,132.14,133.93,136.15,139.14,143.94],
[0,76.774,80.002,82.097,83.697,85.015,86.147,87.149,88.052,88.879,89.645,90.361,91.035,91.674,92.282,92.864,93.423,93.961,94.482,94.986,95.477,95.954,96.420,96.875,97.321,97.758,98.187,98.609,99.024,99.433,99.837,100.24,100.63,101.02,101.41,101.79,102.17,102.55,102.92,103.30,103.67,104.04,104.40,104.77,105.14,105.50,105.87,106.24,106.60,106.97,107.33,107.70,108.07,108.44,108.81,109.18,109.56,109.94,110.32,110.70,111.09,111.48,111.87,112.27,112.67,113.08,113.49,113.91,114.33,114.76,115.20,115.64,116.10,116.56,117.03,117.52,118.01,118.52,119.04,119.58,120.14,120.71,121.30,121.92,122.56,123.24,123.94,124.68,125.47,126.31,127.21,128.18,129.25,130.42,131.74,133.26,135.05,137.28,140.28,145.10],
[0,77.616,80.862,82.969,84.578,85.903,87.042,88.048,88.957,89.788,90.558,91.277,91.955,92.597,93.208,93.793,94.355,94.896,95.420,95.927,96.419,96.899,97.367,97.825,98.273,98.712,99.143,99.567,99.984,100.40,100.80,101.20,101.60,101.99,102.38,102.76,103.15,103.52,103.90,104.28,104.65,105.02,105.39,105.76,106.13,106.50,106.86,107.23,107.60,107.97,108.33,108.70,109.07,109.45,109.82,110.19,110.57,110.95,111.33,111.72,112.10,112.50,112.89,113.29,113.69,114.10,114.52,114.94,115.36,115.79,116.23,116.68,117.14,117.60,118.08,118.56,119.06,119.57,120.10,120.64,121.19,121.77,122.37,122.98,123.63,124.31,125.01,125.76,126.55,127.39,128.30,129.27,130.34,131.52,132.85,134.37,136.17,138.41,141.42,146.26],
[0,78.459,81.723,83.842,85.460,86.792,87.936,88.948,89.861,90.697,91.471,92.194,92.875,93.521,94.135,94.723,95.287,95.832,96.357,96.867,97.362,97.845,98.315,98.775,99.225,99.666,100.10,100.53,100.94,101.36,101.77,102.17,102.57,102.96,103.35,103.74,104.12,104.50,104.88,105.26,105.63,106.01,106.38,106.75,107.12,107.49,107.86,108.23,108.59,108.96,109.33,109.70,110.08,110.45,110.83,111.20,111.58,111.96,112.35,112.73,113.12,113.51,113.91,114.31,114.72,115.13,115.54,115.97,116.39,116.83,117.27,117.72,118.18,118.64,119.12,119.61,120.11,120.62,121.15,121.69,122.25,122.83,123.43,124.05,124.70,125.38,126.09,126.84,127.63,128.48,129.39,130.37,131.44,132.62,133.95,135.48,137.29,139.54,142.56,147.41],
[0,79.302,82.585,84.715,86.342,87.681,88.832,89.849,90.767,91.607,92.385,93.112,93.796,94.445,95.062,95.653,96.220,96.767,97.296,97.808,98.306,98.790,99.263,99.725,100.18,100.62,101.06,101.48,101.91,102.32,102.73,103.13,103.53,103.93,104.32,104.71,105.10,105.48,105.86,106.24,106.62,106.99,107.36,107.74,108.11,108.48,108.85,109.22,109.59,109.96,110.33,110.71,111.08,111.46,111.83,112.21,112.59,112.97,113.36,113.75,114.14,114.53,114.93,115.33,115.74,116.15,116.57,117.00,117.42,117.86,118.30,118.76,119.22,119.68,120.16,120.65,121.16,121.67,122.20,122.74,123.31,123.89,124.49,125.11,125.77,126.45,127.16,127.91,128.71,129.56,130.47,131.46,132.53,133.72,135.06,136.59,138.41,140.66,143.70,148.57],
[0,80.146,83.447,85.589,87.224,88.570,89.727,90.750,91.672,92.517,93.299,94.029,94.717,95.369,95.990,96.583,97.154,97.703,98.234,98.749,99.249,99.736,100.21,100.68,101.13,101.58,102.01,102.44,102.87,103.28,103.69,104.10,104.50,104.90,105.30,105.69,106.07,106.46,106.84,107.22,107.60,107.97,108.35,108.72,109.10,109.47,109.84,110.22,110.59,110.96,111.33,111.71,112.08,112.46,112.84,113.22,113.60,113.99,114.37,114.76,115.16,115.55,115.95,116.36,116.77,117.18,117.60,118.02,118.46,118.89,119.34,119.79,120.25,120.73,121.21,121.70,122.20,122.72,123.25,123.80,124.36,124.95,125.55,126.18,126.83,127.52,128.23,128.99,129.79,130.64,131.56,132.55,133.63,134.82,136.16,137.70,139.53,141.79,144.84,149.73],
[0,80.991,84.310,86.463,88.107,89.461,90.623,91.651,92.578,93.427,94.213,94.947,95.639,96.294,96.917,97.514,98.087,98.639,99.173,99.690,100.19,100.68,101.16,101.63,102.08,102.53,102.97,103.40,103.83,104.25,104.66,105.07,105.47,105.87,106.27,106.66,107.05,107.44,107.82,108.20,108.58,108.96,109.34,109.71,110.09,110.46,110.84,111.21,111.58,111.96,112.33,112.71,113.09,113.47,113.85,114.23,114.61,115.00,115.39,115.78,116.17,116.57,116.97,117.38,117.79,118.21,118.63,119.05,119.49,119.93,120.37,120.83,121.29,121.77,122.25,122.74,123.25,123.77,124.30,124.85,125.42,126.00,126.61,127.24,127.90,128.59,129.31,130.06,130.87,131.73,132.64,133.64,134.72,135.92,137.26,138.81,140.64,142.92,145.97,150.88],
[0,81.837,85.173,87.338,88.991,90.351,91.520,92.553,93.485,94.338,95.128,95.866,96.560,97.219,97.845,98.445,99.021,99.576,100.11,100.63,101.14,101.63,102.11,102.58,103.04,103.49,103.93,104.36,104.79,105.21,105.62,106.04,106.44,106.84,107.24,107.63,108.03,108.41,108.80,109.18,109.56,109.94,110.32,110.70,111.08,111.45,111.83,112.21,112.58,112.96,113.33,113.71,114.09,114.47,114.85,115.24,115.62,116.01,116.40,116.79,117.19,117.59,117.99,118.40,118.81,119.23,119.65,120.08,120.52,120.96,121.41,121.87,122.33,122.81,123.29,123.79,124.30,124.82,125.35,125.91,126.48,127.06,127.67,128.31,128.96,129.65,130.38,131.14,131.95,132.81,133.73,134.73,135.81,137.02,138.37,139.92,141.76,144.04,147.11,152.04],
[0,82.683,86.038,88.214,89.875,91.242,92.417,93.455,94.392,95.249,96.043,96.784,97.483,98.144,98.774,99.376,99.955,100.51,101.05,101.57,102.08,102.57,103.06,103.53,103.99,104.44,104.88,105.32,105.75,106.17,106.59,107.00,107.41,107.81,108.21,108.61,109.00,109.39,109.78,110.16,110.55,110.93,111.31,111.69,112.07,112.45,112.82,113.20,113.58,113.96,114.33,114.71,115.09,115.48,115.86,116.24,116.63,117.02,117.41,117.81,118.21,118.61,119.01,119.42,119.84,120.26,120.68,121.11,121.55,121.99,122.44,122.90,123.37,123.85,124.34,124.83,125.34,125.87,126.41,126.96,127.53,128.12,128.73,129.37,130.03,130.72,131.45,132.21,133.02,133.89,134.81,135.81,136.91,138.11,139.47,141.03,142.88,145.17,148.25,153.19],
[0,83.530,86.902,89.090,90.760,92.134,93.314,94.358,95.299,96.161,96.958,97.703,98.405,99.070,99.703,100.31,100.89,101.45,101.99,102.52,103.03,103.52,104.01,104.48,104.94,105.40,105.84,106.28,106.71,107.14,107.56,107.97,108.38,108.78,109.19,109.58,109.98,110.37,110.76,111.15,111.53,111.91,112.30,112.68,113.06,113.44,113.82,114.20,114.57,114.95,115.33,115.71,116.10,116.48,116.87,117.25,117.64,118.03,118.43,118.82,119.22,119.63,120.03,120.45,120.86,121.28,121.71,122.14,122.58,123.03,123.48,123.94,124.41,124.89,125.38,125.88,126.39,126.92,127.46,128.01,128.59,129.18,129.79,130.43,131.10,131.79,132.52,133.29,134.10,134.97,135.90,136.90,138.00,139.21,140.57,142.14,143.99,146.29,149.38,154.34],
[0,84.377,87.768,89.966,91.645,93.026,94.212,95.261,96.207,97.073,97.874,98.623,99.328,99.996,100.63,101.24,101.82,102.39,102.93,103.46,103.97,104.47,104.95,105.43,105.90,106.35,106.80,107.24,107.67,108.10,108.52,108.94,109.35,109.76,110.16,110.56,110.95,111.35,111.74,112.13,112.51,112.90,113.28,113.67,114.05,114.43,114.81,115.19,115.57,115.95,116.33,116.72,117.10,117.49,117.87,118.26,118.65,119.04,119.44,119.84,120.24,120.64,121.05,121.47,121.89,122.31,122.74,123.17,123.61,124.06,124.51,124.98,125.45,125.93,126.42,126.92,127.44,127.97,128.51,129.07,129.64,130.24,130.85,131.49,132.16,132.86,133.59,134.36,135.18,136.05,136.98,137.99,139.09,140.31,141.68,143.25,145.11,147.41,150.52,155.50],
[0,85.225,88.633,90.843,92.530,93.918,95.111,96.165,97.115,97.985,98.790,99.543,100.25,100.92,101.56,102.17,102.76,103.32,103.87,104.40,104.92,105.42,105.90,106.38,106.85,107.31,107.76,108.20,108.63,109.06,109.49,109.90,110.32,110.73,111.13,111.53,111.93,112.33,112.72,113.11,113.50,113.88,114.27,114.65,115.04,115.42,115.80,116.19,116.57,116.95,117.33,117.72,118.10,118.49,118.88,119.27,119.66,120.06,120.45,120.85,121.26,121.66,122.07,122.49,122.91,123.33,123.76,124.20,124.64,125.09,125.55,126.01,126.49,126.97,127.46,127.97,128.48,129.01,129.56,130.12,130.70,131.29,131.91,132.56,133.23,133.93,134.66,135.44,136.26,137.13,138.07,139.08,140.18,141.40,142.78,144.35,146.22,148.54,151.65,156.65],
[0,86.074,89.500,91.721,93.417,94.811,96.010,97.069,98.024,98.898,99.707,100.46,101.17,101.85,102.49,103.10,103.69,104.26,104.81,105.34,105.86,106.36,106.85,107.33,107.80,108.26,108.72,109.16,109.60,110.03,110.45,110.87,111.29,111.70,112.10,112.51,112.91,113.30,113.70,114.09,114.48,114.87,115.26,115.64,116.03,116.41,116.80,117.18,117.56,117.95,118.33,118.72,119.11,119.50,119.89,120.28,120.67,121.07,121.47,121.87,122.27,122.68,123.09,123.51,123.93,124.36,124.79,125.23,125.67,126.12,126.58,127.05,127.52,128.01,128.50,129.01,129.53,130.06,130.61,131.17,131.75,132.35,132.97,133.62,134.29,134.99,135.73,136.51,137.33,138.21,139.15,140.17,141.27,142.50,143.88,145.46,147.33,149.66,152.79,157.80],
[0,86.924,90.367,92.599,94.303,95.705,96.909,97.973,98.932,99.811,100.62,101.38,102.10,102.78,103.42,104.04,104.63,105.20,105.75,106.29,106.81,107.31,107.80,108.29,108.76,109.22,109.67,110.12,110.56,110.99,111.42,111.84,112.26,112.67,113.08,113.48,113.88,114.28,114.68,115.07,115.46,115.85,116.24,116.63,117.02,117.40,117.79,118.18,118.56,118.95,119.33,119.72,120.11,120.50,120.89,121.28,121.68,122.08,122.48,122.88,123.29,123.70,124.11,124.53,124.96,125.38,125.82,126.26,126.70,127.16,127.62,128.08,128.56,129.05,129.55,130.05,130.58,131.11,131.66,132.22,132.81,133.41,134.03,134.68,135.36,136.06,136.80,137.58,138.41,139.29,140.23,141.25,142.37,143.60,144.98,146.57,148.45,150.78,153.92,158.95],
[0,87.774,91.235,93.478,95.190,96.599,97.808,98.878,99.842,100.72,101.54,102.30,103.02,103.70,104.35,104.97,105.57,106.14,106.69,107.23,107.75,108.26,108.75,109.24,109.71,110.18,110.63,111.08,111.52,111.96,112.38,112.81,113.23,113.64,114.05,114.46,114.86,115.26,115.66,116.05,116.45,116.84,117.23,117.62,118.01,118.40,118.78,119.17,119.56,119.95,120.33,120.72,121.11,121.50,121.90,122.29,122.69,123.09,123.49,123.90,124.31,124.72,125.13,125.55,125.98,126.41,126.84,127.28,127.73,128.19,128.65,129.12,129.60,130.09,130.59,131.10,131.62,132.16,132.71,133.28,133.86,134.47,135.09,135.74,136.42,137.13,137.87,138.66,139.49,140.37,141.32,142.34,143.46,144.69,146.08,147.67,149.56,151.90,155.05,160.10],
[0,88.624,92.103,94.357,96.078,97.493,98.708,99.783,100.75,101.64,102.46,103.23,103.95,104.63,105.28,105.90,106.50,107.08,107.63,108.17,108.70,109.21,109.70,110.19,110.67,111.13,111.59,112.04,112.48,112.92,113.35,113.78,114.20,114.61,115.02,115.43,115.84,116.24,116.64,117.04,117.43,117.83,118.22,118.61,119.00,119.39,119.78,120.17,120.55,120.94,121.33,121.72,122.12,122.51,122.90,123.30,123.70,124.10,124.50,124.91,125.32,125.74,126.15,126.57,127.00,127.43,127.87,128.31,128.76,129.22,129.68,130.16,130.64,131.13,131.63,132.14,132.67,133.20,133.76,134.33,134.91,135.52,136.15,136.80,137.48,138.20,138.94,139.73,140.56,141.45,142.40,143.43,144.55,145.79,147.18,148.78,150.67,153.02,156.18,161.25],
[0,89.476,92.971,95.237,96.966,98.388,99.609,100.69,101.66,102.55,103.38,104.15,104.87,105.56,106.21,106.84,107.44,108.02,108.58,109.12,109.64,110.16,110.65,111.14,111.62,112.09,112.55,113.00,113.45,113.88,114.32,114.74,115.17,115.58,116.00,116.41,116.81,117.22,117.62,118.02,118.42,118.81,119.20,119.60,119.99,120.38,120.77,121.16,121.55,121.94,122.33,122.73,123.12,123.51,123.91,124.31,124.71,125.11,125.52,125.93,126.34,126.75,127.17,127.60,128.02,128.46,128.90,129.34,129.79,130.25,130.72,131.19,131.67,132.17,132.67,133.18,133.71,134.25,134.81,135.38,135.97,136.58,137.21,137.86,138.55,139.26,140.01,140.80,141.64,142.53,143.48,144.51,145.64,146.88,148.28,149.88,151.78,154.14,157.31,162.40],
[0,90.328,93.840,96.117,97.854,99.283,100.51,101.59,102.57,103.47,104.29,105.07,105.80,106.49,107.14,107.77,108.37,108.96,109.52,110.06,110.59,111.10,111.61,112.10,112.58,113.05,113.51,113.96,114.41,114.85,115.28,115.71,116.14,116.56,116.97,117.38,117.79,118.20,118.60,119.00,119.40,119.80,120.19,120.59,120.98,121.37,121.76,122.16,122.55,122.94,123.33,123.73,124.12,124.52,124.92,125.32,125.72,126.12,126.53,126.94,127.35,127.77,128.19,128.62,129.05,129.48,129.92,130.37,130.82,131.28,131.75,132.23,132.71,133.21,133.71,134.23,134.76,135.30,135.86,136.43,137.02,137.63,138.27,138.93,139.61,140.33,141.08,141.87,142.71,143.60,144.56,145.60,146.73,147.98,149.38,150.99,152.90,155.26,158.44,163.55],
[0,91.180,94.710,96.998,98.743,100.18,101.41,102.50,103.48,104.38,105.21,105.99,106.72,107.41,108.07,108.71,109.31,109.89,110.46,111.01,111.54,112.05,112.56,113.05,113.53,114.00,114.47,114.92,115.37,115.81,116.25,116.68,117.11,117.53,117.95,118.36,118.77,119.18,119.58,119.98,120.38,120.78,121.18,121.57,121.97,122.36,122.76,123.15,123.55,123.94,124.33,124.73,125.13,125.52,125.92,126.33,126.73,127.13,127.54,127.96,128.37,128.79,129.21,129.64,130.07,130.51,130.95,131.40,131.85,132.31,132.78,133.26,133.75,134.25,134.75,135.27,135.80,136.35,136.91,137.48,138.08,138.69,139.33,139.99,140.67,141.39,142.15,142.94,143.79,144.68,145.64,146.68,147.82,149.07,150.48,152.09,154.01,156.38,159.58,164.69],
[0,92.033,95.580,97.879,99.632,101.07,102.31,103.41,104.39,105.30,106.13,106.91,107.65,108.34,109.01,109.64,110.25,110.83,111.40,111.95,112.48,113.00,113.51,114.00,114.49,114.96,115.43,115.88,116.34,116.78,117.22,117.65,118.08,118.50,118.92,119.33,119.75,120.16,120.56,120.97,121.37,121.77,122.17,122.56,122.96,123.36,123.75,124.15,124.54,124.94,125.33,125.73,126.13,126.53,126.93,127.33,127.74,128.15,128.56,128.97,129.39,129.81,130.23,130.66,131.09,131.53,131.98,132.43,132.88,133.35,133.82,134.30,134.79,135.28,135.79,136.31,136.85,137.39,137.95,138.53,139.13,139.75,140.38,141.05,141.74,142.46,143.22,144.01,144.86,145.76,146.72,147.77,148.90,150.16,151.58,153.20,155.12,157.50,160.70,165.84],
[0,92.887,96.451,98.760,100.52,101.97,103.21,104.31,105.31,106.21,107.05,107.84,108.57,109.27,109.94,110.57,111.19,111.77,112.34,112.89,113.43,113.95,114.46,114.96,115.44,115.92,116.39,116.85,117.30,117.74,118.18,118.62,119.05,119.47,119.89,120.31,120.72,121.13,121.54,121.95,122.35,122.75,123.15,123.55,123.95,124.35,124.74,125.14,125.54,125.94,126.33,126.73,127.13,127.53,127.94,128.34,128.75,129.16,129.57,129.98,130.40,130.82,131.25,131.68,132.12,132.56,133.00,133.45,133.91,134.38,134.85,135.33,135.82,136.32,136.83,137.36,137.89,138.44,139.00,139.58,140.18,140.80,141.44,142.11,142.80,143.52,144.29,145.09,145.93,146.84,147.80,148.85,149.99,151.26,152.67,154.30,156.23,158.62,161.83,166.99],
[0,93.741,97.322,99.642,101.41,102.87,104.12,105.22,106.22,107.13,107.97,108.76,109.50,110.20,110.87,111.51,112.12,112.71,113.29,113.84,114.38,114.90,115.41,115.91,116.40,116.88,117.35,117.81,118.26,118.71,119.15,119.59,120.02,120.45,120.87,121.29,121.70,122.11,122.52,122.93,123.34,123.74,124.14,124.54,124.94,125.34,125.74,126.14,126.54,126.93,127.33,127.73,128.14,128.54,128.94,129.35,129.76,130.17,130.58,131.00,131.42,131.84,132.27,132.70,133.14,133.58,134.03,134.48,134.94,135.41,135.88,136.37,136.86,137.36,137.87,138.40,138.94,139.49,140.05,140.63,141.24,141.86,142.50,143.17,143.86,144.59,145.35,146.16,147.01,147.91,148.89,149.94,151.08,152.35,153.77,155.40,157.34,159.74,162.96,168.13],
[0,94.596,98.194,100.52,102.30,103.76,105.02,106.13,107.13,108.04,108.89,109.68,110.43,111.13,111.80,112.44,113.06,113.65,114.23,114.78,115.32,115.85,116.36,116.86,117.35,117.83,118.31,118.77,119.23,119.67,120.12,120.56,120.99,121.42,121.84,122.26,122.68,123.09,123.50,123.91,124.32,124.72,125.13,125.53,125.93,126.33,126.73,127.13,127.53,127.93,128.33,128.74,129.14,129.54,129.95,130.36,130.77,131.18,131.59,132.01,132.43,132.86,133.29,133.72,134.16,134.60,135.05,135.51,135.97,136.44,136.92,137.40,137.90,138.40,138.91,139.44,139.98,140.53,141.10,141.68,142.29,142.91,143.56,144.23,144.92,145.65,146.42,147.23,148.08,148.99,149.97,151.02,152.17,153.44,154.87,156.51,158.45,160.85,164.09,169.28],
[0,95.451,99.066,101.41,103.19,104.66,105.92,107.04,108.04,108.96,109.81,110.61,111.35,112.06,112.74,113.38,114.00,114.60,115.17,115.73,116.27,116.80,117.31,117.82,118.31,118.79,119.27,119.73,120.19,120.64,121.09,121.53,121.96,122.39,122.82,123.24,123.66,124.07,124.48,124.90,125.30,125.71,126.12,126.52,126.92,127.32,127.73,128.13,128.53,128.93,129.33,129.74,130.14,130.55,130.96,131.36,131.78,132.19,132.61,133.03,133.45,133.88,134.31,134.74,135.18,135.63,136.08,136.54,137.00,137.47,137.95,138.44,138.93,139.44,139.95,140.48,141.02,141.58,142.15,142.74,143.34,143.97,144.61,145.29,145.99,146.72,147.49,148.30,149.15,150.07,151.05,152.10,153.26,154.53,155.97,157.61,159.56,161.97,165.22,170.42],
[0,96.307,99.939,102.29,104.09,105.56,106.83,107.95,108.95,109.88,110.73,111.53,112.28,112.99,113.67,114.32,114.94,115.54,116.11,116.68,117.22,117.75,118.27,118.77,119.27,119.75,120.23,120.69,121.15,121.61,122.05,122.49,122.93,123.36,123.79,124.21,124.63,125.05,125.47,125.88,126.29,126.70,127.10,127.51,127.91,128.32,128.72,129.12,129.53,129.93,130.33,130.74,131.15,131.55,131.96,132.37,132.79,133.20,133.62,134.04,134.47,134.89,135.33,135.76,136.20,136.65,137.10,137.56,138.03,138.50,138.98,139.47,139.97,140.48,140.99,141.52,142.07,142.62,143.20,143.79,144.39,145.02,145.67,146.35,147.05,147.78,148.55,149.37,150.23,151.14,152.12,153.19,154.34,155.62,157.06,158.71,160.67,163.09,166.35,171.57],
[0,97.164,100.81,103.18,104.98,106.46,107.73,108.85,109.87,110.79,111.65,112.45,113.21,113.92,114.60,115.25,115.88,116.48,117.06,117.62,118.17,118.70,119.22,119.73,120.22,120.71,121.19,121.65,122.12,122.57,123.02,123.46,123.90,124.34,124.76,125.19,125.61,126.03,126.45,126.86,127.27,127.68,128.09,128.50,128.90,129.31,129.71,130.12,130.52,130.93,131.33,131.74,132.15,132.56,132.97,133.38,133.79,134.21,134.63,135.05,135.48,135.91,136.35,136.78,137.23,137.68,138.13,138.59,139.06,139.53,140.01,140.50,141.00,141.51,142.03,142.57,143.11,143.67,144.24,144.84,145.44,146.07,146.73,147.40,148.11,148.85,149.62,150.44,151.30,152.22,153.20,154.27,155.43,156.71,158.16,159.81,161.77,164.20,167.47,172.71],
[0,98.021,101.69,104.06,105.87,107.36,108.64,109.76,110.78,111.71,112.57,113.38,114.14,114.85,115.53,116.19,116.81,117.42,118.00,118.57,119.12,119.65,120.17,120.68,121.18,121.67,122.15,122.62,123.08,123.54,123.99,124.43,124.87,125.31,125.74,126.17,126.59,127.01,127.43,127.84,128.26,128.67,129.08,129.49,129.89,130.30,130.71,131.11,131.52,131.93,132.33,132.74,133.15,133.56,133.97,134.39,134.80,135.22,135.64,136.07,136.50,136.93,137.36,137.80,138.25,138.70,139.16,139.62,140.09,140.56,141.05,141.54,142.04,142.55,143.07,143.61,144.15,144.72,145.29,145.88,146.50,147.13,147.78,148.46,149.17,149.91,150.69,151.51,152.37,153.29,154.28,155.35,156.52,157.81,159.25,160.91,162.88,165.32,168.60,173.85],
[0,98.878,102.56,104.94,106.76,108.26,109.54,110.67,111.70,112.63,113.49,114.30,115.06,115.78,116.47,117.12,117.75,118.36,118.95,119.51,120.06,120.60,121.12,121.63,122.13,122.63,123.11,123.58,124.05,124.50,124.96,125.40,125.84,126.28,126.71,127.14,127.57,127.99,128.41,128.83,129.24,129.65,130.07,130.48,130.88,131.29,131.70,132.11,132.52,132.93,133.33,133.74,134.15,134.57,134.98,135.40,135.81,136.23,136.66,137.08,137.51,137.95,138.38,138.82,139.27,139.72,140.18,140.64,141.11,141.59,142.08,142.57,143.08,143.59,144.11,144.65,145.20,145.76,146.34,146.93,147.55,148.18,148.84,149.52,150.23,150.98,151.75,152.58,153.44,154.37,155.36,156.43,157.60,158.90,160.35,162.02,163.99,166.44,169.73,175.00],
[0,99.736,103.43,105.83,107.66,109.16,110.44,111.58,112.61,113.55,114.42,115.23,115.99,116.71,117.40,118.06,118.69,119.30,119.89,120.46,121.01,121.55,122.08,122.59,123.09,123.58,124.07,124.54,125.01,125.47,125.92,126.37,126.82,127.25,127.69,128.12,128.55,128.97,129.39,129.81,130.23,130.64,131.05,131.46,131.88,132.29,132.70,133.10,133.51,133.92,134.33,134.75,135.16,135.57,135.99,136.40,136.82,137.24,137.67,138.10,138.53,138.96,139.40,139.84,140.29,140.75,141.21,141.67,142.14,142.62,143.11,143.61,144.11,144.63,145.15,145.69,146.24,146.81,147.39,147.98,148.60,149.24,149.90,150.58,151.29,152.04,152.82,153.64,154.52,155.44,156.44,157.52,158.69,159.99,161.44,163.12,165.10,167.55,170.85,176.14],
[0,100.60,104.31,106.71,108.55,110.06,111.35,112.49,113.52,114.47,115.34,116.15,116.92,117.65,118.34,119.00,119.63,120.24,120.83,121.41,121.96,122.50,123.03,123.54,124.05,124.54,125.03,125.50,125.97,126.44,126.89,127.34,127.79,128.23,128.66,129.10,129.52,129.95,130.37,130.79,131.21,131.63,132.04,132.45,132.87,133.28,133.69,134.10,134.51,134.92,135.33,135.75,136.16,136.58,136.99,137.41,137.83,138.26,138.68,139.11,139.54,139.98,140.42,140.86,141.31,141.77,142.23,142.70,143.17,143.65,144.14,144.64,145.15,145.66,146.19,146.73,147.28,147.85,148.43,149.03,149.65,150.29,150.95,151.64,152.35,153.10,153.89,154.71,155.59,156.52,157.52,158.60,159.77,161.08,162.54,164.22,166.20,168.66,171.98,177.28],
[0,101.45,105.19,107.60,109.44,110.96,112.26,113.40,114.44,115.38,116.26,117.08,117.85,118.58,119.27,119.93,120.57,121.19,121.78,122.35,122.91,123.45,123.98,124.50,125.01,125.50,125.99,126.47,126.94,127.40,127.86,128.31,128.76,129.20,129.64,130.07,130.50,130.93,131.35,131.78,132.19,132.61,133.03,133.44,133.86,134.27,134.68,135.10,135.51,135.92,136.33,136.75,137.16,137.58,138.00,138.42,138.84,139.27,139.69,140.12,140.56,141.00,141.44,141.89,142.34,142.79,143.26,143.72,144.20,144.68,145.17,145.67,146.18,146.70,147.23,147.77,148.33,148.90,149.48,150.08,150.70,151.34,152.01,152.70,153.41,154.16,154.95,155.78,156.66,157.59,158.60,159.68,160.86,162.17,163.63,165.32,167.31,169.78,173.10,178.42],
[0,102.31,106.06,108.49,110.34,111.86,113.16,114.31,115.35,116.30,117.18,118.00,118.78,119.51,120.21,120.87,121.51,122.13,122.72,123.30,123.86,124.40,124.94,125.45,125.96,126.46,126.95,127.43,127.90,128.37,128.83,129.28,129.73,130.17,130.61,131.05,131.48,131.91,132.34,132.76,133.18,133.60,134.02,134.43,134.85,135.26,135.68,136.09,136.50,136.92,137.33,137.75,138.17,138.58,139.00,139.43,139.85,140.28,140.71,141.14,141.57,142.01,142.46,142.91,143.36,143.82,144.28,144.75,145.23,145.71,146.21,146.71,147.22,147.74,148.27,148.81,149.37,149.94,150.53,151.13,151.75,152.40,153.06,153.75,154.47,155.23,156.02,156.85,157.73,158.67,159.67,160.76,161.94,163.25,164.73,166.42,168.41,170.89,174.22,179.56],
[0,103.17,106.94,109.37,111.23,112.76,114.07,115.23,116.27,117.22,118.11,118.93,119.71,120.44,121.14,121.81,122.45,123.07,123.67,124.25,124.81,125.36,125.89,126.41,126.92,127.42,127.91,128.39,128.87,129.34,129.80,130.25,130.70,131.15,131.59,132.03,132.46,132.89,133.32,133.74,134.16,134.59,135.00,135.42,135.84,136.26,136.67,137.09,137.50,137.92,138.33,138.75,139.17,139.59,140.01,140.43,140.86,141.29,141.72,142.15,142.59,143.03,143.48,143.93,144.38,144.84,145.31,145.78,146.26,146.74,147.24,147.74,148.25,148.77,149.31,149.85,150.41,150.98,151.57,152.18,152.80,153.45,154.12,154.81,155.53,156.29,157.08,157.92,158.80,159.74,160.75,161.84,163.03,164.34,165.82,167.51,169.52,172.01,175.35,180.70],
[0,104.03,107.82,110.26,112.13,113.66,114.98,116.14,117.18,118.14,119.03,119.86,120.64,121.37,122.08,122.75,123.39,124.01,124.61,125.19,125.76,126.31,126.84,127.37,127.88,128.38,128.87,129.36,129.83,130.30,130.77,131.22,131.67,132.12,132.56,133.00,133.44,133.87,134.30,134.72,135.15,135.57,135.99,136.41,136.83,137.25,137.66,138.08,138.50,138.92,139.33,139.75,140.17,140.59,141.02,141.44,141.87,142.30,142.73,143.17,143.60,144.05,144.49,144.95,145.40,145.86,146.33,146.80,147.28,147.77,148.27,148.77,149.29,149.81,150.35,150.89,151.45,152.03,152.62,153.23,153.85,154.50,155.17,155.87,156.59,157.35,158.15,158.98,159.87,160.82,161.83,162.92,164.11,165.43,166.91,168.61,170.62,173.12,176.47,181.84],
[0,104.90,108.69,111.15,113.02,114.56,115.88,117.05,118.10,119.06,119.95,120.78,121.57,122.31,123.01,123.69,124.33,124.96,125.56,126.14,126.71,127.26,127.80,128.32,128.84,129.34,129.83,130.32,130.80,131.27,131.73,132.19,132.65,133.10,133.54,133.98,134.42,134.85,135.28,135.71,136.13,136.56,136.98,137.40,137.82,138.24,138.66,139.08,139.50,139.91,140.33,140.75,141.18,141.60,142.02,142.45,142.88,143.31,143.74,144.18,144.62,145.06,145.51,145.96,146.42,146.89,147.36,147.83,148.31,148.80,149.30,149.81,150.32,150.85,151.39,151.93,152.50,153.07,153.67,154.28,154.90,155.55,156.23,156.93,157.65,158.41,159.21,160.05,160.94,161.89,162.90,164.00,165.20,166.52,168.01,169.71,171.73,174.23,177.59,182.98],
[0,105.76,109.57,112.04,113.92,115.46,116.79,117.96,119.02,119.98,120.88,121.71,122.50,123.24,123.95,124.62,125.27,125.90,126.50,127.09,127.66,128.21,128.75,129.28,129.79,130.30,130.80,131.28,131.76,132.24,132.70,133.16,133.62,134.07,134.51,134.96,135.39,135.83,136.26,136.69,137.12,137.54,137.97,138.39,138.81,139.23,139.65,140.07,140.49,140.91,141.33,141.76,142.18,142.60,143.03,143.46,143.89,144.32,144.75,145.19,145.63,146.08,146.53,146.98,147.44,147.91,148.38,148.86,149.34,149.83,150.33,150.84,151.36,151.88,152.42,152.97,153.54,154.12,154.71,155.32,155.95,156.61,157.28,157.98,158.71,159.48,160.28,161.12,162.01,162.96,163.98,165.08,166.28,167.61,169.10,170.81,172.83,175.34,178.72,184.12],
[0,106.62,110.45,112.93,114.81,116.37,117.70,118.87,119.93,120.90,121.80,122.64,123.43,124.17,124.88,125.56,126.21,126.84,127.45,128.04,128.61,129.16,129.70,130.23,130.75,131.26,131.76,132.25,132.73,133.20,133.67,134.13,134.59,135.04,135.49,135.93,136.37,136.81,137.24,137.67,138.10,138.53,138.96,139.38,139.80,140.23,140.65,141.07,141.49,141.91,142.33,142.76,143.18,143.61,144.03,144.46,144.90,145.33,145.77,146.21,146.65,147.10,147.55,148.00,148.47,148.93,149.40,149.88,150.37,150.86,151.36,151.87,152.39,152.92,153.46,154.01,154.58,155.16,155.76,156.37,157.00,157.66,158.34,159.04,159.77,160.54,161.34,162.19,163.08,164.03,165.06,166.16,167.36,168.70,170.19,171.91,173.94,176.45,179.84,185.26],
[0,107.48,111.33,113.81,115.71,117.27,118.61,119.79,120.85,121.82,122.72,123.57,124.36,125.11,125.82,126.50,127.16,127.79,128.39,128.98,129.56,130.12,130.66,131.19,131.71,132.22,132.72,133.21,133.69,134.17,134.64,135.10,135.56,136.02,136.47,136.91,137.35,137.79,138.23,138.66,139.09,139.52,139.94,140.37,140.79,141.22,141.64,142.06,142.49,142.91,143.33,143.76,144.18,144.61,145.04,145.47,145.90,146.34,146.78,147.22,147.66,148.11,148.57,149.02,149.49,149.95,150.43,150.91,151.40,151.89,152.39,152.90,153.43,153.96,154.50,155.05,155.62,156.21,156.80,157.42,158.05,158.71,159.39,160.10,160.83,161.60,162.40,163.25,164.15,165.11,166.13,167.24,168.45,169.78,171.28,173.00,175.04,177.57,180.96,186.39],
[0,108.35,112.21,114.70,116.61,118.17,119.51,120.70,121.77,122.74,123.65,124.49,125.29,126.04,126.76,127.44,128.10,128.73,129.34,129.93,130.51,131.07,131.61,132.15,132.67,133.18,133.68,134.17,134.66,135.14,135.61,136.08,136.54,136.99,137.44,137.89,138.33,138.77,139.21,139.64,140.07,140.50,140.93,141.36,141.79,142.21,142.63,143.06,143.48,143.91,144.33,144.76,145.19,145.62,146.05,146.48,146.91,147.35,147.79,148.23,148.68,149.13,149.58,150.04,150.51,150.98,151.45,151.93,152.42,152.92,153.42,153.94,154.46,154.99,155.54,156.09,156.66,157.25,157.85,158.47,159.10,159.76,160.44,161.15,161.89,162.66,163.47,164.32,165.22,166.18,167.21,168.32,169.53,170.87,172.37,174.10,176.14,178.68,182.08,187.53],
[0,109.21,113.09,115.59,117.50,119.07,120.42,121.61,122.69,123.67,124.57,125.42,126.22,126.97,127.69,128.38,129.04,129.67,130.29,130.88,131.46,132.02,132.57,133.10,133.63,134.14,134.64,135.14,135.63,136.11,136.58,137.05,137.51,137.97,138.42,138.87,139.31,139.75,140.19,140.63,141.06,141.49,141.92,142.35,142.78,143.20,143.63,144.05,144.48,144.91,145.33,145.76,146.19,146.62,147.05,147.49,147.92,148.36,148.80,149.25,149.69,150.15,150.60,151.06,151.53,152.00,152.48,152.96,153.45,153.95,154.46,154.97,155.49,156.03,156.58,157.13,157.71,158.29,158.89,159.51,160.15,160.81,161.50,162.21,162.95,163.72,164.53,165.39,166.29,167.25,168.28,169.40,170.61,171.96,173.47,175.20,177.25,179.79,183.20,188.67],
[0,110.07,113.97,116.48,118.40,119.98,121.33,122.53,123.60,124.59,125.50,126.35,127.15,127.91,128.63,129.32,129.98,130.62,131.23,131.83,132.41,132.97,133.52,134.06,134.59,135.10,135.61,136.10,136.59,137.07,137.55,138.02,138.48,138.94,139.39,139.84,140.29,140.73,141.17,141.61,142.04,142.48,142.91,143.34,143.77,144.20,144.62,145.05,145.48,145.91,146.33,146.76,147.19,147.62,148.06,148.49,148.93,149.37,149.81,150.26,150.71,151.16,151.62,152.08,152.55,153.02,153.50,153.99,154.48,154.98,155.49,156.00,156.53,157.07,157.61,158.17,158.75,159.34,159.94,160.56,161.20,161.86,162.55,163.26,164.01,164.78,165.59,166.45,167.36,168.32,169.36,170.48,171.70,173.04,174.56,176.29,178.35,180.90,184.32,189.80],
[0,110.94,114.85,117.37,119.30,120.88,122.24,123.44,124.52,125.51,126.42,127.28,128.08,128.84,129.57,130.26,130.92,131.56,132.18,132.78,133.36,133.93,134.48,135.02,135.54,136.06,136.57,137.07,137.56,138.04,138.52,138.99,139.45,139.91,140.37,140.82,141.27,141.71,142.15,142.59,143.03,143.46,143.90,144.33,144.76,145.19,145.62,146.05,146.47,146.90,147.33,147.76,148.20,148.63,149.06,149.50,149.94,150.38,150.83,151.27,151.72,152.18,152.64,153.10,153.57,154.05,154.53,155.01,155.51,156.01,156.52,157.03,157.56,158.10,158.65,159.21,159.79,160.38,160.98,161.61,162.25,162.92,163.60,164.32,165.06,165.84,166.66,167.52,168.43,169.39,170.43,171.55,172.78,174.13,175.65,177.39,179.45,182.01,185.44,190.94],
[0,111.80,115.73,118.26,120.20,121.79,123.15,124.35,125.44,126.43,127.35,128.21,129.01,129.78,130.50,131.20,131.86,132.51,133.13,133.73,134.31,134.88,135.43,135.97,136.50,137.02,137.53,138.03,138.52,139.01,139.49,139.96,140.43,140.89,141.35,141.80,142.25,142.69,143.14,143.58,144.01,144.45,144.88,145.32,145.75,146.18,146.61,147.04,147.47,147.90,148.33,148.77,149.20,149.63,150.07,150.51,150.95,151.39,151.84,152.29,152.74,153.20,153.66,154.12,154.59,155.07,155.55,156.04,156.53,157.04,157.55,158.07,158.60,159.14,159.69,160.25,160.83,161.42,162.03,162.66,163.30,163.97,164.66,165.37,166.12,166.90,167.72,168.58,169.49,170.47,171.51,172.63,173.86,175.22,176.74,178.49,180.55,183.12,186.56,192.07],
[0,112.67,116.61,119.16,121.10,122.69,124.06,125.27,126.36,127.35,128.28,129.14,129.94,130.71,131.44,132.14,132.81,133.45,134.07,134.68,135.26,135.83,136.39,136.93,137.46,137.98,138.49,139.00,139.49,139.98,140.46,140.93,141.40,141.86,142.32,142.78,143.23,143.67,144.12,144.56,145.00,145.44,145.87,146.31,146.74,147.17,147.61,148.04,148.47,148.90,149.33,149.77,150.20,150.64,151.08,151.52,151.96,152.40,152.85,153.30,153.75,154.21,154.67,155.14,155.61,156.09,156.57,157.06,157.56,158.06,158.58,159.10,159.63,160.17,160.73,161.29,161.87,162.46,163.07,163.70,164.35,165.02,165.71,166.43,167.18,167.96,168.78,169.65,170.56,171.54,172.58,173.71,174.94,176.30,177.83,179.58,181.65,184.22,187.68,193.21],
[0,113.53,117.49,120.05,122.00,123.60,124.97,126.18,127.28,128.28,129.20,130.06,130.88,131.65,132.38,133.08,133.75,134.40,135.02,135.63,136.21,136.79,137.34,137.89,138.42,138.94,139.46,139.96,140.46,140.94,141.43,141.90,142.37,142.84,143.30,143.75,144.21,144.65,145.10,145.54,145.99,146.42,146.86,147.30,147.73,148.17,148.60,149.03,149.47,149.90,150.33,150.77,151.20,151.64,152.08,152.52,152.97,153.41,153.86,154.31,154.77,155.23,155.69,156.16,156.63,157.11,157.60,158.09,158.59,159.09,159.61,160.13,160.66,161.21,161.76,162.33,162.91,163.51,164.12,164.75,165.40,166.07,166.76,167.48,168.24,169.02,169.85,170.71,171.63,172.61,173.66,174.79,176.02,177.39,178.92,180.68,182.76,185.33,188.80,194.34],
[0,114.40,118.37,120.94,122.90,124.50,125.88,127.10,128.20,129.20,130.13,130.99,131.81,132.58,133.32,134.02,134.69,135.34,135.97,136.58,137.17,137.74,138.30,138.85,139.38,139.91,140.42,140.93,141.42,141.91,142.40,142.87,143.35,143.81,144.27,144.73,145.19,145.64,146.08,146.53,146.97,147.41,147.85,148.29,148.72,149.16,149.59,150.03,150.46,150.90,151.33,151.77,152.21,152.65,153.09,153.53,153.97,154.42,154.87,155.33,155.78,156.24,156.71,157.18,157.65,158.13,158.62,159.11,159.61,160.12,160.64,161.16,161.70,162.24,162.80,163.37,163.95,164.55,165.16,165.80,166.45,167.12,167.82,168.54,169.29,170.08,170.91,171.78,172.70,173.68,174.73,175.86,177.10,178.47,180.01,181.77,183.86,186.44,189.92,195.48],
[0,115.27,119.25,121.83,123.79,125.41,126.79,128.01,129.12,130.12,131.05,131.92,132.74,133.52,134.25,134.96,135.63,136.29,136.92,137.53,138.12,138.69,139.25,139.80,140.34,140.87,141.38,141.89,142.39,142.88,143.37,143.85,144.32,144.79,145.25,145.71,146.16,146.62,147.07,147.51,147.96,148.40,148.84,149.28,149.71,150.15,150.59,151.02,151.46,151.90,152.33,152.77,153.21,153.65,154.09,154.54,154.98,155.43,155.88,156.34,156.80,157.26,157.73,158.20,158.67,159.16,159.64,160.14,160.64,161.15,161.67,162.19,162.73,163.28,163.84,164.41,164.99,165.59,166.21,166.84,167.49,168.17,168.87,169.59,170.35,171.14,171.97,172.84,173.77,174.75,175.80,176.94,178.18,179.56,181.10,182.86,184.96,187.55,191.03,196.61],
[0,116.13,120.14,122.72,124.69,126.31,127.70,128.93,130.03,131.05,131.98,132.85,133.67,134.45,135.19,135.90,136.58,137.23,137.86,138.48,139.07,139.65,140.21,140.76,141.30,141.83,142.35,142.85,143.36,143.85,144.34,144.82,145.29,145.76,146.23,146.69,147.14,147.60,148.05,148.50,148.94,149.38,149.83,150.27,150.71,151.14,151.58,152.02,152.46,152.90,153.33,153.77,154.21,154.66,155.10,155.54,155.99,156.44,156.90,157.35,157.81,158.28,158.74,159.22,159.69,160.18,160.67,161.16,161.67,162.18,162.70,163.23,163.76,164.31,164.87,165.45,166.03,166.63,167.25,167.89,168.54,169.22,169.92,170.65,171.41,172.20,173.03,173.91,174.83,175.82,176.88,178.02,179.26,180.64,182.19,183.96,186.06,188.66,192.15,197.74],
[0,117.00,121.02,123.62,125.59,127.22,128.61,129.85,130.95,131.97,132.91,133.78,134.61,135.39,136.13,136.84,137.52,138.18,138.81,139.42,140.02,140.60,141.17,141.72,142.26,142.79,143.31,143.82,144.32,144.82,145.31,145.79,146.26,146.74,147.20,147.67,148.12,148.58,149.03,149.48,149.93,150.37,150.82,151.26,151.70,152.14,152.58,153.02,153.45,153.89,154.33,154.77,155.22,155.66,156.10,156.55,157.00,157.45,157.91,158.36,158.83,159.29,159.76,160.24,160.72,161.20,161.69,162.19,162.69,163.21,163.73,164.26,164.80,165.35,165.91,166.48,167.07,167.68,168.30,168.93,169.59,170.27,170.97,171.70,172.46,173.26,174.09,174.97,175.90,176.89,177.95,179.09,180.34,181.72,183.27,185.05,187.16,189.76,193.27,198.87],
[0,117.87,121.90,124.51,126.50,128.13,129.53,130.76,131.88,132.89,133.83,134.71,135.54,136.32,137.07,137.78,138.46,139.12,139.76,140.38,140.97,141.56,142.12,142.68,143.22,143.75,144.27,144.79,145.29,145.79,146.28,146.76,147.24,147.71,148.18,148.64,149.10,149.56,150.01,150.46,150.91,151.36,151.80,152.25,152.69,153.13,153.57,154.01,154.45,154.89,155.33,155.78,156.22,156.66,157.11,157.56,158.01,158.46,158.92,159.38,159.84,160.31,160.78,161.25,161.74,162.22,162.72,163.21,163.72,164.24,164.76,165.29,165.83,166.38,166.95,167.52,168.11,168.72,169.34,169.98,170.64,171.32,172.03,172.76,173.52,174.32,175.15,176.03,176.97,177.96,179.02,180.17,181.42,182.81,184.36,186.15,188.26,190.87,194.38,200.01],
[0,118.74,122.79,125.40,127.40,129.03,130.44,131.68,132.80,133.82,134.76,135.64,136.47,137.26,138.01,138.72,139.41,140.07,140.71,141.33,141.93,142.51,143.08,143.64,144.18,144.71,145.24,145.75,146.26,146.76,147.25,147.73,148.21,148.69,149.16,149.62,150.08,150.54,151.00,151.45,151.90,152.35,152.79,153.24,153.68,154.12,154.57,155.01,155.45,155.89,156.33,156.78,157.22,157.67,158.12,158.57,159.02,159.47,159.93,160.39,160.85,161.32,161.80,162.27,162.76,163.24,163.74,164.24,164.75,165.26,165.79,166.32,166.86,167.42,167.98,168.56,169.15,169.76,170.38,171.02,171.69,172.37,173.08,173.81,174.58,175.38,176.22,177.10,178.03,179.03,180.09,181.25,182.50,183.89,185.45,187.24,189.35,191.98,195.50,201.14],
[0,119.61,123.67,126.30,128.30,129.94,131.35,132.60,133.72,134.74,135.69,136.58,137.41,138.20,138.95,139.66,140.35,141.02,141.66,142.28,142.88,143.46,144.04,144.59,145.14,145.67,146.20,146.72,147.22,147.72,148.22,148.70,149.19,149.66,150.13,150.60,151.06,151.52,151.98,152.43,152.88,153.33,153.78,154.23,154.67,155.12,155.56,156.00,156.45,156.89,157.33,157.78,158.22,158.67,159.12,159.57,160.03,160.48,160.94,161.40,161.87,162.34,162.81,163.29,163.78,164.27,164.76,165.26,165.77,166.29,166.82,167.35,167.90,168.45,169.02,169.60,170.19,170.80,171.43,172.07,172.73,173.42,174.13,174.87,175.63,176.44,177.28,178.16,179.10,180.10,181.17,182.32,183.58,184.97,186.54,188.33,190.45,193.08,196.62,202.27],
[0,120.48,124.56,127.19,129.20,130.85,132.26,133.51,134.64,135.67,136.62,137.51,138.34,139.13,139.89,140.61,141.30,141.96,142.60,143.23,143.83,144.42,144.99,145.55,146.10,146.64,147.16,147.68,148.19,148.69,149.19,149.68,150.16,150.64,151.11,151.58,152.04,152.50,152.96,153.42,153.87,154.32,154.77,155.22,155.66,156.11,156.55,157.00,157.44,157.89,158.33,158.78,159.23,159.68,160.13,160.58,161.03,161.49,161.95,162.42,162.88,163.35,163.83,164.31,164.80,165.29,165.78,166.29,166.80,167.32,167.85,168.38,168.93,169.49,170.06,170.64,171.23,171.84,172.47,173.12,173.78,174.47,175.18,175.92,176.69,177.49,178.34,179.23,180.17,181.17,182.24,183.40,184.66,186.06,187.63,189.42,191.55,194.19,197.73,203.40],
[0,121.35,125.44,128.09,130.10,131.76,133.18,134.43,135.56,136.59,137.55,138.44,139.28,140.07,140.83,141.55,142.24,142.91,143.55,144.18,144.78,145.37,145.95,146.51,147.06,147.60,148.13,148.65,149.16,149.66,150.16,150.65,151.13,151.61,152.09,152.56,153.02,153.49,153.94,154.40,154.86,155.31,155.76,156.21,156.65,157.10,157.55,157.99,158.44,158.89,159.33,159.78,160.23,160.68,161.13,161.59,162.04,162.50,162.96,163.43,163.90,164.37,164.85,165.33,165.82,166.31,166.81,167.31,167.83,168.35,168.88,169.41,169.96,170.52,171.09,171.68,172.27,172.88,173.51,174.16,174.83,175.52,176.23,176.97,177.75,178.55,179.40,180.29,181.23,182.24,183.31,184.47,185.74,187.14,188.71,190.52,192.65,195.29,198.85,204.53],
[0,122.22,126.33,128.98,131.00,132.66,134.09,135.35,136.48,137.52,138.47,139.37,140.21,141.01,141.76,142.49,143.18,143.85,144.50,145.13,145.74,146.33,146.91,147.47,148.02,148.56,149.09,149.61,150.13,150.63,151.13,151.62,152.11,152.59,153.06,153.53,154.00,154.47,154.93,155.39,155.84,156.29,156.75,157.20,157.65,158.09,158.54,158.99,159.44,159.89,160.33,160.78,161.23,161.69,162.14,162.59,163.05,163.51,163.98,164.44,164.91,165.39,165.86,166.35,166.84,167.33,167.83,168.34,168.85,169.37,169.91,170.45,170.99,171.56,172.13,172.71,173.31,173.93,174.56,175.21,175.88,176.57,177.28,178.03,178.80,179.61,180.46,181.35,182.30,183.30,184.38,185.55,186.82,188.22,189.80,191.61,193.75,196.40,199.96,205.66],
[0,123.09,127.21,129.88,131.91,133.57,135.00,136.26,137.40,138.44,139.40,140.30,141.14,141.94,142.70,143.43,144.13,144.80,145.45,146.08,146.69,147.28,147.86,148.43,148.98,149.52,150.06,150.58,151.09,151.60,152.10,152.59,153.08,153.56,154.04,154.51,154.98,155.45,155.91,156.37,156.83,157.28,157.74,158.19,158.64,159.09,159.54,159.99,160.43,160.88,161.33,161.78,162.24,162.69,163.14,163.60,164.06,164.52,164.99,165.45,165.93,166.40,166.88,167.37,167.86,168.35,168.85,169.36,169.88,170.40,170.93,171.48,172.03,172.59,173.16,173.75,174.35,174.97,175.60,176.25,176.92,177.62,178.33,179.08,179.86,180.67,181.52,182.41,183.36,184.37,185.45,186.62,187.90,189.31,190.89,192.70,194.85,197.50,201.08,206.79],
[0,123.96,128.10,130.77,132.81,134.48,135.92,137.18,138.32,139.37,140.33,141.23,142.08,142.88,143.64,144.37,145.07,145.75,146.40,147.03,147.64,148.24,148.82,149.39,149.94,150.49,151.02,151.54,152.06,152.57,153.07,153.57,154.05,154.54,155.02,155.49,155.96,156.43,156.89,157.35,157.81,158.27,158.72,159.18,159.63,160.08,160.53,160.98,161.43,161.88,162.33,162.79,163.24,163.69,164.15,164.61,165.07,165.53,166.00,166.47,166.94,167.42,167.90,168.38,168.88,169.37,169.88,170.39,170.90,171.43,171.96,172.51,173.06,173.62,174.20,174.79,175.39,176.01,176.64,177.30,177.97,178.66,179.38,180.13,180.91,181.73,182.58,183.48,184.43,185.44,186.52,187.70,188.97,190.39,191.97,193.79,195.94,198.61,202.19,207.92],
[0,124.83,128.98,131.67,133.71,135.39,136.83,138.10,139.25,140.29,141.26,142.16,143.01,143.82,144.58,145.32,146.02,146.70,147.35,147.98,148.60,149.19,149.78,150.35,150.90,151.45,151.98,152.51,153.03,153.54,154.04,154.54,155.03,155.51,155.99,156.47,156.94,157.41,157.88,158.34,158.80,159.26,159.71,160.17,160.62,161.07,161.53,161.98,162.43,162.88,163.33,163.79,164.24,164.70,165.16,165.61,166.08,166.54,167.01,167.48,167.95,168.43,168.92,169.40,169.90,170.40,170.90,171.41,171.93,172.46,172.99,173.54,174.09,174.66,175.24,175.83,176.43,177.05,177.69,178.34,179.02,179.71,180.44,181.19,181.97,182.78,183.64,184.54,185.49,186.51,187.60,188.77,190.05,191.47,193.06,194.88,197.04,199.71,203.30,209.05],
[0,125.70,129.87,132.56,134.61,136.30,137.74,139.02,140.17,141.22,142.19,143.10,143.95,144.76,145.53,146.26,146.96,147.64,148.30,148.93,149.55,150.15,150.73,151.30,151.86,152.41,152.95,153.48,154.00,154.51,155.01,155.51,156.00,156.49,156.97,157.45,157.92,158.39,158.86,159.32,159.79,160.24,160.70,161.16,161.61,162.07,162.52,162.97,163.43,163.88,164.33,164.79,165.24,165.70,166.16,166.62,167.09,167.55,168.02,168.49,168.97,169.45,169.93,170.42,170.92,171.42,171.92,172.44,172.96,173.48,174.02,174.57,175.12,175.69,176.27,176.86,177.47,178.09,178.73,179.39,180.06,180.76,181.49,182.24,183.02,183.84,184.70,185.60,186.56,187.58,188.67,189.84,191.13,192.55,194.14,195.97,198.14,200.82,204.42,210.18],
[0,126.57,130.76,133.46,135.52,137.21,138.66,139.94,141.09,142.14,143.12,144.03,144.88,145.69,146.47,147.20,147.91,148.59,149.25,149.88,150.50,151.10,151.69,152.26,152.82,153.37,153.91,154.44,154.96,155.48,155.98,156.48,156.98,157.47,157.95,158.43,158.90,159.37,159.84,160.31,160.77,161.23,161.69,162.15,162.60,163.06,163.51,163.97,164.42,164.88,165.33,165.79,166.25,166.71,167.17,167.63,168.09,168.56,169.03,169.50,169.98,170.46,170.95,171.44,171.94,172.44,172.95,173.46,173.98,174.51,175.05,175.60,176.16,176.73,177.31,177.90,178.51,179.13,179.77,180.43,181.11,181.81,182.54,183.29,184.08,184.90,185.76,186.66,187.62,188.64,189.74,190.92,192.21,193.63,195.23,197.06,199.23,201.92,205.53,211.30],
[0,127.44,131.64,134.36,136.42,138.12,139.57,140.86,142.01,143.07,144.05,144.96,145.82,146.63,147.41,148.15,148.85,149.54,150.20,150.84,151.46,152.06,152.65,153.22,153.79,154.34,154.88,155.41,155.93,156.45,156.95,157.46,157.95,158.44,158.93,159.41,159.88,160.36,160.83,161.29,161.76,162.22,162.68,163.14,163.60,164.05,164.51,164.97,165.42,165.88,166.33,166.79,167.25,167.71,168.17,168.64,169.10,169.57,170.04,170.52,171.00,171.48,171.97,172.46,172.96,173.46,173.97,174.48,175.01,175.54,176.08,176.63,177.19,177.76,178.34,178.94,179.55,180.17,180.81,181.47,182.15,182.86,183.59,184.34,185.13,185.95,186.82,187.73,188.69,189.71,190.81,191.99,193.28,194.71,196.32,198.15,200.33,203.02,206.64,212.43],
[0,128.32,132.53,135.25,137.33,139.03,140.49,141.78,142.94,144.00,144.98,145.89,146.76,147.57,148.35,149.09,149.80,150.49,151.15,151.79,152.41,153.02,153.61,154.18,154.75,155.30,155.84,156.38,156.90,157.42,157.93,158.43,158.93,159.42,159.90,160.39,160.86,161.34,161.81,162.28,162.74,163.21,163.67,164.13,164.59,165.05,165.50,165.96,166.42,166.88,167.33,167.79,168.25,168.71,169.18,169.64,170.11,170.58,171.05,171.53,172.01,172.49,172.98,173.48,173.98,174.48,174.99,175.51,176.03,176.57,177.11,177.66,178.22,178.79,179.38,179.97,180.59,181.21,181.86,182.52,183.20,183.91,184.64,185.40,186.19,187.01,187.88,188.79,189.75,190.78,191.88,193.07,194.36,195.79,197.40,199.24,201.42,204.13,207.75,213.56],
[0,129.19,133.42,136.15,138.23,139.94,141.40,142.70,143.86,144.92,145.91,146.83,147.69,148.51,149.29,150.03,150.75,151.43,152.10,152.74,153.36,153.97,154.56,155.14,155.71,156.26,156.81,157.34,157.87,158.39,158.90,159.40,159.90,160.39,160.88,161.36,161.84,162.32,162.79,163.26,163.73,164.19,164.66,165.12,165.58,166.04,166.50,166.96,167.42,167.87,168.33,168.79,169.26,169.72,170.18,170.65,171.12,171.59,172.06,172.54,173.02,173.51,174.00,174.49,174.99,175.50,176.01,176.53,177.06,177.59,178.14,178.69,179.25,179.83,180.41,181.01,181.62,182.25,182.90,183.56,184.25,184.95,185.69,186.45,187.24,188.07,188.93,189.85,190.82,191.84,192.95,194.14,195.44,196.87,198.49,200.33,202.52,205.23,208.87,214.69],
[0,130.06,134.31,137.05,139.14,140.85,142.32,143.62,144.78,145.85,146.84,147.76,148.63,149.45,150.23,150.98,151.69,152.38,153.05,153.69,154.32,154.93,155.52,156.10,156.67,157.23,157.77,158.31,158.84,159.36,159.87,160.37,160.87,161.37,161.86,162.34,162.82,163.30,163.78,164.25,164.72,165.18,165.65,166.11,166.57,167.03,167.49,167.95,168.41,168.87,169.33,169.80,170.26,170.72,171.19,171.66,172.13,172.60,173.08,173.55,174.04,174.52,175.02,175.51,176.01,176.52,177.04,177.56,178.08,178.62,179.17,179.72,180.28,180.86,181.45,182.05,182.66,183.29,183.94,184.61,185.29,186.00,186.74,187.50,188.29,189.12,189.99,190.91,191.88,192.91,194.02,195.21,196.51,197.95,199.57,201.42,203.62,206.33,209.98,215.81],
[0,130.94,135.20,137.95,140.04,141.76,143.23,144.54,145.71,146.78,147.77,148.69,149.56,150.39,151.17,151.92,152.64,153.33,154.00,154.65,155.27,155.88,156.48,157.06,157.63,158.19,158.74,159.28,159.80,160.33,160.84,161.35,161.85,162.35,162.84,163.32,163.81,164.28,164.76,165.23,165.70,166.17,166.64,167.10,167.56,168.03,168.49,168.95,169.41,169.87,170.33,170.80,171.26,171.73,172.19,172.66,173.13,173.61,174.09,174.57,175.05,175.54,176.03,176.53,177.03,177.54,178.06,178.58,179.11,179.65,180.19,180.75,181.32,181.89,182.48,183.08,183.70,184.33,184.98,185.65,186.34,187.05,187.79,188.55,189.35,190.18,191.05,191.97,192.94,193.98,195.09,196.28,197.59,199.03,200.65,202.51,204.71,207.43,211.09,216.94],
[0,131.81,136.09,138.85,140.95,142.67,144.15,145.46,146.63,147.71,148.70,149.63,150.50,151.33,152.11,152.86,153.58,154.28,154.95,155.60,156.23,156.84,157.44,158.02,158.59,159.15,159.70,160.24,160.77,161.30,161.81,162.32,162.82,163.32,163.81,164.30,164.79,165.27,165.74,166.22,166.69,167.16,167.62,168.09,168.56,169.02,169.48,169.94,170.41,170.87,171.33,171.80,172.26,172.73,173.20,173.67,174.14,174.62,175.10,175.58,176.06,176.55,177.05,177.55,178.05,178.56,179.08,179.60,180.14,180.67,181.22,181.78,182.35,182.93,183.52,184.12,184.74,185.37,186.02,186.69,187.38,188.10,188.84,189.60,190.40,191.24,192.11,193.03,194.01,195.04,196.16,197.36,198.67,200.11,201.74,203.60,205.80,208.53,212.20,218.06],
[0,132.69,136.98,139.74,141.85,143.58,145.07,146.38,147.56,148.63,149.63,150.56,151.44,152.27,153.05,153.81,154.53,155.23,155.90,156.55,157.18,157.80,158.40,158.98,159.56,160.12,160.67,161.21,161.74,162.27,162.78,163.29,163.80,164.30,164.79,165.28,165.77,166.25,166.73,167.20,167.67,168.15,168.61,169.08,169.55,170.01,170.48,170.94,171.40,171.87,172.33,172.80,173.27,173.73,174.20,174.68,175.15,175.63,176.11,176.59,177.08,177.57,178.07,178.57,179.07,179.58,180.10,180.63,181.16,181.70,182.25,182.81,183.38,183.96,184.55,185.16,185.78,186.41,187.07,187.74,188.43,189.14,189.89,190.65,191.46,192.29,193.17,194.09,195.07,196.11,197.23,198.43,199.74,201.19,202.82,204.69,206.90,209.64,213.31,219.19],
[0,133.56,137.87,140.64,142.76,144.49,145.98,147.30,148.48,149.56,150.56,151.50,152.37,153.21,154.00,154.75,155.48,156.18,156.85,157.50,158.14,158.75,159.36,159.94,160.52,161.08,161.63,162.18,162.71,163.24,163.76,164.27,164.77,165.27,165.77,166.26,166.75,167.23,167.71,168.19,168.66,169.13,169.60,170.07,170.54,171.01,171.47,171.94,172.40,172.87,173.33,173.80,174.27,174.74,175.21,175.68,176.16,176.64,177.12,177.60,178.09,178.58,179.08,179.58,180.09,180.61,181.12,181.65,182.19,182.73,183.28,183.84,184.41,184.99,185.59,186.19,186.81,187.45,188.11,188.78,189.47,190.19,190.93,191.71,192.51,193.35,194.23,195.15,196.13,197.18,198.29,199.50,200.82,202.27,203.91,205.78,207.99,210.74,214.42,220.31],
[0,134.44,138.76,141.54,143.66,145.41,146.90,148.22,149.40,150.49,151.49,152.43,153.31,154.14,154.94,155.70,156.42,157.12,157.80,158.46,159.09,159.71,160.31,160.90,161.48,162.04,162.60,163.14,163.68,164.21,164.73,165.24,165.75,166.25,166.75,167.24,167.73,168.21,168.69,169.17,169.65,170.12,170.59,171.06,171.53,172.00,172.47,172.93,173.40,173.87,174.33,174.80,175.27,175.74,176.22,176.69,177.17,177.65,178.13,178.62,179.11,179.60,180.10,180.60,181.11,181.63,182.15,182.67,183.21,183.75,184.31,184.87,185.44,186.02,186.62,187.23,187.85,188.49,189.15,189.82,190.52,191.24,191.98,192.76,193.56,194.40,195.28,196.21,197.20,198.24,199.36,200.57,201.89,203.35,204.99,206.87,209.09,211.84,215.53,221.44],
[0,135.31,139.65,142.44,144.57,146.32,147.82,149.14,150.33,151.42,152.42,153.36,154.25,155.08,155.88,156.64,157.37,158.07,158.75,159.41,160.05,160.67,161.27,161.86,162.44,163.01,163.56,164.11,164.65,165.18,165.70,166.21,166.72,167.23,167.73,168.22,168.71,169.19,169.68,170.16,170.63,171.11,171.58,172.05,172.52,172.99,173.46,173.93,174.40,174.86,175.33,175.80,176.27,176.75,177.22,177.70,178.18,178.66,179.14,179.63,180.12,180.61,181.11,181.62,182.13,182.65,183.17,183.70,184.24,184.78,185.33,185.90,186.47,187.06,187.65,188.27,188.89,189.53,190.19,190.87,191.56,192.29,193.03,193.81,194.62,195.46,196.34,197.27,198.26,199.31,200.43,201.65,202.97,204.43,206.07,207.95,210.18,212.94,216.64,222.56],
[0,136.19,140.54,143.34,145.48,147.23,148.73,150.06,151.25,152.35,153.36,154.30,155.19,156.02,156.82,157.59,158.32,159.02,159.70,160.36,161.00,161.62,162.23,162.82,163.40,163.97,164.53,165.08,165.62,166.15,166.67,167.19,167.70,168.20,168.70,169.20,169.69,170.18,170.66,171.14,171.62,172.10,172.57,173.04,173.51,173.99,174.45,174.92,175.39,175.86,176.33,176.80,177.28,177.75,178.23,178.70,179.18,179.67,180.15,180.64,181.13,181.63,182.13,182.64,183.15,183.67,184.19,184.72,185.26,185.81,186.36,186.93,187.50,188.09,188.69,189.30,189.93,190.57,191.23,191.91,192.61,193.33,194.08,194.86,195.67,196.51,197.40,198.33,199.32,200.37,201.50,202.72,204.04,205.51,207.16,209.04,211.27,214.04,217.75,223.69],
[0,137.07,141.43,144.24,146.38,148.14,149.65,150.98,152.18,153.28,154.29,155.23,156.12,156.96,157.77,158.53,159.26,159.97,160.65,161.32,161.96,162.58,163.19,163.79,164.37,164.94,165.50,166.05,166.59,167.12,167.64,168.16,168.67,169.18,169.68,170.18,170.67,171.16,171.64,172.13,172.61,173.08,173.56,174.03,174.51,174.98,175.45,175.92,176.39,176.86,177.33,177.81,178.28,178.75,179.23,179.71,180.19,180.68,181.16,181.65,182.15,182.64,183.15,183.66,184.17,184.69,185.21,185.75,186.29,186.83,187.39,187.96,188.53,189.12,189.72,190.34,190.97,191.61,192.27,192.95,193.65,194.38,195.13,195.91,196.72,197.57,198.46,199.39,200.38,201.44,202.57,203.79,205.12,206.59,208.24,210.13,212.37,215.14,218.86,224.81],
[0,137.94,142.32,145.14,147.29,149.06,150.57,151.90,153.11,154.20,155.22,156.17,157.06,157.90,158.71,159.48,160.21,160.92,161.61,162.27,162.91,163.54,164.15,164.75,165.33,165.90,166.46,167.01,167.56,168.09,168.62,169.14,169.65,170.16,170.66,171.16,171.65,172.14,172.63,173.11,173.59,174.07,174.55,175.02,175.50,175.97,176.44,176.92,177.39,177.86,178.33,178.81,179.28,179.76,180.24,180.72,181.20,181.68,182.17,182.66,183.16,183.66,184.16,184.67,185.19,185.71,186.23,186.77,187.31,187.86,188.42,188.99,189.57,190.16,190.76,191.37,192.00,192.65,193.31,194.00,194.70,195.43,196.18,196.96,197.77,198.62,199.52,200.45,201.45,202.50,203.64,204.86,206.19,207.67,209.32,211.22,213.46,216.24,219.97,225.93],
[0,138.82,143.21,146.04,148.20,149.97,151.49,152.83,154.03,155.13,156.15,157.10,158.00,158.85,159.65,160.42,161.16,161.87,162.56,163.22,163.87,164.50,165.11,165.71,166.29,166.87,167.43,167.98,168.52,169.06,169.59,170.11,170.62,171.13,171.64,172.14,172.63,173.12,173.61,174.10,174.58,175.06,175.54,176.02,176.49,176.97,177.44,177.91,178.39,178.86,179.33,179.81,180.28,180.76,181.24,181.72,182.21,182.69,183.18,183.68,184.17,184.67,185.18,185.69,186.21,186.73,187.26,187.79,188.33,188.89,189.45,190.02,190.60,191.19,191.79,192.41,193.04,193.69,194.35,195.04,195.74,196.47,197.23,198.01,198.83,199.68,200.57,201.51,202.51,203.57,204.70,205.93,207.27,208.74,210.40,212.30,214.55,217.34,221.08,227.06],
[0,139.70,144.10,146.94,149.11,150.88,152.40,153.75,154.96,156.06,157.09,158.04,158.94,159.79,160.59,161.37,162.11,162.82,163.51,164.18,164.82,165.45,166.07,166.67,167.25,167.83,168.39,168.95,169.49,170.03,170.56,171.08,171.60,172.11,172.62,173.12,173.61,174.11,174.60,175.08,175.57,176.05,176.53,177.01,177.48,177.96,178.43,178.91,179.38,179.86,180.33,180.81,181.29,181.77,182.25,182.73,183.22,183.70,184.19,184.69,185.19,185.69,186.20,186.71,187.23,187.75,188.28,188.82,189.36,189.91,190.47,191.05,191.63,192.22,192.83,193.44,194.08,194.73,195.39,196.08,196.79,197.52,198.28,199.06,199.88,200.73,201.63,202.57,203.57,204.63,205.77,207.00,208.34,209.82,211.48,213.39,215.64,218.44,222.19,228.18],
[0,140.58,144.99,147.85,150.01,151.80,153.32,154.67,155.88,156.99,158.02,158.97,159.87,160.73,161.54,162.31,163.05,163.77,164.46,165.13,165.78,166.41,167.03,167.63,168.22,168.79,169.36,169.92,170.46,171.00,171.53,172.06,172.57,173.09,173.59,174.10,174.59,175.09,175.58,176.07,176.55,177.04,177.52,178.00,178.47,178.95,179.43,179.90,180.38,180.86,181.33,181.81,182.29,182.77,183.25,183.74,184.22,184.71,185.20,185.70,186.20,186.70,187.21,187.73,188.24,188.77,189.30,189.84,190.38,190.94,191.50,192.07,192.66,193.25,193.86,194.48,195.11,195.77,196.43,197.12,197.83,198.56,199.32,200.11,200.93,201.79,202.69,203.63,204.63,205.70,206.84,208.07,209.42,210.90,212.57,214.48,216.74,219.54,223.29,229.30],
[0,141.45,145.89,148.75,150.92,152.71,154.24,155.59,156.81,157.92,158.95,159.91,160.81,161.67,162.48,163.26,164.00,164.72,165.41,166.08,166.74,167.37,167.99,168.59,169.18,169.76,170.33,170.88,171.43,171.97,172.51,173.03,173.55,174.06,174.57,175.08,175.58,176.07,176.56,177.05,177.54,178.02,178.51,178.99,179.47,179.95,180.42,180.90,181.38,181.86,182.33,182.81,183.29,183.77,184.26,184.74,185.23,185.72,186.22,186.71,187.21,187.72,188.23,188.74,189.26,189.79,190.32,190.86,191.41,191.96,192.53,193.10,193.69,194.28,194.89,195.52,196.15,196.80,197.48,198.17,198.88,199.61,200.37,201.16,201.98,202.84,203.74,204.69,205.69,206.76,207.91,209.14,210.49,211.98,213.65,215.56,217.83,220.63,224.40,230.42],
[0,142.33,146.78,149.65,151.83,153.62,155.16,156.52,157.74,158.85,159.88,160.85,161.75,162.61,163.42,164.20,164.95,165.67,166.37,167.04,167.69,168.33,168.95,169.55,170.14,170.72,171.29,171.85,172.40,172.94,173.48,174.00,174.53,175.04,175.55,176.06,176.56,177.05,177.55,178.04,178.53,179.01,179.50,179.98,180.46,180.94,181.42,181.90,182.38,182.85,183.33,183.81,184.30,184.78,185.26,185.75,186.24,186.73,187.23,187.72,188.23,188.73,189.24,189.76,190.28,190.81,191.34,191.88,192.43,192.99,193.56,194.13,194.72,195.32,195.93,196.55,197.19,197.84,198.52,199.21,199.92,200.66,201.42,202.21,203.04,203.90,204.80,205.75,206.76,207.83,208.97,210.21,211.56,213.05,214.73,216.65,218.92,221.73,225.51,231.54],
[0,143.21,147.67,150.55,152.74,154.54,156.08,157.44,158.66,159.78,160.82,161.78,162.69,163.55,164.37,165.15,165.90,166.62,167.32,167.99,168.65,169.28,169.91,170.51,171.11,171.69,172.26,172.82,173.37,173.91,174.45,174.98,175.50,176.02,176.53,177.04,177.54,178.04,178.53,179.02,179.51,180.00,180.49,180.97,181.45,181.93,182.41,182.89,183.37,183.85,184.33,184.82,185.30,185.78,186.27,186.76,187.25,187.74,188.24,188.74,189.24,189.75,190.26,190.78,191.30,191.83,192.36,192.91,193.46,194.02,194.58,195.16,195.75,196.35,196.96,197.59,198.23,198.88,199.56,200.25,200.96,201.70,202.47,203.26,204.09,204.95,205.86,206.81,207.82,208.89,210.04,211.28,212.64,214.13,215.81,217.73,220.01,222.83,226.62,232.67],
[0,144.09,148.57,151.45,153.65,155.45,157.00,158.36,159.59,160.71,161.75,162.72,163.63,164.49,165.31,166.09,166.85,167.57,168.27,168.95,169.60,170.24,170.87,171.47,172.07,172.65,173.23,173.79,174.34,174.89,175.42,175.95,176.48,177.00,177.51,178.02,178.52,179.02,179.52,180.01,180.50,180.99,181.48,181.96,182.44,182.93,183.41,183.89,184.37,184.85,185.33,185.82,186.30,186.79,187.27,187.76,188.25,188.75,189.25,189.75,190.25,190.76,191.28,191.79,192.32,192.85,193.39,193.93,194.48,195.04,195.61,196.19,196.78,197.38,197.99,198.62,199.26,199.92,200.60,201.29,202.01,202.75,203.51,204.31,205.14,206.00,206.91,207.87,208.88,209.95,211.11,212.35,213.71,215.21,216.89,218.82,221.10,223.93,227.72,233.79],
[0,144.97,149.46,152.35,154.56,156.37,157.92,159.29,160.52,161.64,162.68,163.66,164.57,165.43,166.26,167.04,167.80,168.52,169.22,169.90,170.56,171.20,171.83,172.44,173.03,173.62,174.19,174.76,175.31,175.86,176.40,176.93,177.45,177.97,178.49,179.00,179.50,180.00,180.50,181.00,181.49,181.98,182.46,182.95,183.44,183.92,184.40,184.88,185.37,185.85,186.33,186.82,187.30,187.79,188.28,188.77,189.26,189.76,190.26,190.76,191.27,191.78,192.29,192.81,193.34,193.87,194.41,194.95,195.51,196.07,196.64,197.22,197.81,198.41,199.03,199.66,200.30,200.96,201.64,202.33,203.05,203.79,204.56,205.36,206.19,207.06,207.97,208.93,209.94,211.02,212.17,213.42,214.78,216.28,217.97,219.91,222.19,225.03,228.83,234.91],
[0,145.85,150.35,153.26,155.47,157.28,158.84,160.21,161.44,162.57,163.62,164.59,165.51,166.37,167.20,167.99,168.74,169.47,170.17,170.86,171.52,172.16,172.79,173.40,174.00,174.58,175.16,175.72,176.28,176.83,177.37,177.90,178.43,178.95,179.47,179.98,180.48,180.99,181.48,181.98,182.47,182.97,183.45,183.94,184.43,184.91,185.40,185.88,186.36,186.85,187.33,187.82,188.31,188.79,189.28,189.78,190.27,190.77,191.27,191.77,192.28,192.79,193.31,193.83,194.36,194.89,195.43,195.98,196.53,197.09,197.67,198.25,198.84,199.44,200.06,200.69,201.34,202.00,202.68,203.37,204.10,204.84,205.61,206.41,207.24,208.11,209.02,209.98,211.00,212.08,213.24,214.49,215.85,217.36,219.05,220.99,223.28,226.12,229.93,236.03],
[0,146.73,151.25,154.16,156.38,158.20,159.76,161.13,162.37,163.50,164.55,165.53,166.45,167.32,168.14,168.93,169.69,170.42,171.13,171.81,172.47,173.12,173.75,174.36,174.96,175.55,176.13,176.69,177.25,177.80,178.34,178.88,179.40,179.93,180.44,180.96,181.46,181.97,182.47,182.97,183.46,183.95,184.44,184.93,185.42,185.91,186.39,186.88,187.36,187.85,188.33,188.82,189.31,189.80,190.29,190.78,191.28,191.78,192.28,192.78,193.29,193.81,194.32,194.85,195.37,195.91,196.45,197.00,197.55,198.12,198.69,199.28,199.87,200.48,201.09,201.73,202.37,203.04,203.72,204.42,205.14,205.88,206.66,207.46,208.29,209.17,210.08,211.04,212.06,213.14,214.31,215.56,216.93,218.44,220.13,222.08,224.37,227.22,231.04,237.15],
[0,147.61,152.14,155.06,157.29,159.11,160.68,162.06,163.30,164.44,165.49,166.47,167.39,168.26,169.09,169.88,170.64,171.37,172.08,172.77,173.43,174.08,174.71,175.32,175.92,176.51,177.09,177.66,178.22,178.77,179.31,179.85,180.38,180.90,181.42,181.94,182.45,182.95,183.45,183.95,184.45,184.94,185.43,185.92,186.41,186.90,187.39,187.87,188.36,188.85,189.33,189.82,190.31,190.80,191.29,191.79,192.29,192.79,193.29,193.79,194.31,194.82,195.34,195.86,196.39,196.93,197.47,198.02,198.58,199.14,199.72,200.30,200.90,201.51,202.13,202.76,203.41,204.07,204.76,205.46,206.18,206.93,207.70,208.51,209.34,210.22,211.13,212.10,213.12,214.21,215.37,216.63,218.00,219.51,221.21,223.16,225.46,228.32,232.15,238.27],
[0,148.49,153.04,155.97,158.20,160.03,161.60,162.98,164.23,165.37,166.42,167.40,168.33,169.20,170.03,170.83,171.59,172.32,173.03,173.72,174.39,175.03,175.67,176.28,176.89,177.48,178.06,178.63,179.19,179.74,180.29,180.83,181.36,181.88,182.40,182.92,183.43,183.93,184.44,184.94,185.43,185.93,186.42,186.91,187.40,187.89,188.38,188.87,189.36,189.85,190.33,190.82,191.31,191.81,192.30,192.80,193.29,193.79,194.30,194.81,195.32,195.83,196.35,196.88,197.41,197.95,198.49,199.04,199.60,200.17,200.75,201.33,201.93,202.54,203.16,203.79,204.44,205.11,205.80,206.50,207.23,207.97,208.75,209.56,210.40,211.27,212.19,213.16,214.18,215.27,216.44,217.70,219.07,220.59,222.29,224.24,226.55,229.41,233.25,239.39],
[0,149.37,153.93,156.87,159.11,160.94,162.52,163.91,165.16,166.30,167.35,168.34,169.27,170.14,170.98,171.77,172.54,173.28,173.99,174.68,175.34,175.99,176.63,177.25,177.85,178.44,179.03,179.60,180.16,180.71,181.26,181.80,182.33,182.86,183.38,183.90,184.41,184.92,185.42,185.92,186.42,186.92,187.41,187.91,188.40,188.89,189.38,189.87,190.35,190.84,191.33,191.82,192.32,192.81,193.30,193.80,194.30,194.80,195.31,195.82,196.33,196.85,197.37,197.90,198.43,198.97,199.51,200.07,200.63,201.20,201.77,202.36,202.96,203.57,204.19,204.83,205.48,206.15,206.83,207.54,208.27,209.02,209.80,210.61,211.45,212.32,213.25,214.22,215.24,216.33,217.50,218.77,220.14,221.66,223.37,225.33,227.64,230.51,234.36,240.50],
[0,150.25,154.83,157.78,160.02,161.86,163.44,164.83,166.08,167.23,168.29,169.28,170.21,171.09,171.92,172.72,173.49,174.23,174.94,175.63,176.30,176.95,177.59,178.21,178.82,179.41,179.99,180.57,181.13,181.69,182.23,182.77,183.31,183.84,184.36,184.88,185.39,185.90,186.41,186.91,187.41,187.91,188.40,188.90,189.39,189.88,190.37,190.86,191.35,191.84,192.33,192.83,193.32,193.81,194.31,194.81,195.31,195.81,196.32,196.83,197.34,197.86,198.39,198.91,199.45,199.99,200.53,201.09,201.65,202.22,202.80,203.39,203.99,204.60,205.23,205.86,206.52,207.19,207.87,208.58,209.31,210.06,210.84,211.65,212.50,213.38,214.30,215.27,216.30,217.40,218.57,219.83,221.21,222.74,224.45,226.41,228.73,231.61,235.46,241.62],
[0,151.14,155.72,158.68,160.93,162.78,164.36,165.76,167.01,168.16,169.22,170.21,171.15,172.03,172.87,173.67,174.44,175.18,175.89,176.59,177.26,177.91,178.55,179.17,179.78,180.38,180.96,181.54,182.10,182.66,183.21,183.75,184.28,184.81,185.34,185.86,186.37,186.88,187.39,187.89,188.40,188.90,189.39,189.89,190.38,190.87,191.37,191.86,192.35,192.84,193.33,193.83,194.32,194.82,195.31,195.81,196.32,196.82,197.33,197.84,198.36,198.88,199.40,199.93,200.47,201.01,201.56,202.11,202.67,203.25,203.83,204.42,205.02,205.63,206.26,206.90,207.55,208.22,208.91,209.62,210.35,211.11,211.89,212.70,213.55,214.43,215.36,216.33,217.36,218.46,219.63,220.90,222.29,223.81,225.53,227.50,229.82,232.70,236.57,242.74],
[0,152.02,156.62,159.58,161.84,163.69,165.28,166.68,167.94,169.09,170.16,171.15,172.09,172.97,173.81,174.62,175.39,176.13,176.85,177.54,178.21,178.87,179.51,180.13,180.74,181.34,181.93,182.50,183.07,183.63,184.18,184.72,185.26,185.79,186.32,186.84,187.35,187.87,188.38,188.88,189.38,189.88,190.38,190.88,191.37,191.87,192.36,192.85,193.35,193.84,194.33,194.83,195.32,195.82,196.32,196.82,197.32,197.83,198.34,198.85,199.37,199.89,200.42,200.95,201.48,202.03,202.58,203.13,203.70,204.27,204.85,205.45,206.05,206.66,207.29,207.93,208.59,209.26,209.95,210.66,211.40,212.15,212.94,213.75,214.60,215.48,216.41,217.39,218.42,219.52,220.70,221.97,223.36,224.89,226.61,228.58,230.91,233.80,237.67,243.86],
[0,152.90,157.51,160.49,162.75,164.61,166.20,167.61,168.87,170.03,171.09,172.09,173.03,173.91,174.76,175.56,176.34,177.08,177.80,178.50,179.17,179.83,180.47,181.10,181.71,182.31,182.90,183.47,184.04,184.60,185.15,185.70,186.24,186.77,187.30,187.82,188.34,188.85,189.36,189.87,190.37,190.87,191.37,191.87,192.37,192.86,193.36,193.85,194.34,194.84,195.33,195.83,196.33,196.82,197.33,197.83,198.33,198.84,199.35,199.86,200.38,200.91,201.43,201.96,202.50,203.05,203.60,204.16,204.72,205.30,205.88,206.47,207.08,207.69,208.32,208.97,209.62,210.30,210.99,211.70,212.44,213.20,213.98,214.80,215.65,216.54,217.47,218.44,219.48,220.58,221.76,223.04,224.43,225.96,227.69,229.66,232.00,234.89,238.77,244.98],
[0,153.78,158.41,161.39,163.66,165.53,167.12,168.53,169.80,170.96,172.03,173.03,173.97,174.86,175.70,176.51,177.29,178.03,178.75,179.45,180.13,180.79,181.43,182.06,182.67,183.27,183.86,184.44,185.01,185.57,186.13,186.67,187.21,187.75,188.28,188.80,189.32,189.83,190.34,190.85,191.36,191.86,192.36,192.86,193.36,193.85,194.35,194.85,195.34,195.84,196.33,196.83,197.33,197.83,198.33,198.83,199.34,199.85,200.36,200.88,201.40,201.92,202.45,202.98,203.52,204.07,204.62,205.18,205.75,206.32,206.91,207.50,208.11,208.73,209.36,210.00,210.66,211.34,212.03,212.75,213.48,214.24,215.03,215.85,216.70,217.59,218.52,219.50,220.54,221.64,222.83,224.11,225.50,227.04,228.77,230.75,233.09,235.99,239.88,246.09],
[0,154.67,159.31,162.30,164.58,166.44,168.04,169.46,170.73,171.89,172.96,173.97,174.91,175.80,176.65,177.46,178.24,178.99,179.71,180.41,181.09,181.75,182.39,183.02,183.64,184.24,184.83,185.41,185.98,186.55,187.10,187.65,188.19,188.73,189.25,189.78,190.30,190.82,191.33,191.84,192.34,192.85,193.35,193.85,194.35,194.85,195.35,195.84,196.34,196.84,197.33,197.83,198.33,198.83,199.34,199.84,200.35,200.86,201.37,201.89,202.41,202.93,203.46,204.00,204.54,205.09,205.64,206.20,206.77,207.35,207.93,208.53,209.14,209.76,210.39,211.03,211.70,212.37,213.07,213.79,214.52,215.29,216.08,216.90,217.75,218.64,219.57,220.56,221.60,222.71,223.89,225.17,226.57,228.11,229.84,231.83,234.18,237.08,240.98,247.21],
[0,155.55,160.20,163.20,165.49,167.36,168.97,170.38,171.66,172.82,173.90,174.90,175.85,176.74,177.59,178.41,179.19,179.94,180.66,181.36,182.04,182.71,183.35,183.98,184.60,185.21,185.80,186.38,186.95,187.52,188.07,188.62,189.17,189.70,190.23,190.76,191.28,191.80,192.31,192.82,193.33,193.84,194.34,194.84,195.34,195.84,196.34,196.84,197.34,197.84,198.33,198.83,199.33,199.84,200.34,200.85,201.35,201.87,202.38,202.90,203.42,203.95,204.48,205.01,205.56,206.11,206.66,207.22,207.79,208.37,208.96,209.56,210.17,210.79,211.42,212.07,212.73,213.41,214.11,214.83,215.57,216.33,217.12,217.94,218.80,219.69,220.63,221.61,222.66,223.77,224.96,226.24,227.64,229.19,230.92,232.91,235.26,238.18,242.08,248.33],
[0,156.43,161.10,164.11,166.40,168.28,169.89,171.31,172.59,173.76,174.84,175.84,176.79,177.69,178.54,179.36,180.14,180.89,181.62,182.32,183.00,183.67,184.31,184.95,185.57,186.17,186.77,187.35,187.92,188.49,189.05,189.60,190.14,190.68,191.21,191.74,192.26,192.78,193.30,193.81,194.32,194.83,195.33,195.83,196.34,196.84,197.34,197.84,198.33,198.83,199.33,199.83,200.34,200.84,201.35,201.85,202.36,202.88,203.39,203.91,204.43,204.96,205.49,206.03,206.57,207.12,207.68,208.24,208.82,209.40,209.99,210.58,211.20,211.82,212.45,213.10,213.77,214.45,215.15,215.87,216.61,217.37,218.17,218.99,219.85,220.74,221.68,222.67,223.72,224.83,226.02,227.31,228.71,230.26,232.00,233.99,236.35,239.27,243.19,249.44]);

# Clean Exit: For now, remove lingering files
sub cleanexit {
	unlink 'final.c';
}

##?##?## GENERAL PRINTING ##?##?##

# Printing during phase 1, parsing
sub printP {
	my $level = $_[0];
	my $text = $_[1];
	if ($printParsingflag >= $level) {
		print $dataoutfile $text;
	}
}
# Printing during phase 2, generation
sub printG {
	my $level = $_[0];
	my $text = $_[1];
	if (($printGenerateflag != 2 || $level != 0) && $printGenerateflag > 0 && $printGenerateflag >= $level) {
		print $dataoutfile $text;
	}
}
# Error printing. Exits the program when hit.
sub printerror {
	my $code = $_[0];
	my $errorlinenumber = $_[1];
	my $text = $_[2];
	my $message = $_[3];
		
	if ($printerrorsflag != 0) {
		print "\n";
		if ($parsingflag == 1) {
			print "Error Code $code at line $linenumber: '$text'\n";
			print "$message\n";
		}
		elsif ($errorlinenumber ne "" && numbervsstring($errorlinenumber) == 1) {
			print "Error Code $code at line $errorlinenumber: '$text'\n";
			print "$message\n";
		}
		else {
			print "Error Code $code while working with: '$text'\n";
			print "$message\n";
		}
		cleanexit();
		exit;
	}
}
# Warning printing. Can still continue processing.
sub printwarning {
	my $code = $_[0];
	my $errorlinenumber = $_[1];
	my $text = $_[2];
	my $message = $_[3];
	
	if ($printerrorsflag != 0) {
		print "\n";	
		my $fullmessage;
		if ($parsingflag == 1) {
			$fullmessage = "Warning Code $code at line $linenumber: '$text'. " . "$message\n";
		}
		elsif ($errorlinenumber ne "" && numbervsstring($errorlinenumber) == 1) {
			$fullmessage = "Warning Code $code at line $errorlinenumber: '$text'. " . "$message\n";
		}
		else {
			$fullmessage = "Warning Code $code while working with: '$text'. " . "$message\n";
		}
		print $fullmessage;
		$warningcounter++;
		$warninglist[scalar @warninglist] = $fullmessage;
	}
}

##?##?## PRINT SUMMARY STUFF ##?##?##

# PARSING PHASE: Print values, varlists, variables, add and removes
sub printParameters {
	printP (1, "Print Parameters!\n");
	printP (1, "Size of Parametersnumber:        '". scalar @parametersnumber. "'\n");
	printP (1, "Size of Parameters:              '". scalar @parameters. "'\n");
	printP (1, "Size of ParametersFeature:       '". scalar @parametersfeature. "'\n");
	printP (1, "Size of ParametersDistVar:       '". scalar @parametersdistvar. "'\n");
	printP (1, "Size of ParametersEqualPar:      '". scalar @parametersequalpar. "'\n");
	printP (1, "Size of ParametersEvalFlag:      '". scalar @parametersevalflag. "'\n");
	printP (1, "Size of ParametersFullFlag:      '". scalar @parametersfullflag. "'\n");
	printP (1, "Size of parametersReportFlag:    '". scalar @parametersreportflag. "'\n");
	printP (1, "Size of parametersNoReplaceFlag: '". scalar @parametersnoreplaceflag. "'\n\n");

	for(my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
		printP (1, " Parameter $parametersnumber[$pariter]:              '". $parameters[$pariter]. "'\n");
		printP (1, "  parametersfeature:       '". $parametersfeature[$pariter]. "'\n");
		printP (1, "  parametersdistvar:       '". $parametersdistvar[$pariter]. "'\n");
		printP (1, "  parametersequalpar:      '". $parametersequalpar[$pariter]. "'\n");
		printP (1, "  parametersevalflag:      '". $parametersevalflag[$pariter]. "'\n");
		printP (1, "  parametersfullflag:      '". $parametersfullflag[$pariter]. "'\n");
		printP (1, "  parametersreportflag:    '". $parametersreportflag[$pariter]. "'\n");
		printP (1, "  parametersnoreplaceflag: '". $parametersnoreplaceflag[$pariter]. "'\n\n");
		
	}
	
	
	printP (1, "\nPrint VarList!\n");
	printP (1, "Size of VarListName:         '". scalar @varlistname. "'\n");
	printP (1, "Size of VarListVarName:      '". scalar @varlistvarname. "'\n");
	printP (1, "Size of VarListArg:          '". scalar @varlistarg. "'\n");
	printP (1, "Size of VarListequalvar:     '". scalar @varlistequalvar. "'\n");
	printP (1, "Size of VarListevalflag:     '". scalar @varlistevalflag. "'\n");
	printP (1, "Size of VarListType:         '". scalar @varlisttype. "'\n");
	printP (1, "Size of VarListInitValue:    '". scalar @varlistinitvalue. "'\n");
	printP (1, "Size of VarListinitallflag:  '". scalar @varlistinitallflag. "'\n");
	printP (1, "Size of VarListendtouch:     '". scalar @varlistendtouch. "'\n\n");
	
	for(my $vliter = 0; $vliter < scalar @varlistname; $vliter++) {
		printP (1, " varlistname:          '". $varlistname[$vliter]. "'\n");
		printP (1, "  varlistarg:          '". $varlistarg[$vliter]. "'\n");
		printP (1, "  varlistequalvar      '". $varlistequalvar[$vliter]. "'\n");
		printP (1, "  varlistevalflag:     '". $varlistevalflag[$vliter]. "'\n");
		printP (1, "  varlisttype:         '". $varlisttype[$vliter]. "'\n");
		printP (1, "  varlistinitvalue:    '". $varlistinitvalue[$vliter]. "'\n");
		printP (1, "  varlistinitallflag:  '". $varlistinitallflag[$vliter]. "'\n");
		printP (1, "  varlistendtouch:     '". $varlistendtouch[$vliter]. "'\n");
	}
	
	
	printP (1, "\nPrint Variables!\n");
	printP (1, "Size of VariablesNumber:     '". scalar @variablesnumber. "'\n");
	printP (1, "Size of Variables:           '". scalar @variables. "'\n");
	printP (1, "Size of variablesVarlistVar: '". scalar @variablesvarlistvar. "'\n");
	printP (1, "Size of variablesEqualPar:   '". scalar @variablesequalpar. "'\n");
	printP (1, "Size of variablesEvalflag:   '". scalar @variablesevalflag. "'\n");
	printP (1, "Size of variablesreportflag: '". scalar @variablesreportflag. "'\n");
	printP (1, "Size of variablesFeature:    '". scalar @variablesfeature. "'\n\n");

	for(my $variter = 0; $variter < scalar @variables; $variter++) {
		printP (1, " Variable $variablesnumber[$variter]:           '". $variables[$variter]. "'\n");
		printP (1, "  variablesvarlistvar: '". $variablesvarlistvar[$variter]. "'\n");
		printP (1, "  variablesequalpar:   '". $variablesequalpar[$variter]. "'\n");
		printP (1, "  variablesevalflag:   '". $variablesevalflag[$variter]. "'\n");
		printP (1, "  variablesreportflag: '". $variablesreportflag[$variter]. "'\n");
		printP (1, "  variablesfeature:    '". $variablesfeature[$variter]. "'\n\n");
	}
	
	printP (1, "\nPrint AddVariables!\n");
	printP (1, "Size of AddVariablesNumber:  '". scalar @addvariablesnumber. "'\n");
	printP (1, "Size of AddVariables:        '". scalar @addvariables. "'\n");
	printP (1, "Size of AddVariablesDistVar: '". scalar @addvariablesvarlistvar. "'\n");
	printP (1, "Size of AddVariablesFeature: '". scalar @addvariablesfeature. "'\n\n");
	
	for(my $additer = 0; $additer < scalar @addvariables; $additer++) {
		printP (1, " addvariables $addvariablesnumber[$additer]:          '". $addvariables[$additer]. "'\n");
		printP (1, "  addvariablesvarlistvar: '". $addvariablesvarlistvar[$additer]. "'\n");
		printP (1, "  addvariablesfeature:    '". $addvariablesfeature[$additer]. "\n\n");
	}
	
	printP (1, "\nPrint RemVariables!\n");
	printP (1, "Size of RemVariablesNumber:  '". scalar @remvariablesnumber. "'\n");
	printP (1, "Size of RemVariables:        '". scalar @remvariables. "'\n");
	printP (1, "Size of RemVariablesDistVar: '". scalar @remvariablesvarlistvar. "'\n");
	printP (1, "Size of RemVariablesFeature: '". scalar @remvariablesfeature. "\n\n");

	for(my $remiter = 0; $remiter < scalar @remvariables; $remiter++) {
		printP (1, " remvariables $remvariablesnumber[$remiter]:          '". $remvariables[$remiter]. "'\n");
		printP (1, "  remvariablesvarlistvar: '". $remvariablesvarlistvar[$remiter]. "'\n");
		printP (1, "  remvariablesfeature:    '". $remvariablesfeature[$remiter]. "'\n\n");
	}
	

}
# PARSING PHASE: Print generate statements
sub printGenerates {	
	printP (1, "Print Distributions!\n");
	printP (1, "Size of globaldistributions:     ". scalar @globaldistributions. "\n");
	printP (1, "Size of localdistributions:     ". scalar @localdistributions. "\n");

	for(my $disiter = 0; $disiter < scalar @globaldistributions; $disiter++) {
		printP (1, " GlobalDistribution $disiter: ". $globaldistributions[$disiter]. "\n");
	}	
	
	for(my $disiter = 0; $disiter < scalar @localdistributions; $disiter++) {
		printP (1, " LocalDistribution $disiter: ". $localdistributions[$disiter]. "\n");
	}	
	
	printP (1, "Size of generates:     ". scalar @generates. "\n");
	printP (1, "Size of gendistribute: ". scalar @gendistribute. "\n");
	printP (1, "Size of gentouch:      ". scalar @gentouch. "\n");
	for(my $disiter = 0; $disiter < scalar @generates; $disiter++) {
		printP (1, " generates:     ". $generates[$disiter]. "\n");
		printP (1, " gendistribute: ". $gendistribute[$disiter]. "\n");
		printP (1, " gentouch:      ". $gentouch[$disiter]. "\n");
	}
}
# PARSING PHASE: Print global, program, features, genif and genloops
sub printFeatures {
	printP (1, "\nPrint features!\n");
	
	printP (1, "Size of Global:                ". scalar @globalcodelines. "\n");
	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @globalcodelines; $feaiter++) {
		printP (1, "  Global line $feaiter: $globalcodelines[$feaiter]");
	}
	
	printP (1, "Size of Global Enum:           ". scalar @globalenum. "\n");
	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @globalenum; $feaiter++) {
		printP (1, "  Global enum line $feaiter: $globalenum[$feaiter]\n");
	}
	printP (1, "Size of Global Report:         ". scalar @globalreport. "\n");
	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @globalreport; $feaiter++) {
		printP (1, "  Global report line $feaiter: $globalreport[$feaiter]\n");
	}
	
	
	
	printP (1, "Size of Program:               ". scalar @programcodelines. "\n");
	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @programcodelines; $feaiter++) {
		printP (1, "  Program line $feaiter: $programcodelines[$feaiter]");
	}
	
	printP (1, "Size of Program Enum:          ". scalar @programenum. "\n");
	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @programenum; $feaiter++) {
		printP (1, "  Program enum line $feaiter: $programenum[$feaiter]\n");
	}
	
	printP (1, "Size of Program Dist:          ". scalar @programdist. "\n");
	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @programdist; $feaiter++) {
		printP (1, "  Program dist line $feaiter: $programdist[$feaiter]\n");
	}
	
	printP (1, "Size of Program Report:        ". scalar @programreport. "\n");
	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @programreport; $feaiter++) {
		printP (1, "  Program report line $feaiter: $programreport[$feaiter]\n");
	}
	
	printP (1, "Size of Features:              ". scalar @features. "\n");
	printP (1, "Size of FeaturesList:          ". scalar @featureslist. "\n");
	printP (1, "Size of FeatureParams:         ". scalar @featuresparams. "\n");
	printP (1, "Size of Featureparameterlist:  ". scalar @featuresparameterlist. "\n");
	printP (1, "Size of Featuresinglelineflag: ". scalar @featuressinglelineflag. "\n");
	printP (1, "Size of Featureparamsvalid:    ". scalar @featuresparamsvalid. "\n");

	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @features; $feaiter++) {
		printP (1, "Feature #$feaiter: " . $features[$feaiter] . "\n");
		printP (1, "  with " . scalar @{$featuresparams[$feaiter]} . " Params and " . scalar @{$featureslist[$feaiter]} . " feature lines\n");
		for (my $funiter = 0; $funiter < scalar @{$featureslist[$feaiter]}; $funiter++) {
			printP (1, "   Feature line $funiter: ${$featureslist[$feaiter]}[$funiter]");
		}
		for (my $pariter = 0; $pariter < scalar @{$featuresparams[$feaiter]}; $pariter++) {
			printP (1, "  Param: ${$featuresparams[$feaiter]}[$pariter]\n");
		}
		for (my $pariter = 0; $pariter < scalar @{$featuresparameterlist[$feaiter]}; $pariter++) {
			printP (1, "  Paramlist: ${$featuresparameterlist[$feaiter]}[$pariter]\n");
		}
		printP (1, "featuressinglelineflag: '$featuressinglelineflag[$feaiter]'\n");
		printP (1, "featuresparamsvalid: '$featuresparamsvalid[$feaiter]'\n\n");
	}
	printP (1, "Size of Stored:              ". scalar @stored. "\n");
	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @stored; $feaiter++) {
		printP (1, "Feature #$feaiter: " . $stored[$feaiter] . "\n");
	}
	
	printP (1, "\nPrint genifs!\n");
	printP (1, "Size of GenifID: ". scalar @genifid. "\n");
	printP (1, "Size of genifinequality: ". scalar @genifinequality. "\n");
	printP (1, "Size of GenifFunction: ". scalar @geniffeature. "\n");
	printP (1, "Size of GenifList: ". scalar @geniflist. "\n");
	printP (1, "Size of GenifType: ". scalar @geniftype. "\n");
	
	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @genifinequality; $feaiter++) {
		printP (1, "Genif #$genifid[$feaiter]: \n");
		printP (1, " genifinequality: '$genifinequality[$feaiter]'\n");
		printP (1, " geniffeature:    '$geniffeature[$feaiter]'\n");
		printP (1, " geniftype:       '$geniftype[$feaiter]'\n");
		printP (1, " geniflist:       '". scalar @{$geniflist[$feaiter]} ."'\n");
		for (my $funiter = 0; $funiter < scalar @{$geniflist[$feaiter]}; $funiter++) {
			printP (1, "Genif line $funiter: ${$geniflist[$feaiter]}[$funiter]");
		}
		printP (1, "\n");
	}
	
	printP (1, "\nPrint genloops!\n");
	printP (1, "Size of GenloopID: ". scalar @genloopid. "\n");
	printP (1, "Size of GenloopVar: ". scalar @genloopvar. "\n");
	printP (1, "Size of GenloopStart: ". scalar @genloopstart. "\n");
	printP (1, "Size of GenloopEnd: ". scalar @genloopend. "\n");
	printP (1, "Size of GenloopStride: ". scalar @genloopstride. "\n");
	printP (1, "Size of GenloopValid: ". scalar @genloopvalid. "\n");
	printP (1, "Size of GenloopValue: ". scalar @genloopvalue. "\n");
	printP (1, "Size of GenloopFeature: ". scalar @genloopfeature. "\n");
	printP (1, "Size of GenloopList: ". scalar @genlooplist. "\n");
		
	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @genloopvar; $feaiter++) {
		printP (1, "Genloop #$genloopid[$feaiter]: \n");
		printP (1, " genloopvar:        '$genloopvar[$feaiter]'\n");
		printP (1, " genloopstart:      '$genloopstart[$feaiter]'\n");
		printP (1, " genloopend:        '$genloopend[$feaiter]'\n");
		printP (1, " genloopstride:     '$genloopstride[$feaiter]'\n");
		printP (1, " genloopvalid:      '$genloopvalid[$feaiter]'\n");
		printP (1, " genloopvalue:      '$genloopvalue[$feaiter]'\n");
		printP (1, " genloopfeature:    '$genloopfeature[$feaiter]'\n");
		printP (1, " genlooplist:       '". scalar @{$genlooplist[$feaiter]} ."'\n");
		for (my $funiter = 0; $funiter < scalar @{$genlooplist[$feaiter]}; $funiter++) {
			printP (1, "Genloop line $funiter: '${$genlooplist[$feaiter]}[$funiter]'");
		}
		printP (1, "\n");
	}
	
}
# PARSING PHASE: Top level print all
sub printeverything {
	printP (1, "\n\nPrint everything!\n");
	printParameters();
	printGenerates();
	printFeatures();
	printP (1, "\nEnd Print everything!\n\n");
}

# GENERATION PHASE: Print Final Report
sub printfinalreport {
	my $generated = $generatecounter - scalar @errorlist;
	my $failed = scalar @errorlist;
	printG (1, "Final Report!\n");
	#Generated how many files
	if ($generated == 1) {
		printG (1, " Generated $generated instance programs");
	}
	else {
		printG (1, " Generated $generated instance programs");
	}
	if (scalar @programenum > 0) {
		if ($setcounter == 1) {
			printG (1, " in $setcounter set");
		}
		else {
			printG (1, " in $setcounter sets");
		}
	}
	#Warnings summary
	if ($warningcounter > 0) {
		printG (1, " with $warningcounter warnings\n");
	}
	for (my $i = 0; $i < scalar @warninglist; $i++) {
		printG (1, "  Warning message: $warninglist[$i]");
	}
	printG (1, ".\n");
	#Errors summary
	if ($failed == 1) {
		printG (1, " $failed file failed to generate.\n");
	}
	elsif ($failed != 0) {
		printG (1, " $failed files failed to generate.\n");
	}
	else {
		printG (1, " All files successfully generated.\n");
	}
	for (my $i = 0; $i < scalar @errorlist; $i++) {
		printG (1, "  File Failed: ". $outname1.$errorlist[$i]."_".$errorlist2[$i].$outname2."\n");
	}
	
	if ($timingflag == 1) {
		print "Time in parsing: $timeparse\n";
		print "Time in generating: $timecreate\n";
		print " Time in replacement: $timereplace\n";
		print "Time in printing to file: $timegen\n";
		print "# of constructs: $constructscount\n";
		print " # of dists: $distscount\n";
		print " # of values: $valuescount\n";
		print " # of varlists: $varlistscount\n";
		print " # of variables: $variablescount\n";
		print " # of stored: $storedscount\n";
		print " # of adds: $addscount\n";
		print " # of removes: $removescount\n";
		print " # of genmaths: $genmathscount\n";
		print " # of genasserts: $genassertscount\n";
		print " # of genifs: $genifscount\n";
		print " # of genloops: $genloopscount\n";
		print "# of codes: $codescount\n";
		print "# of total lines: $linescount\n";
		print "# of replaces: $replacecount\n";
		print " # of value replaces: $valreplacecount\n";
		print " # of variable replaces: $varreplacecount\n";
		print " # of varlist replaces: $varlistreplacecount\n";
		print " # of stored replaces: $storedreplacecount\n";
		print " # of feature replaces: $featreplacecount\n";
		print " # of feature arg replaces: $featargreplacecount\n";
		print " # of genif replaces: $genifreplacecount\n";
		print " # of genloop replaces: $genloopreplacecount\n";
		print " # of genloopvar replaces: $genloopvarreplacecount\n";
	}
	
}
sub lineCount {
	my $type = $_[0];
	if ($timingflag == 1) {
		if ($type <= 13) {
			$linescount++;
			if ($type == 12) {
				$codescount++;
			}
			else {
				$constructscount++;
				if ($type == 1) {
					$distscount++;
				}
				elsif ($type == 2) {
					$valuescount++;
				}
				elsif ($type == 3) {
					$varlistscount++;
				}
				elsif ($type == 4) {
					$variablescount++;
				}
				elsif ($type == 5) {
					$storedscount++;
				}
				elsif ($type == 6) {
					$addscount++;
				}
				elsif ($type == 7) {
					$removescount++;
				}
				elsif ($type == 8) {
					$genmathscount++;
				}
				elsif ($type == 9) {
					$genassertscount++;
				}
				elsif ($type == 10) {
					$genifscount++;		
				}
				elsif ($type == 11) {
					$genloopscount++;
				}
			}
		}
		else {
			$replacecount = 0;
			if ($type == 14) {
				$valreplacecount++;
			}
			elsif ($type == 15) {
				$varreplacecount++;
			}
			elsif ($type == 16) {
				$varlistreplacecount++;
			}
			elsif ($type == 17) {
				$storedreplacecount++;
			}
			elsif ($type == 18) {
				$featreplacecount++;
			}
			elsif ($type == 19) {
				$featargreplacecount++;
			}
			elsif ($type == 20) {
				$genifreplacecount++;
			}
			elsif ($type == 21) {
				$genloopreplacecount++;
			}
			elsif ($type == 22) {
				$genloopvarreplacecount++;
			}
		}
	}
}

##?##?## FOR DEBUGGING PRINTING DURING PROCESSING ##?##?##

# Print current parameter set
sub debug_printcurrentparameterset {
	for (my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
		print "$parameters[$pariter]:\n";
		for (my $i = 0; $i < $currentdepth; $i++) {

			printd (2, " $i: ${$parameterscounters[$i]}[$pariter]\n");
		}
		
	}
}
# Print distributions after they are parsed
sub debug_printdistributions {
	printP (1, "Print Distributions!!!\n");
	printP (1, "Size of Distributions: ". scalar @distributions. "\n");
	printP (1, "Size of DistributionCounter: ". scalar @distributionsvalues. "\n");
	printP (1, "Size of DistributionProb: ". scalar @distributionsprob. "\n");
	printP (1, "Size of DistributionReal: ". scalar @distributionsreal. "\n");

	
	for(my $disiter = 0; $disiter < scalar @distributions; $disiter++) {
		printP (1, " Distribution: ". $distributions[$disiter]. "\n");
		printP (1, " Size of DistributionCounter[$disiter]: ". scalar @{$distributionsvalues[$disiter]}. "\n");
		printP (1, " Size of DistributionProb[$disiter]: ". scalar @{$distributionsprob[$disiter]}. "\n");
		for(my $j = 0; $j < scalar @{$distributionsvalues[$disiter]}; $j++) {
			printP (1, "		Range: '" . ${$distributionsvalues[$disiter]}[$j] ."' with Distribution: '" . ${$distributionsprob[$disiter]}[$j] .  "and ${$distributionsprob[$disiter]}[$j] '\n");
			
		}
	}	
}
# Print the status of the varlist and which are allowed
sub debug_printvarlists {
	printG (3, "Begin var avail$_[0]\n");
	for (my $vliter = 0; $vliter < scalar @varlistname; $vliter++) {
		printG (3, "$varlistname[$vliter]: ");
		for (my $variter2 = 0; $variter2 < scalar @{$varlistavailability[$vliter]}; $variter2++) {
			printG (3, "${$varlistavailability[$vliter]}[$variter2]");
		}
		printG (3, "\n");
	}
	printG (3, "End var avail$_[0]\n");
}
# Print the parameters that were passed into a feature
sub debug_printParams {
	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @features; $feaiter++) {
		print "Feature $feaiter $features[$feaiter] with $featuresparamsvalid[$feaiter]\n";
		for (my $pariter = 0; $pariter < $featuresparamsvalid[$feaiter]; $pariter++) {
			print " $pariter ${${$featuresparameterlist[$feaiter]}[$pariter]}[0]\n";
		}
	}
}
# Print the list of currently used Genesis names (names that cannot be reused)
sub debug_printlocalitynames {
	print "BC: $parsebracketcounter ";
	print scalar @{$namesforlocality[$parsebracketcounter+1]};
	for (my $i = 0; $i <= $parsebracketcounter; $i++) {
		for (my $j = 0; $j < scalar @{$namesforlocality[$i]}; $j++) {
		
			print "$i $j = ${$namesforlocality[$i]}[$j]\n";
		}
		
	}
	print "\n";
}

##?##?## VALUE COUNTER MANIPULATION ##?##?##

# GENERATION PHASE: Initiate all global counters to 0
sub setupGlobalCounters {
	for (my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
		my @parametersglobalcounters;
		for (my $disiter = 0; $disiter < scalar @distributions; $disiter++) {
			if ($distributions[$disiter] eq $parametersdistvar[$pariter]) {
				for (my $disiter2 = 0; $disiter2 < scalar @{$distributionsvalues[$disiter]}; $disiter2++) {
					$parametersglobalcounters[$disiter2] = 0;
				}
			}
		}
		$parametersglobalcounter[$pariter] = \@parametersglobalcounters;
	}
}
# GENERATION PHASE: Print the global counters and performs the chi squared test
sub printParamglobalcounters {
	if ($printGlobalcountersflag == 1 || $chisquaredtestflag == 1) {
		print "Global Parameter counters: \n";
		for (my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
			if ($parametersevalflag[$pariter] == 1 && $parametersfullflag[$pariter] == 0 && $parametersrealflag[$pariter] == 0) {
				$parameterschisflag[$pariter] = 1;
				print " $parameters[$pariter] \n";
				for (my $disiter = 0; $disiter < scalar @distributions; $disiter++) {
					if ($distributions[$disiter] eq $parametersdistvar[$pariter]) {
						for (my $disiter2 = 0; $disiter2 < scalar @{$distributionsvalues[$disiter]}; $disiter2++) {
							print "  value ${$distributionsvalues[$disiter]}[$disiter2]: ${$parametersglobalcounter[$pariter]}[$disiter2]\n";
						}
						if ($chisquaredtestflag == 1) {
							#Perform the chi squared test
							chiSquaredTest ($pariter);
						}
					}
				}
				
			}
			else {
				$parameterschisflag[$pariter] = 0;
			}

		}
		#Displays a chi squared test summary
		if ($chisquaredtestflag == 1) {
			print "Test Summary \n";
			my $counter = 0;
			for (my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
				if ($parameterschisflag[$pariter] == 1){
					my $alpha1 = $chisquaredlookupalpha[$confidenceindex[$counter]]/100;
					my $alpha2 = $chisquaredlookupalpha[$confidenceindex[$counter]-1]/100;
					my $differs1 = (100-$chisquaredlookupalpha[$confidenceindex[$counter]-1]);
					my $differs2 = (100-$chisquaredlookupalpha[$confidenceindex[$counter]]);
					
					print " For $parameters[$pariter] | Chi2: $chisquared[$counter] | Alpha: $alpha1-$alpha2 | Differs from declared: $differs1\%-$differs2\%";
					if ($dtestflag == 1) {
					print " | D: $dValue[$counter] ";
					}
					print "\n";
					$counter++;
				}
			}
		}
		
	}
}
# CLEANUP PHASE: Perform the chi-squared test on a single parameter
sub chiSquaredTest {
	my $pariter = $_[0];
	my $sum = 0;
	my @expected;
	my @expectedrounded;
	my @colD;
	my @colE;
	my @colF;
	my $finalchisquaredvalue = 0;
	
	my $actualsum = 0;
	my $expectedsum = 0;
	my $currentDvalue = 0;
	my $Pvalue = 0;
	print "\n";
	print "Chi Squared Test\n";
	print "for $parameters[$pariter] \n";
	
	#Find the distribution that corresponds to the parameter
	for (my $disiter = 0; $disiter < scalar @distributions; $disiter++) {
		if ($distributions[$disiter] eq $parametersdistvar[$pariter]) {
			
			#make sure there is at least 1 sample
			for (my $disiter2 = 0; $disiter2 < scalar @{$distributionsvalues[$disiter]}; $disiter2++) {
				$sum = $sum + ${$parametersglobalcounter[$pariter]}[$disiter2];
			}
			if ($sum > 0) {
			
				#fill out the table
				for (my $disiter2 = 0; $disiter2 < scalar @{$distributionsvalues[$disiter]}; $disiter2++) {
					$expected[scalar @expected] = ${$distributionsprob[$disiter]}[$disiter2]*$sum;
					$expectedrounded[scalar @expectedrounded] = sprintf "%.2f   ", $expected[$disiter2];
					
					$colD[scalar @colD] = ${$parametersglobalcounter[$pariter]}[$disiter2]-$expected[$disiter2];
					$colE[scalar @colE] = $colD[$disiter2]*$colD[$disiter2];
					$colF[scalar @colF] = $colE[$disiter2]/$expected[$disiter2];
				}

				
				print " ColA: Value\n";
				print " ColB: Actual Count\n";
				print " ColC: Expected Count\n";
				print " ColD: ColB-ColC\n";
				print " ColE: ColD Squared\n";
				print " ColF: ColE/ColC\n";
				print "\n";
				print "        A     B      C        D       E      F\n";
				for (my $disiter2 = 0; $disiter2 < scalar @{$distributionsvalues[$disiter]}; $disiter2++) {
					$finalchisquaredvalue = $finalchisquaredvalue + $colF[$disiter2];
				
					print "  value ${$distributionsvalues[$disiter]}[$disiter2]:   ${$parametersglobalcounter[$pariter]}[$disiter2]   ";
					
					
					printf "%.2f   ", $expectedrounded[$disiter2];
					printf "%.2f   ", $colD[$disiter2];
					printf "%.2f   ", $colE[$disiter2];
					printf "%.2f\n", $colF[$disiter2];
				}
				
				#Final Chi Squared value for this parameter
				$chisquared[scalar @chisquared] = sprintf "%.2f", $finalchisquaredvalue;
				print "Final Chi Squared Value: $finalchisquaredvalue\n";
				print "\n";
				print "\n";
				
				#Degrees of freedom to use the lookup table
				my $dof = scalar @{$distributionsvalues[$disiter]} - 1;
				
				#Find what alpha this corresponds to (between)
				my $found = 0;
				for (my $alphavalue = 0; $found == 0 && $alphavalue < scalar @chisquaredlookupalpha - 1; $alphavalue++) {
					if ($chisquaredlookup[$dof-1][$alphavalue] > $chisquared[scalar @chisquared -1]) {
						@confidenceindex[scalar @confidenceindex] = $alphavalue;
						$found = 1;
					}
				
				}
				if ($found == 0) {
					@confidenceindex[scalar @confidenceindex] = scalar @chisquaredlookupalpha - 1;
				}
				my $alpha1 = $chisquaredlookupalpha[$confidenceindex[scalar @confidenceindex-1]]/100;
				my $alpha2 = $chisquaredlookupalpha[$confidenceindex[scalar @confidenceindex-1]-1]/100;
				my $differs1 = (100-$chisquaredlookupalpha[$confidenceindex[scalar @confidenceindex-1]-1]);
				my $differs2 = (100-$chisquaredlookupalpha[$confidenceindex[scalar @confidenceindex-1]]);
				print " The chi-squared value is between an alpha value of $alpha1 and $alpha2. This means this distribution differs from the declared distribution by between $differs1\% and $differs2\%. ";
				if ($alpha1 < 0.05) {
					print "This means it could still be sampled correctly, but there is a high chance of bias affecting the sampling. \n";
				}
				else {
					print "This means there is no reason to believe it was not sampled correctly. An alpha value below 0.05 would mean there is a high chance of biased.\n\n";
				}
				if ($dtestflag == 1) {
					#A different test: Cumulative Distribution Function test 
					#AKA Kolmogorov Smirnov test, partially implemented
					for (my $disiter2 = 0; $disiter2 < scalar @{$distributionsvalues[$disiter]}; $disiter2++) {			
						$actualsum = $actualsum + ${$parametersglobalcounter[$pariter]}[$disiter2];
						$expectedsum = $expectedsum + $expectedrounded[$disiter2];
						if ($expectedsum-$actualsum > $currentDvalue) {
							$currentDvalue = $expectedsum-$actualsum;
						}
						if ($actualsum-$expectedsum > $currentDvalue) {
							$currentDvalue = $actualsum-$expectedsum;
						}
					}
					#normalize /1
					$currentDvalue = $currentDvalue/$sum;
					$dValue[scalar @dValue] = $currentDvalue;
					print "D = $currentDvalue\n\n";
					#my $s = $sum*$currentDvalue^2;
					#$Pvalue = 2*exp(-(2.000071+.331/sqrt($sum)+1.409/$sum)*$s);
					#http://mathworks.com/matlabcentral/newsreader/view_thread/249306
					#print "Arbitrary P: $Pvalue \n\n";
					
					
					 #Calculate the observed test statistic, KSobs.
					 #Find all the possible permutation of the data and calculate KS for each permutation.
					 #The p-value is found by
					 #p-value=# of KS≥KSobstotal # of permutations
					 
					 #unreasonable >_>;
				 }
			 }
			 else {
				print "This value was never sampled. \n";
				$parameterschisflag[$pariter] = 0;
			 }
			
		}
	}

	
	
	
}

##?##?## INITIALIZATION FUNCTIONS ##?##?##

# INIT PHASE: After arguments are handled, determine the comment character
sub determineOutputCommentChar {
	#Makes assumptions on the comment character based on type
	#Reporting wont work if not .c or .s...
	if ($outname2 eq ".c") {
		$reportcharacter = "//";
	}
	elsif ($outname2 eq ".s") {
		$reportcharacter = "#";
	}
	else {
		$headerflag = 0;
	}
}
# INIT PHASE: Handle command line arguments
sub handleArguments {
	#First Argument should be either the filename or a -h
	if (defined $ARGV[0]) {
		#If -h arugment
		if (lc($ARGV[0]) eq '-h') {
			print "Usage: ./genesis.pl [name of genesis file] [options]\n\n";
			print "Usage: ./genesis.pl [name of genesis program] [name of template program] [options]\n\n";

			print "  Possible options: \n";
			for(my $i = 0; $i < scalar @commandlinearguments; $i++  ) {
				print "    " . ${$commandlinearguments[$i]}[0];
			
				my $length = length ${$commandlinearguments[$i]}[0];
			
				for (my $j = 0; $j < 20 - $length; $j++) {
					print " ";
				}
				
				if (${$commandlinearguments[$i]}[4] == 0) {
					print " (can be ${$commandlinearguments[$i]}[5])";
				}
				elsif (${$commandlinearguments[$i]}[4] > 1) {
					print " (default: ${$commandlinearguments[$i]}[5])";
				}
				elsif (${$commandlinearguments[$i]}[4] == -1) {
					print " (can be string*string (ex. Gen*.out))";
				}
				print "\n";
			}
			
			print "\n  Example usage:\n ./genesis.pl ./GenesisPrograms/Testcases/spec-demo.c printParsing=2 printGenerate=2\n";
			
			exit;
		}
		#If filename
		elsif ($ARGV[0] ne '') {
			if (! open (GENPROGFILE, "<:crlf", $ARGV[0])) {
				print "Some sort of open error for Genesis program '$ARGV[0]'. Exiting.";
				exit;
			}
			$filename = $ARGV[0];
		}
		#If there is none, open a default. This shouldnt happen actually.
		else {
			if (! open (GENPROGFILE, "<:crlf", './GenesisPrograms/spec-demo.c')) {
				print "Some sort of open error default for demo Genesis program. Exiting.";
				exit;
			}
			$filename = "./GenesisPrograms/spec-demo.c"
		}
	}
	#If there is none, open a default, one of these wont happen...
	else {
		if (! open (GENPROGFILE, "<:crlf", './GenesisPrograms/spec-demo.c')) {
			print "Some sort of open error for default demo Genesis program. Exiting.";
			exit;
		}
		$filename = "./GenesisPrograms/spec-demo.c"
	}
	
	#$i counts through command line arguments.
	#Starts at 1 if there's no target file. Starts at 2 if there is.
	my $i;
	if (!defined $ARGV[1] || (defined $ARGV[1] && $ARGV[1] =~ /^[\s]*(([\w]+)=([^\)]*))(.*)$/)) {
		$filename2 = "";
		$i = 1;
	}
	else {
		#Opens target code file.
		if (! open (TEMPLATEPROGFILE, "<:crlf", $ARGV[1])) {
			print "Some sort of open error for target code file '$ARGV[1]'. Exiting.";
			exit;
		}
		$filename2 = $ARGV[1];
		$i = 2;
	}

	for (; $i < scalar @ARGV; $i++) {
		setcommandlineargs($ARGV[$i]);
	}
	#Once the files involved is known, determine the comment char
	determineOutputCommentChar();
	
	if ($printintroflag != 0) {
		print " Using Genesis Program: $filename!\n";
		if (defined $filename2) {
			print " Using Target Code File: $filename2!\n";
		}
		print " Using Output directory: $outDir!\n";
		print " Using Instance Program format: $outname1*$outname2!\n\n";
	}
}
# INIT PHASE: Open file for outputting info if needed
sub openOutputFiles {	
	if (defined $dataoutfilename) {
		open($dataoutfile, '>', $dataoutfilename) or die;
	}
	else {
		$dataoutfile = \*STDOUT;
	}
}


##?##?## PHASE1: PARSING THE GENESIS PROGRAM ##?##?##

# PARSING PHASE: check if used line is a keyword, and not to be substituted
sub testNameDoubles {
	#Check for double Genesis name duplication (values, vars, etc)
	my $text = $_[0];
	my $infeature = $_[1];
	my $type = $_[2];
	
	my $error = 0;
	my $errorType;
	
	for (my $j = 0; $j < scalar @{$namesforlocality[$parsebracketcounter+1]}; $j++) {
	
		if ($text eq ${$namesforlocality[$parsebracketcounter+1]}[$j]) {
			printerror ("X", "", "$type '$text'", "$type with name '$text' already exists.");
		}
	}
	
	for (my $j = 0; $j < scalar @globalnames; $j++) {
		if ($text eq $globalnames[$j]) {
			printerror ("X2", "", "$type '$text'", "$type with name '$text' already exists.");
		}
	}
	for (my $j = 0; $j < scalar @programnames; $j++) {
		if ($text eq $programnames[$j]) {
			printerror ("X3", "", "$type '$text'", "$type with name '$text' already exists.");
		}
	}

	${$namesforlocality[$parsebracketcounter+1]}[scalar @{$namesforlocality[$parsebracketcounter+1]}] = $text;

}

sub initiateGlobalSection {
	printP (2, ' Global Section! '. "\n");
				
	if ($globalexistsflag == 1) {
		printerror ("CL", "", "global", "More than one global section.");
	}
	
	$globalexistsflag = 1;
	
	if ($currentfeature ne "") {
		$samplewarningflag = 0;
	}
	$parsebracketcounter++;
	my @temp;
	$namesforlocality[$parsebracketcounter+1] = \@temp;
	$brackettype[$parsebracketcounter] = "global";
	
	$currentbracket[$parsebracketcounter] = "global";
	#$currentfeature = "global";
}

sub initiateProgramSection {
	printP (2, ' Program Section! '. "\n");
				
	if ($programexistsflag == 1) {
		printerror ("BM", "", "program", "More than one program section.");
	}
	
	$programexistsflag = 1;
	
	if ($currentfeature ne "") {
		$samplewarningflag = 0;
	}
	$parsebracketcounter++;
	my @temp;
	$namesforlocality[$parsebracketcounter+1] = \@temp;
	$brackettype[$parsebracketcounter] = "program";
	
	$currentbracket[$parsebracketcounter] = "program";
	#$currentfeature = "program";
}

sub initiateFeatureSection {
	my $info = $_[0];
	printP (2, ' Feature! '. "\n");
				
	if ($currentfeature ne "") {
		$samplewarningflag = 0;
	}
	$parsebracketcounter++;
	my @temp;
	$namesforlocality[$parsebracketcounter+1] = \@temp;
	$brackettype[$parsebracketcounter] = "feature";
	
	if ($info =~ /^(([\w]*\([\w]*\)[\s]*)*)([\w]+)[\s]*(\(.*\))?[\s]*$/) {
						
		my $args = $1;
		my $featurename = $3;
		my $samplevar = $4;
		my @params;
		my @parameterlist;
		setfeatureargs($args);
		
		if (defined $samplevar) {
			$samplevar =~ s/^\(|\)$//g;

			@parameterlist = split(",", $samplevar);
			for (my $i = 0; $i < scalar @parameterlist; $i++) {
				$parameterlist[$i] =~ s/^\s+|\s+$//g;
			}
			for(my $i = 0; $i < scalar @parameterlist; $i++) {
				printP (3, "		 Parameter " . $i . ": '" . $parameterlist[$i] . "'\n");
			}
		}
		testNameDoubles ($featurename, "", "Feature");
		$featuresparameterlist[scalar @featuresparameterlist] = \@params;
		$featuresparams[scalar @featuresparams] = \@parameterlist;
		$featuresparamsvalid[scalar @featuresparamsvalid] = 0;
	
		$currentfeature = $featurename;
		if ($featurename eq "program") {
			printerror ("BN", "", $info, "Feature cannot be named program.");

		}
		if ($featurename eq "global") {
			printerror ("CZ", "", $info, "Feature cannot be named global.");

		}
		$features[scalar @features] = $featurename;
		$featuresvalid[scalar @featuresvalid] = 0;
		printP (3, "   Multiline Feature with params! '$currentfeature'\n");
	}
	else {
		printerror ("N", "", $info, "Invalid feature line.");
	}
	$currentbracket[$parsebracketcounter] = $features[scalar @features -1];
	return (1);
}

sub initiateGenerateSection {
	my $info = $_[0];
	printP (2, " Generate! \n");
				
	if ($info =~ /^[\s]*$/) {
		printerror ("BX", "", "Generate line", "No number to generate!");
	}
	
	my $notouch;
	my $multiline = 0;
	my $generatenum;
	my $distributioninfo;
	if ($info =~ /[\w\s]+ with/) {
		($generatenum, $distributioninfo) = split(" with", $info, 2);
		if ($distributioninfo =~ /^[\s]*$/) {
			$multiline = 1;
		}
		else {
			$multiline = 0;
		}
	}
	else {
		$distributioninfo = "";
		$generatenum = $info;
		$multiline = 0;
	}
	($generatenum, $notouch) = split(" ", $generatenum, 2);
	$generates[scalar @generates] = $generatenum;
	if (!defined $notouch) {
		$gentouch[scalar @gentouch] = 1;
	}
	elsif ($notouch eq "notouch") {
		$gentouch[scalar @gentouch] = 0;
	}
	else {
		printerror ("BE", "", "'$notouch'", "Weird argument for generate.");
	}
	if ($multiline == 0) {
		$gendistribute[scalar @gendistribute] = $distributioninfo;
	}
	else {
		my $gentext; #reading from the generate line
		my $genline = "";
		$gentext = <GENPROGFILE>;
		$gentext =~ s/^\s+|\s+$//g;

		while ($gentext ne "end") {
			if ($genline eq "") {
			$genline = $gentext;
			}
			else {
				$genline = $genline.",".$gentext;
			}
			$gentext = <GENPROGFILE>;
			$gentext =~ s/^\s+|\s+$//g;
		}
		$gendistribute[scalar @gendistribute] = $genline;

	}
	printP (3, "   Create $generatenum with '$gendistribute[scalar @gendistribute-1]'\n");
}

sub addToFeature {
	my $text = $_[0];
	
	#Add to current context
	${$currentgens[$parsebracketcounter]}[scalar @{$currentgens[$parsebracketcounter]}] = "$text\n";
	printP (3, "   Add line to feature. Feature right now: \n");
	for (my $funiter = 0; $funiter < scalar @{$currentgens[$parsebracketcounter]}; $funiter++) {
		printP (3, "   Feature line $funiter: ${$currentgens[$parsebracketcounter]}[$funiter]");
	}
	
	#Update parameter list, if we are still in the global section
	if ($brackettype[$parsebracketcounter] eq "global") { 
		#A parameter exists & the last was enumerate
		# and either
		#	- globalenum is empty, or
		#	- the last entry is not the same as the last parameter
		if ((scalar @parametersfullflag > 0 && $parametersfullflag[scalar @parametersfullflag-1] == 1) 
		&& (scalar @globalenum == 0 || (scalar @globalenum > 0 && $globalenum[scalar @globalenum-1] != scalar @{$currentgens[$parsebracketcounter]} -1 ))) {
			$globalenum[scalar @globalenum] = scalar @{$currentgens[$parsebracketcounter]} -1;
		}
		if ($distlineflag == 1) {
			$globaldist[scalar @globaldist] = scalar @{$currentgens[$parsebracketcounter]} -1;
		}
		if ($reportlineflag == 1) {
			$globalreport[scalar @globalreport] = scalar @{$currentgens[$parsebracketcounter]} -1;
		}
	}
	#Update parameter list, if we are still in the program section
	elsif ($brackettype[$parsebracketcounter] eq "program") { 
		#A parameter exists & the last was enumerate
		# and either
		#	- programenum is empty, or
		#	- the last entry is not the same as the last parameter

		if ((scalar @parametersfullflag > 0 && $parametersfullflag[scalar @parametersfullflag-1] == 1) 
		&& (scalar @programenum == 0 || (scalar @programenum > 0 && $programenum[scalar @programenum-1] != scalar @{$currentgens[$parsebracketcounter]} -1 ))) {
			$programenum[scalar @programenum] = scalar @{$currentgens[$parsebracketcounter]} -1;
		}
		if ($distlineflag == 1) {
			$programdist[scalar @programdist] = scalar @{$currentgens[$parsebracketcounter]} -1;
		}
		if ($reportlineflag == 1) {
			$programreport[scalar @programreport] = scalar @{$currentgens[$parsebracketcounter]} -1;
		}
	}
}

# PARSING PHASE: Parses the genesis line and stores the information
sub parseGenesisLine {
	my $text = $_[0];
	my $keyword;
	my $info;
	
	if (!defined $text) {
		printerror ("AC", "", "End of header", "No end genesis line.");
	}
	$linenumber++;
	#$/ = "\r\n";
	chomp($text);					
	
	$reportlineflag = 0;
	$distlineflag = 0;
	
	($keyword, $info) = split(" ", $text, 2);
	
	if ($text =~ /^([\w,\[\]\s]*)[\s]*=[\s]*[$generegex]+(.*)$/) {
		$equalWithoutGenmathFlag = 1;
	}
	
	# If the first word in the line may be a Genesis Construct
	if (defined $keyword) {
	
		#If it is a Genesis comment
		if (lc($keyword) =~ /^\/\/\//) {
			printP (2, ' Genesis Comment!'. "\n");
			#do nothing
			return $text;
		}
		
		# If we are not in a section yet (global, program or feature, or the generate line, or the end genesis line)
		# Else, throw an error/assume it is a comment
		elsif ($parsebracketcounter < 0) {
			# Allows the following on base level when not in a section:
			# - geninclude
			# - global
			# - program
			# - feature
			# - generate
			# - end genesis
			# - any other line may or may not be ignored
			if (lc($keyword) eq "geninclude") {
				initiateGenincludeStatement($info);
				return $text;
			}
			elsif (lc($keyword) eq "global") {
				initiateGlobalSection();
				return $text;
			}
			elsif (lc($keyword) eq "program") {
				initiateProgramSection();
				return $text;
			}
			elsif (lc($keyword) eq "feature") {
				initiateFeatureSection($info);
				return $text;
			}
			#By design, this is in the bracket < 0 condition, meaning outside of features. Maybe change this later by design.
			elsif (lc($keyword) eq "generate") {
				initiateGenerateSection($info);
				return $text;
			}
			elsif (lc($keyword) eq "end" && defined $info && lc($info) eq "genesis") {
				printP (2, "End genesis! \n");
				$checkoneheaderflag = 1;
				return "";
			}
			else {
				#If flag is off, line is considered an error.
				#If flag is on, line is considered a comment.
				if ($headercommentsflag == 0) {
					printerror ("CK", "", "$text" , "A line in the header is outside the global/program/features section.");
				}
				else {
					printP (2, "Assuming comments! \n");
					return "";
				}
			}
		}
		
		# Allows the following if we are in a section 
		# - value
		# - varlist
		# - stored feature
		# - variable
		# - add
		# - remove
		# - genif
		# - genloop
		# - distribution
		# - genmath
		# - genif
		# - genloop
		# - any code snippet
		# (generate is an error)
		# (end genesis is an error)
		# - end
		elsif ($parsebracketcounter >= 0) {
		
			# Remove leading spaces
			for(my $i = -1; $i <= $parsebracketcounter; $i++) {
				$text =~ s/^(\s)//;
			}
		
			if ($text =~ /^[\s]*end[\s]*genesis[\s]*$/) {
				printerror ("AB", "", "end genesis", "Missing 'end' statement.");
			}
			elsif (lc($keyword) eq "generate") {
				printerror ("AE", "", "generate line", "Generate line inside a feature '$currentfeature', incorrect usage.");
			}
			elsif (lc($keyword) eq "value") {
				return parsevalue($info,$text);
			}
			
			elsif (lc($keyword) eq "varlist") {
				return parsevarlist($info,$text);
			}

			elsif (lc($keyword) eq "variable") {
				return parsevariable($info,$text);
			}
						
			elsif (lc($keyword) eq "feature") {
				return parsestored($info,$text);
			}
			
			elsif (lc($keyword) eq "add") {
				return parseadd($info,$text);
			}
			
			elsif (lc($keyword) eq "remove") {
				return parseremove($info,$text);
			}
			
			elsif (lc($keyword) eq "distribution") {
				return parsedistribution($info,$text);			
			}
			elsif (lc($keyword) eq "genmath") {
				return parsegenmath($info,$text);	
			}
			
			elsif (lc($keyword) eq "genif" || lc($keyword) eq "genelsif" || lc($keyword) eq "genelse") {
				return parsegenif($info, $text, $keyword);
			}
			
			elsif ($text =~ /^[\s]*genloop[\s]*(.*)/) {
				return parsegenloop($info, $text);
			}			
			
			elsif ($text =~ /^[\s]*end[\s]*$/) {
				return parseend ($info, $text);
			}
			else {
				printP (2, " Actual line snippet.\n");
				if ($brackettype[0] eq "global") {
					printwarning ("WK", "", $text, "Code snippet in global section will not be used.");
				}
				
				if ($brackettype[0] eq "program") {
					printwarning ("WL", "", $text, "Code snippet in program section will not be used.");
				}
				
				addToFeature($text);
				
				if ($currentfeature ne "") {
					$samplewarningflag = 0;
				}
				return $text;
			}
		}
		else {
			printerror ("ZZA", "", "$text" , "Something is off with the compiler. Tell Alton.");
		}
		printerror ("ZZB", "", "$text" , "Something is off with the compiler. Tell Alton.");
	}
	#Blank line with no keyword
	else {
		printP (2, " Blank line!\n");
		return $text;
	}
}

sub storeGenif {
	my $type = $_[0];
	my $listlocation = $_[1];
	if ($currentbracket[$parsebracketcounter] =~ /^([$refqregex]+) ([\d]*)[\s]*$/) {
		$genifinequality[scalar @genifinequality] = $1;
		$genifid[scalar @genifid]  = $2;
		$geniffeature[scalar @geniffeature]  = $currentfeature;
		$geniflist[scalar @geniflist] = $listlocation;
		$geniftype[scalar @geniftype] = $type;
		printP (3, "  Var: '" . $1. "'\n");
		printP (3, "  ID: " ."'" . $2 ."'". "\n");
	}
	elsif ($type == 0) {
		printerror ("AW", "", "$currentbracket[$parsebracketcounter]", "Bad genif condition.");
	}
	elsif ($type == 1) {
		printerror ("AX", "", "$currentbracket[$parsebracketcounter]", "Bad genelsif condition.");
	}
	else {
		printerror ("ZZC", "", "storeGenif", "Something is off with the compiler. Tell Alton.");
	}
									
}


# PARSING PHASE: Open geninclude and parse file
sub initiateGenincludeStatement {
	my $filename = $_[0];
	$libfilename = "./LibraryFiles/$filename"; 
	printP (2, ' Geninclude Statement! '. "\n");
	if ($libfilename ne '') {	
		if (! open (LIBRARYFILE, "<:crlf", $libfilename)) {
			print "Some sort of open error for library file '$libfilename'. Exiting.";
			exit;
		}
	}
	else {
		if (! open (LIBRARYFILE, "<:crlf", './LibraryFiles/varlist_c.lib')) {
			print "Some sort of open error for default library file 'varlist_c.lib'. Exiting.";
			exit;
		}
	}
	
	while (my $text = <LIBRARYFILE>) {
		#print "TEXT: '$text'\n";
		
		parseGenesisLine($text);
	}
	
	close(LIBRARYFILE);
}
# PARSING PHASE: Parse and store a value
sub parsevalue {
	my $info = $_[0];
	my $text = $_[1];
	printP (2, ' Value!'. "\n");
	if ($currentfeature ne "") {
		$samplewarningflag = 1;
	}
	if (defined $info) {
		my @valuelist = split(";", $info);
		
		my $bracketflag = 0;
		$noreplacementcounter = 0;
	
		# for every semicolon split
		for(my $priter = 0; $priter < scalar @valuelist; $priter++) {
			my $search = "";
			$noreplacementcounter++;

			$valuelist[$priter] =~ s/^\s+|\s+$//g;
			
			$search = $valuelist[$priter];

			$bracketflag++ while ($valuelist[$priter] =~ /\{/g);
			$bracketflag-- while ($valuelist[$priter] =~ /\}/g);
			

			while ($bracketflag >= 1) {
				$priter++;
				$search = $search . ";" . $valuelist[$priter];
				$bracketflag++ while ($valuelist[$priter] =~ /\{/g);
				$bracketflag-- while ($valuelist[$priter] =~ /\}/g);
			}
					
			my $type = 0;
			my @parameter;
			my $range;
			my $args; 
			if ($search =~ /^([\w,\[\$\{\}\]]*)$/) {
				$type = 1;
				@parameter = split(",", $1);
				$args = "";
			}
			elsif ($search =~ /^([\w,\[\$\{\}\]\s]*)[\s]+sample[\s]+([$equaregex]+)(.*)$/) {
				$type = 2;
				@parameter = split(",", $1);
				$range = $2;
				$args = $3;
			}
			elsif ($search =~ /^([\w,\[\$\{\}\]\s]*)[\s]+sample[\s]+({[-$generegex,\.:;\s]*})(.*)$/) {
				$type = 3;
				@parameter = split(",", $1);
				my $tempdistname = "_a" . scalar @localdistributions;
				$range = $tempdistname;
				$localdistributions[scalar @localdistributions] = $tempdistname . " = " . $2;
				$args = $3;
			}
			elsif ($search =~ /^([\w,\[\$\{\}\]\s]*)[\s]+enumerate[\s]+([$equaregex]*)(.*)$/) {
				#TODO: Enumerate not allowed in features for now
				if ($currentfeature ne "" && $currentfeature ne "program") {
					printerror ("AL", "", "Value $1 with range $2", "Enumerate is invalid while in a feature due to possible infinite nesting. Please leave enumerate outside a feature.");
				}
				$type = 4;
				@parameter = split(",", $1);
				$range = $2;
				$args = $3;
			}
			elsif ($search =~ /^([\w,\[\]\$\{\}\s]*)[\s]*=[\s]*([\'|\"]?[$generegex]+[\'|\"]?)(.*)$/) {
				$type = 5;
				@parameter = split(",", $1);
				$range = $2;
				$args = $3;
			
			}
			#Old method where from is used instead of sample
			elsif($search =~ /^([\w,\[\]\s]*)[\s]+from[\s]+([$equaregex]+)(.*)$/ || $search =~ /^([\w,\[\]\s]*)[\s]+from[\s]+{[-$generegex,:;\s]*}(.*)$/ ) {
				printerror ("BS", "", $text, "Invalid value line. (Maybe change 'from' to 'sample'?)");
			}
			#Else bad error
			else {
				printerror ("A", "", $text, "Invalid value line.");
			}			
			#for every value split
			for(my $pariter = 0; $pariter < scalar @parameter; $pariter++) {
				my $bracketnum;
				my $arrayflag;
				#check if it is a value array
				if ($parameter[$pariter] =~ /^([\w]*)\[([$referegex]*)\]/ ) {
					$bracketnum = $2;
					$parameter[$pariter] = $1;
					$arrayflag = 1;
					if ($bracketnum eq "") {
						printerror ("Q", "", "Value $parameter[$pariter]", "Nothing in the brackets for value array.");
					}
				}
				# else, not an array
				else {
					$arrayflag = 0;
					$bracketnum = -1;
				}
			
				# While cycling through the array (or if it is not an array)
				if ($type==1) {
					$parametersevalflag[scalar @parametersevalflag] = 0;
					$parametersfullflag[scalar @parametersfullflag] = 0;
				}
				
				# Value sampling
				elsif ($type==2) {
					$parametersevalflag[scalar @parametersevalflag] = 1;
					$parametersfullflag[scalar @parametersfullflag] = 0;
				}
				#Value sampling with in-line distributions
				elsif ($type==3) {
					$parametersevalflag[scalar @parametersevalflag] = 1;
					$parametersfullflag[scalar @parametersfullflag] = 0;
				}
				#Value enumerate
				elsif ($type==4) {
				
					$numtoenumerate = 1;
					$parametersevalflag[scalar @parametersevalflag] = 1;
					$parametersfullflag[scalar @parametersfullflag] = 1;
				}
				#Value equals
				elsif ($type==5) {
					$parametersevalflag[scalar @parametersevalflag] = 0;
					$parametersfullflag[scalar @parametersfullflag] = 0;
				}
				#Shouldnt happen, captured by error A. Incase.
				else {
					printerror ("ZZD", "", "'$search'", "Something is off with the compiler. Tell Alton.");
				}
				$parameter[$pariter] =~ s/^\s+|\s+$//g;
				setvalueargs($args);
				if (!defined $range) {
					$parametersdistvar[scalar @parametersdistvar] = "";
					$parametersequalpar[scalar @parametersequalpar] = "";
				}
				else {
					$range =~ s/^\s*|\s*$//g;
					if ($parametersevalflag[scalar @parametersevalflag -1] == 1) {
						$parametersdistvar[scalar @parametersdistvar] = $range;
						$parametersequalpar[scalar @parametersequalpar] = "";
					}
					else {
						$parametersdistvar[scalar @parametersdistvar] = "";
						$parametersequalpar[scalar @parametersequalpar] = $range;
					}
				}
				testNameDoubles ($parameter[$pariter], $currentfeature, "Value");
				$parameters[scalar @parameters] = $parameter[$pariter];
				
				if ($arrayflag == 1) {
					$parametersarrayflag[scalar @parametersarrayflag] = 1;	
					$parametersarraybrackets[scalar @parametersarraybrackets] = $bracketnum;
				}
				else {
					$parametersarrayflag[scalar @parametersarrayflag] = 0;
					$parametersarraybrackets[scalar @parametersarraybrackets] = "";
				}
				
				if ($brackettype[0] eq "global") {
					$parametersglobalflag[scalar @parametersglobalflag] = 1;
				}
				else {
					$parametersglobalflag[scalar @parametersglobalflag] = 0;
				}
				
				$parametersfeature[scalar @parametersfeature] = $currentfeature;
				$parametersrealflag[scalar @parametersrealflag] = 0;
				#$parameterslocalcounter[scalar @parameterslocalcounter] = 0;
				#$parametersstartcounter[scalar @parametersstartcounter] = 0;
				$parametersglobalcounter[scalar @parametersglobalcounter] = 0;
				$parametersnumber[scalar @parametersnumber] = $valuecounter;
				
				printP (3, "   Value " . (scalar @parameters- 1) . ": '" . $parameters[scalar @parameters- 1] . "' from '" . $parametersdistvar[scalar @parameters- 1] . "'\n");
					
			}
			
		}
	}
	else {
		printerror ("BY", "", $text, "Blank value line.");
	}
	#increase counter and return value
	$valuecounter++;
	my $tempvalue = $valuecounter-1;
	my $returnvalue = "value $tempvalue";
	
	addToFeature($returnvalue);
	return $returnvalue;
}
# PARSING PHASE: Parse and store a varlist
sub parsevarlist {
	my $info = $_[0];
	my $text = $_[1];
	printP (2, ' Varlist!'. "\n");
			
	if ($currentfeature ne "") {
		$samplewarningflag = 2;
	}
						

	if (defined $info && $info =~ /^([\w]*)[\s]*\[[\s]*([$referegex]*)\](.*)[\s]*$/) {
		$varlistevalflag[scalar @varlistevalflag] = 1;						
		$varlistname[scalar @varlistname] = $1;
		$varlistarg[scalar @varlistarg] = $2;
		$varlistequalvar[scalar @varlistequalvar] = "";
		$varlistvalidity[scalar @varlistvalidity] = -1;
		setvarlistargs($3);
	}
	#Varlist with from
	
	elsif (defined $info && $info =~ /^([\w]*)[\s]*from[\s]*([$equaregex]*)(.*)[\s]*$/) {
		$varlistevalflag[scalar @varlistevalflag] = 0;					
		$varlistname[scalar @varlistname] = $1;
		$varlistarg[scalar @varlistarg] = "";
		$varlistequalvar[scalar @varlistequalvar] = $2;
		$varlistvalidity[scalar @varlistvalidity] = 0;
		if ($3 =~ /[\S]/) {
			printerror ("BD", "", $text, "Varlists using 'from' should not have any arguments.");
		}
		setvarlistargs("");
	}
	else {
		printerror ("C", "", $text, "Invalid varlist line.");
	}
	$varlistcounter++;
	my $tempvalue = $varlistcounter-1;
	my $returnvalue = "varlist $tempvalue";
	
	addToFeature($returnvalue);
	return $returnvalue;
}
# PARSING PHASE: Parse and store a variable
sub parsevariable {
	my $info = $_[0];
	my $text = $_[1];
	printP (2, ' Variable!'. "\n");
			
	if ($currentfeature ne "") {
		$samplewarningflag = 3;
	}
	
	if (defined $info) {
		my @variable = split(";", $info);
		# for every semicolon split
		for(my $variter = 0; $variter < scalar @variable; $variter++) {
			my @parameter;
			my $range;
			my $args;
			my $type;
			if ($variable[$variter] =~ /^([\w,\s]*)[\s]+from[\s]+([$referegex]+)[\s]*(.*)$/) {
				@parameter = split(",", $1);
				$range = $2;
				$args = $3;
				$type = 1;
				$range =~ s/^\s*|\s*$//g;
			}
			elsif ($variable[$variter] =~ /^([\w,\s]*)[\s]*=[\s]*([$generegex]+)[\s]*(.*)$/) {
				@parameter = split(",", $1);
				$range = $2;
				$args = $3;
				$type = 2;
				$range =~ s/^\s*|\s*$//g;
			}
			else {
				printerror ("D", "", $text, "Invalid variable line.");
			}
			# for every parameter split
			for(my $pariter = 0; $pariter < scalar @parameter; $pariter++) {
				$parameter[$pariter] =~ s/^\s+|\s+$//g;
				if ($type == 1) {
					my $tempargs = $args;
					$variablesevalflag[scalar @variablesevalflag] = 1;
					setvarargs($tempargs);
				}
				elsif($type == 2) {
					my $tempargs = $args;
					$variablesevalflag[scalar @variablesevalflag] = 0;
					setvarargs($args);
				}
				
				testNameDoubles ($parameter[$pariter], $currentfeature, "Var");
				
				$variables[scalar @variables] = $parameter[$pariter];
				$variablesfeature[scalar @variablesfeature] = $currentfeature;
				
				#Sampling
				if ($variablesevalflag[scalar @variablesevalflag -1] == 1) {
					$variablesvarlistvar[scalar @variablesvarlistvar] = $range;
					$variablesequalpar[scalar @variablesequalpar] = $range;
				}
				#Equals
				else {
					$variablesvarlistvar[scalar @variablesvarlistvar] = "";
					
					for(my $variter2 = 0; $variter2 < scalar @variables; $variter2++) {
						if ($range =~ /\$\{$variables[$variter2]\}/) {
							$variablesvarlistvar[scalar @variablesvarlistvar-1] = $variablesvarlistvar[$variter2];
						}
					}
					
					if ($variablesvarlistvar[scalar @variablesvarlistvar-1] eq "") {
						printerror ("BT", "", "$range" , "Not a valid varlist target for a variable.");
					}
					
					$variablesequalpar[scalar @variablesequalpar] = $range;
				}
				
				#Global Flag
				if ($parsebracketcounter == -1) {
					$variablesglobalflag[scalar @variablesglobalflag] = 1;
				}
				else {
					$variablesglobalflag[scalar @variablesglobalflag] = 0;
				}
				
				$variablesnumber[scalar @variablesnumber] = $variablecounter;
	
				printP (3, "  Variable " . (scalar @variables- 1) . ": '". $variables[scalar @variables- 1]. "' from " . $variablesvarlistvar[scalar @variables- 1] . "\n");	
			}

		}
		
	}
	else {
		printerror ("AT", "", $text, "Blank variable line.");
	}
	$variablecounter++;
	my $tempvalue = $variablecounter-1;
	my $returnvalue = "variable $tempvalue";
	
	addToFeature($returnvalue);
	return $returnvalue;
}
# PARSING PHASE: Parse and store a feature instance
sub parsestored {
	my $info = $_[0];
	my $text = $_[1];
	printP (2, ' Stored!'. "\n");
	
	#
	if ($currentfeature ne "") {
		$samplewarningflag = 3;
	}
	if (defined $info) {
		my @storedline = split(";", $info);
		# for every semicolon split
		for(my $variter = 0; $variter < scalar @storedline; $variter++) {
			my @parameter;
			my $range;
			my $args;
			if ($storedline[$variter] =~ /^([\w,\s]*)[\s]+process[\s]+([$referegex]*)[\s]*(.*)$/) {
				@parameter = split(",", $1);
				$range = $2;
				$args = $3;
				$range =~ s/^\s*|\s*$//g;
				# for every feature name split
			}
			else {
				printerror ("CN", "", $text, "Invalid stored line.");
			}
			for(my $pariter = 0; $pariter < scalar @parameter; $pariter++) {
				$parameter[$pariter] =~ s/^\s+|\s+$//g;
				
				testNameDoubles ($parameter[$pariter], $currentfeature, "Stored");
				
				$stored[scalar @stored] = $parameter[$pariter];
				$storedvar[scalar @storedvar] = $range;
				$storedfeature[scalar @storedfeature] = $currentfeature;
				if ($parsebracketcounter == -1) {
					$storedglobalflag[scalar @storedglobalflag] = 1;
				}
				else {
					$storedglobalflag[scalar @storedglobalflag] = 0;
				}
				
				$storednumber[scalar @storednumber] = $storedcounter;
	
				printP (3, "  Stored " . (scalar @stored- 1) . ": '". $stored[scalar @stored- 1]. "'\n");	
			}
		}
	}
	else {
		printerror ("CI", "", $text, "Blank stored line.");
	}
	$storedcounter++;
	my $tempvalue = $storedcounter-1;
	my $returnvalue = "stored $tempvalue";
	
	addToFeature($returnvalue);
	return $returnvalue;
}
# PARSING PHASE: Parse and store a add line
sub parseadd {
	my $info = $_[0];
	my $text = $_[1];
	printP (2, ' AddVariable!'. "\n");
	
	if ($currentfeature ne "") {
		$samplewarningflag = 0;
	}
	if (defined $info) {
		my @valuelist = split(";", $info);
		# for every semicolon split
		for(my $priter = 0; $priter < scalar @valuelist; $priter++) {
		$valuelist[$priter] =~ s/^\s+|\s+$//g;
			my $samplevar;
			my $range;
			if ($valuelist[$priter] =~ /^([\w,\s]*)[\s]+to[\s]+([$referegex]+)[\s]*$/) {
				$samplevar = $1;
				$range = $2;
				$samplevar =~ s/^\s+|\s+$//g;
				$range =~ s/^\s+|\s+$//g;
			}
			else {
				if ($valuelist[$priter] =~ /^([\w,\s]*)[\s]+to[\s]+varlist[\s]+([$referegex]+)[\s]*$/) {
					printerror ("E1", "", $text, "Invalid add line. HINT: varlist keyword is not needed anymore.");
				}
				else {
					printerror ("E", "", $text, "Invalid add line.");
				}
			}
			my @addvariable = split(",", $samplevar);
			# for every Genesis name split
			for(my $variter = 0; $variter < scalar @addvariable; $variter++) {
				$addvariable[$variter] =~ s/^\s+|\s+$//g;
				$addvariables[scalar @addvariables] = $addvariable[$variter];
				$addvariablesfeature[scalar @addvariablesfeature] = $currentfeature;
				$addvariablesvarlistvar[scalar @addvariablesvarlistvar] = $range;
				$addvariablesnumber[scalar @addvariablesnumber] = $addcounter;
				printP (3, "  AddVariable " . (scalar @addvariables- 1) . ": '". $addvariables[scalar @addvariables- 1]. "' to " . $addvariablesvarlistvar[scalar @addvariables- 1] . "\n");	
			}
		}
	}
	else {
		printerror ("E", "", $text, "Invalid addvar line.");
	}
	$addcounter++;
	my $tempvalue = $addcounter-1;
	my $returnvalue = "add $tempvalue";
	
	addToFeature($returnvalue);
	return $returnvalue;
}
# PARSING PHASE: Parse and store a remove line
sub parseremove {
	my $info = $_[0];
	my $text = $_[1];
	printP (2, ' RemVariable!'. "\n");
			
	if ($currentfeature ne "") {
		$samplewarningflag = 0;
	}
	if (defined $info) {
	
		my @valuelist = split(";", $info);
		
		# for every semicolon split
		for(my $priter = 0; $priter < scalar @valuelist; $priter++) {
		$valuelist[$priter] =~ s/^\s+|\s+$//g;
			my $samplevar;
			my $range;
			if ($valuelist[$priter] =~ /^([\w,\s]*)[\s]+from[\s]+([$referegex]+)[\s]*$/) {
				$samplevar = $1;
				$range = $2;
				$samplevar =~ s/^\s+|\s+$//g;
				$range =~ s/^\s+|\s+$//g;
			}
			else {
				if ($valuelist[$priter] =~ /^([\w,\s]*)[\s]+from[\s]+varlist[\s]+([$referegex]+)[\s]*$/) {
					printerror ("F1", "", $text, "Invalid rem line. HINT: varlist keyword is not needed anymore.");
				}
				else {
					printerror ("F", "", $text, "Invalid rem line.");
				}
			}
			my @remvariable = split(",", $samplevar);
			# for every Genesis name split
			for(my $variter = 0; $variter < scalar @remvariable; $variter++) {
				$remvariable[$variter] =~ s/^\s+|\s+$//g;
				$remvariables[scalar @remvariables] = $remvariable[$variter];
				$remvariablesfeature[scalar @remvariablesfeature] = $currentfeature;
				$remvariablesvarlistvar[scalar @remvariablesvarlistvar] = $range;
				$remvariablesnumber[scalar @remvariablesnumber] = $remcounter;
				printP (3, "  remvariable " . (scalar @remvariables- 1) . ": '". $remvariables[scalar @remvariables- 1]. "' to " . $remvariablesvarlistvar[scalar @remvariables- 1] . "\n");	
			}
		}
	}
	else {
		printerror ("F", "", $text, "Invalid remvar line.");
	}
	$remcounter++;
	my $tempvalue = $remcounter-1;
	my $returnvalue = "remove $tempvalue";
	
	addToFeature($returnvalue);
	return $returnvalue;
}

sub parsedistribution {
	my $info = $_[0];
	my $text = $_[1];
	printP (2, " Distribution!\n");
	
	if ($currentfeature ne "") {
		$samplewarningflag = 4;
	}

	$distlineflag = 1;
	$globaldistributions[scalar @globaldistributions] = $info;
	my $returntext = "distribution ". scalar @globaldistributions-1;
	addToFeature($returntext);
	return $returntext;
}

sub parsegenmath {
	my $info = $_[0];
	my $text = $_[1];
	printP (2, " Genmath!\n");
	if ($info =~ /^([$referegex,\s]*)[\s]+sample[\s]+([$equaregex]+)(.*)$/ || $info =~ /^([$referegex,\s]*)[\s]+sample[\s]+{[-$generegex,:;\s]*}(.*)$/ ) {
		$distlineflag = 1;
		$genmathdistvar[scalar @genmathdistvar] = $2;
	}
	addToFeature($text);
	return $text;
}

sub parsegenif {
	my $info = $_[0];
	my $text = $_[1];
	my $keyword = $_[2];
	if ($currentfeature ne "") {
		$samplewarningflag = 0;
	}
	my $iftype = 0;
	my $bracket = $parsebracketcounter;
	if (lc($keyword) eq "genif") {
		printP (2, ' Genif! '. "\n");
		$iftype = 1;
		printP (3, " Add genif to feature. Feature right now: \n");
		if (!defined $info || $info =~ /^[\s]*$/) {
			printerror ("CX", "", "$text", "Genif with no arguments!");
		}
	}
	elsif (lc($keyword) eq "genelsif") {
		printP (2, ' Genelsif! '. "\n");
		$iftype = 2;
		printP (3, " Add genelsif to feature. Feature right now: \n");
		if (!defined $info || $info =~ /^[\s]*$/) {
			printerror ("CY", "", "$text", "Genelse with no arguments!");
		}
	}
	elsif (lc($keyword) eq "genelse") {
		printP (2, ' Genelse! '. "\n");
		$iftype = 3;
		printP (3, " Add genelse to feature. Feature right now: \n");
		if (defined $info && $info =~ /[^\s]/) {
			printerror ("AY", "", "$text", "Genelse should not have a condition.");
		}
		$info = "1";
	}
	else {
		printerror ("ZZE", "", "'$text'", "Something is off with the compiler. Tell Alton.");
	}
	
	if ($brackettype[$parsebracketcounter] ne "genelsif" && $brackettype[$parsebracketcounter] ne "genif") {
		if ($iftype == 2) {
			printerror ("AJ", "", "genelsif", "Genelsif without genif");
		}
		elsif ($iftype == 3) {
			printerror ("AK", "", "genelse", "Genelse without genif");
		}
	}
	
	if ($iftype == 2 || $iftype == 3) {
		
		$bracket = $bracket - 1;

		my @tempfunction;
		for (my $funiter = 0; $funiter < scalar @{$currentgens[$parsebracketcounter]}; $funiter++) {
			$tempfunction[scalar @tempfunction] = ${$currentgens[$parsebracketcounter]}[$funiter];
			printP (3, "Feature line $funiter: '${$currentgens[$parsebracketcounter]}[$funiter]'\n");
		}
		
		@{$currentgens[$parsebracketcounter]}=(); 

		
		if ($brackettype[$parsebracketcounter] eq "genif") {
			printP (3, "  Genif name: '" . $currentbracket[$parsebracketcounter]. "'\n");
			storeGenif(0, \@tempfunction);
		}
		
		elsif ($brackettype[$parsebracketcounter] eq "genelsif") {
			printP (3, "  Genelsif name: '" . $currentbracket[$parsebracketcounter]. "'\n");
			storeGenif(1, \@tempfunction);
		}
		if ($iftype == 2) {
			$brackettype[$parsebracketcounter] = "genelsif";
		}
		if ($iftype == 3) {
			$brackettype[$parsebracketcounter] = "genelse";
		}
	}
	elsif ($iftype == 1) {
		$parsebracketcounter++;
		$brackettype[$parsebracketcounter] = "genif";
	}
				
	my @temp;
	$namesforlocality[$parsebracketcounter+1] = \@temp;
	$currentbracket[$parsebracketcounter] = "$info $genifcounter";		
	${$currentgens[$bracket]}[scalar @{$currentgens[$bracket]}] = "genif $genifcounter\n";
	for (my $funiter = 0; $funiter < scalar @{$currentgens[$bracket]}; $funiter++) {
		printP (3, "   Feature line $funiter: ${$currentgens[$bracket]}[$funiter]");
	}
	$genifcounter++;
	return $text;
}

sub parsegenloop {
	my $info = $_[0];
	my $text = $_[1];
	printP (2, ' Genloop! '. "\n");
	if ($currentfeature ne "") {
		$samplewarningflag = 0;
	}
		
	if (!defined $info || $info =~ /^[\s]*$/) {
		printerror ("BZ", "", "$text", "Genloop with no arguments!");
	}
	elsif ($info =~ /^([\w]+[\s]*:[\s]*[$generegex]+[\s]*:[\s]*[$generegex]+[\s]*(:[\s]*[$generegex]+)?)/){
		$brackettype[$parsebracketcounter+1] = "genloop1";
		$info =~ s/\:\s+|\s+\:/\:/g;
		
	}
	elsif ($info =~ /^([$refqregex]+)/){
		$brackettype[$parsebracketcounter+1] = "genloop2";
	}
	else {
		printerror ("BZ", "", "$text", "Genloop with no arguments!");
	}
	
	${$currentgens[$parsebracketcounter]}[scalar @{$currentgens[$parsebracketcounter]}] = "genloop $info ". $genloopcounter ."\n";
	
	printP (3, " Add genloop to feature. Feature right now: \n");
	for (my $funiter = 0; $funiter < scalar @{$currentgens[$parsebracketcounter]}; $funiter++) {
		printP (3, "   Feature line $funiter: ${$currentgens[$parsebracketcounter]}[$funiter]");
	}
	$parsebracketcounter++;
	my @temp;
	$namesforlocality[$parsebracketcounter+1] = \@temp;
	$currentbracket[$parsebracketcounter] = $info . " " . $genloopcounter;
	$genloopcounter++;
	return $text;
}

sub parseend {
	my $info = $_[0];
	my $text = $_[1];
	#The end of something
	$reportlineflag = 0;
	
	#${$currentgens[$parsebracketcounter]}[(scalar @{$currentgens[$parsebracketcounter]})-1] =~ s/\n$//;
	my @tempfunction;
	if (defined $currentgens[$parsebracketcounter]) {
		for (my $funiter = 0; $funiter < scalar @{$currentgens[$parsebracketcounter]}; $funiter++) {
			$tempfunction[scalar @tempfunction] = ${$currentgens[$parsebracketcounter]}[$funiter];
		}
	}
	
	#End of genloop
	if ($brackettype[$parsebracketcounter] eq "genloop1") {
		printP (2, " End Genloop!\n");
		printP (3, "  Genloop1 name: '" . $currentbracket[$parsebracketcounter]. "'\n");
		my $counter;
		my $id;
		my @tempvalue;
		my $varname;
		my $varstart;
		my $varend;
		my $varstride;
						
		($counter, $id) = split(" ", $currentbracket[$parsebracketcounter], 2);
		($varname, $varstart, $varend, $varstride) = split(":", $counter, 4);
		if (!defined $varstride) {
			$varstride = 1;
		}
		
		$varname =~ s/^\s+|\s+$//g;
		$varstart =~ s/^\s+|\s+$//g;
		$varend =~ s/^\s+|\s+$//g;
		$varstride =~ s/^\s+|\s+$//g;
		
		$genloopvar[scalar @genloopvar] = $varname;
		$genloopstart[scalar @genloopstart]  = $varstart;
		$genloopend[scalar @genloopend]  = $varend;
		$genloopstride[scalar @genloopstride]  = $varstride;
		$genloopinequality[scalar@genloopinequality] = "";
		$genloopid[scalar @genloopid]  = $id;
		$genlooplist[scalar @genlooplist]  = \@tempfunction;
		$genloopvalid[scalar @genloopvalid]  = 0;
		$genloopvalue[scalar @genloopvalue]  = \@tempvalue;
		$genloopfeature[scalar @genloopfeature]  = $currentfeature;
		printP (3, "  Var: '" . $varname. "'\n");
		printP (3, "  Var start: " ."'" . $varstart ."'". "\n");
		printP (3, "  Var end: " ."'" . $varend ."'". "\n");
		printP (3, "  Var stride: " ."'" . $varstride ."'". "\n");
	}
	#End of conditional genloop
	elsif ($brackettype[$parsebracketcounter] eq "genloop2") {
		printP (2, " End Genloop!\n");
		printP (3, "  Genloop2 name: '" . $currentbracket[$parsebracketcounter]. "'\n");
		my $counter;
		my $id;
		($counter, $id) = split(" ", $currentbracket[$parsebracketcounter], 2);
		$genloopvar[scalar @genloopvar] = "";
		$genloopstart[scalar @genloopstart]  = "";
		$genloopend[scalar @genloopend]  = "";
		$genloopstride[scalar @genloopstride]  = "";
		$genloopinequality[scalar@genloopinequality] = $counter;
		$genloopid[scalar @genloopid]  = $id;
		$genlooplist[scalar @genlooplist]  = \@tempfunction;
		$genloopvalid[scalar @genloopvalid]  = 0;
		$genloopvalue[scalar @genloopvalue]  = 0;
		$genloopfeature[scalar @genloopfeature]  = $currentfeature;
	}
	#End of genif
	elsif ($brackettype[$parsebracketcounter] eq "genif") {
		printP (2, " End Genif!\n");
		printP (3, "  Genif name: '" . $currentbracket[$parsebracketcounter]. "'\n");
		storeGenif(0, \@tempfunction);

	}
	#End of genelsif
	elsif ($brackettype[$parsebracketcounter] eq "genelsif") {
		printP (2, " End Genelsif!\n");
		printP (3, "  Genelsif name: '" . $currentbracket[$parsebracketcounter]. "'\n");
		storeGenif(1, \@tempfunction);

	}
	#End of genelse
	elsif ($brackettype[$parsebracketcounter] eq "genelse") {
		printP (2, " End Genelse!\n");
		printP (3, "  Genelse name: '" . $currentbracket[$parsebracketcounter]. "'\n");
		storeGenif(2, \@tempfunction);
	}
	#End of feature
	elsif ($brackettype[$parsebracketcounter] eq "feature") {
	
		if ($samplewarningflag == 1) {
			printwarning ("WB", "", "Value", "Done at end of feature?");
		}
		if ($samplewarningflag == 2) {
			printwarning ("WC", "", "Varlist", "Done at end of feature?");
		}
		if ($samplewarningflag ==  3) {
			printwarning ("WD", "", "Variable", "Done at end of feature?");
		}
		if ($samplewarningflag == 4) {
			printwarning ("WE", "", "Distribution", "Done at end of feature?");
		}
		printP (2, " End Feature!\n");
		my $numberoffeats = scalar @featureslist;
		printP (3, "   Feature $numberoffeats: '" . $currentbracket[$parsebracketcounter]. "'\n");
		$featureslist[scalar @featureslist]  = \@tempfunction;
		$currentfeature = "";
	}
	#End of program section
	elsif ($brackettype[$parsebracketcounter] eq "program") {
		printP (2, " End Program Section!\n");
		for (my $funiter = 0; $funiter < scalar @tempfunction; $funiter++) {
			$programcodelines[$funiter]  = $tempfunction[$funiter];
		}
		
		for (my $j = 0; $j < scalar @{$namesforlocality[$parsebracketcounter+1]}; $j++) {
			$programnames[$j] = ${$namesforlocality[$parsebracketcounter+1]}[$j];
		}
		$currentfeature = "";
	}
	#End of global section
	elsif ($brackettype[$parsebracketcounter] eq "global") {
		printP (2, " End Global Section!\n");
		for (my $funiter = 0; $funiter < scalar @tempfunction; $funiter++) {
			$globalcodelines[$funiter]  = $tempfunction[$funiter];
		}
		
		for (my $j = 0; $j < scalar @{$namesforlocality[$parsebracketcounter+1]}; $j++) {
			$globalnames[$j] = ${$namesforlocality[$parsebracketcounter+1]}[$j];
		}
		$currentfeature = "";
	}
	else {
		printerror ("ZZF", "", "'$text'", "Something is off with the compiler. Tell Alton.");
	}
	@{$currentgens[$parsebracketcounter]}=(); 
	$parsebracketcounter--; 
	return $text;
}
	
# PARSING PHASE: Takes in a line, parses and processes all command line args
sub setcommandlineargs {
	my $text = $_[0];
	while ($text =~ /^[\s]*(([\w]+)=([^\)]*))(.*)$/) {
		my $full = $1;
		my $type = $2;
		my $arg = $3;
		my $rest = $4;
		
		my $implemented = 0;
		for (my $i = 0; $i < scalar @commandlinearguments; $i++) {
			if ($type eq ${$commandlinearguments[$i]}[0]) {
				#Check Duplicates
				if (${$commandlinearguments[$i]}[1] == 1) {
					printerror (${$commandlinearguments[$i]}[2], $text, "${$commandlinearguments[$i]}[0] argument more than once.");
				}
				${$commandlinearguments[$i]}[1] = 1;
				#If there are possible values
				if (${$commandlinearguments[$i]}[4] > 0) {
					for (my $j = 1; $j <= ${$commandlinearguments[$i]}[4]; $j++) {
						if ($arg eq ${$commandlinearguments[$i]}[4+$j]) {
							$commandlinechange{$type}($arg);
							$implemented = 1;
						}		
					}
				}
				#Any string format
				elsif (${$commandlinearguments[$i]}[4] == 0) {
					if ($arg) {
						$commandlinechange{$type}($arg);
						$implemented = 1;
					} 						
				}
				# *.* format
				elsif (${$commandlinearguments[$i]}[4] == -1) {
					if ($arg =~ /^([^\*]*)\*([^\*]*)$/) {
						$commandlinechange{$type}($1, $2);
						$implemented = 1;
					}
					else {
						printerror ("EF", "", $text, "outfile argument value invalid.\n".
						"  Possible argument values:\n".
						"    character string * character string\n".
						"    Ex. Gen*.c\n");
					}
				}
				if ($implemented == 0) {
					my $errormessage = "${$commandlinearguments[$i]}[0] argument value invalid.\n".
					"  Possible argument values:\n";
					my $number = ${$commandlinearguments[$i]}[4];
					if ($number == 0) {
						$number = 1;
					}
					for (my $j = 1; $j <= $number; $j++) {
						$errormessage = $errormessage . "    " . ${$commandlinearguments[$i]}[4+$j] . "\n";
					}
					printerror (${$commandlinearguments[$i]}[3], $text, $errormessage);
				}
			}
		}
		if ($implemented == 0) {
			my $errormessage = "Command line argument invalid.\n".
			"  Possible command line options:\n";
			for(my $j = 0; $j < scalar @commandlinearguments; $j++  ) {
				$errormessage = $errormessage . "    " . ${$commandlinearguments[$j]}[0] . "\n";
			}
			printerror ("EA", "", $text, $errormessage);
		}
		$text = $rest;
	}
	if ($text =~ /[\S]/) {
		printerror ("EB", "", $text, "Command line argument structure invalid.");
	}
}
# PARSING PHASE: Takes in a line, parses and processes all varlist args 
sub setvarlistargs {
	my $text = $_[0];
	$varlistvarname[scalar @varlistvarname] =  $varlistname[scalar @varlistname-1];
	$varlisttype[scalar @varlisttype] = "float";
	$varlistinitvalue[scalar @varlistinitvalue] = "";
	$varlistinitallflag[scalar @varlistinitallflag] = "0";
	$varlistendtouch[scalar @varlistendtouch] = "1";
	
	for (my $i = 0; $i < scalar @varlistarguments; $i++) {
		${$varlistarguments[$i]}[1] = 0;
	}
	
	while ($text =~ /^[\s]*(([\w]+)(\(([^\)]*)\))?)(.*)$/) {
		
		my $argmissingflag = 0;
		my $full = $1;
		my $type = $2;
		my $arg;
		
		if (defined $4 && $4 ne "") {
			$arg = $4;
		}
		else {
			$argmissingflag = 1;
		}
			
		my $rest = $5;
		
		my $implemented = 0;
		for (my $i = 0; $i < scalar @varlistarguments; $i++) {
			if ($type eq ${$varlistarguments[$i]}[0]) {
			#Check Duplicates
				if (${$varlistarguments[$i]}[1] == 1) {
					printerror (${$varlistarguments[$i]}[2], "", $text, "${$varlistarguments[$i]}[0] argument more than once.");
				}
				elsif ($i == 0 && ${$varlistarguments[1]}[1] == 1) {
					printerror (${$varlistarguments[$i]}[2], "", $text, "${$varlistarguments[$i]}[0] argument more than once.");
				}
				elsif ($i == 1 && ${$varlistarguments[0]}[1] == 1) {
					printerror (${$varlistarguments[$i]}[2], "", $text, "${$varlistarguments[$i]}[0] argument more than once.");
				}
				else {
					${$varlistarguments[$i]}[1] = 1;
				}
				if (${$varlistarguments[$i]}[4] > 0) {
					if ($argmissingflag == 1) {
						$varlistchange{$type}(${$varlistarguments[$i]}[5]);
						$implemented = 1;
					}
					else {
						for (my $j = 1; $j <= ${$varlistarguments[$i]}[4]; $j++) {
							if ($arg eq ${$varlistarguments[$i]}[4+$j]) {
								$varlistchange{$type}($arg);
								$implemented = 1;
							}		
						}
					}
				}
				elsif (${$varlistarguments[$i]}[4] == 0) {
					if ($argmissingflag == 1) {
						my $errormessage = "${$varlistarguments[$i]}[0] needs an argument value.\n".
						"  Possible argument values:\n";
						my $number = ${$varlistarguments[$i]}[4];
						if ($number == 0) {
							$number = 1;
						}
						for (my $j = 1; $j <= $number; $j++) {
							$errormessage = $errormessage . "    " . ${$varlistarguments[$i]}[4+$j] . "\n";
						}
						printerror ("CV", "", $text, $errormessage);
						
					}
					#Only accepts charstrings and _
					if ($arg =~ /[\w]+/) {
						$varlistchange{$type}($arg);
						$implemented = 1;
					} 						
				}
				if ($implemented == 0) {
					my $errormessage = "${$varlistarguments[$i]}[0] argument value invalid.\n".
					"  Possible argument values:\n";
					my $number = ${$varlistarguments[$i]}[4];
					if ($number == 0) {
						$number = 1;
					}
					for (my $j = 1; $j <= $number; $j++) {
						$errormessage = $errormessage . "    " . ${$varlistarguments[$i]}[4+$j] . "\n";
					}
					printerror (${$varlistarguments[$i]}[3], "", $text, $errormessage);
				}
			}
		}
		if ($implemented == 0) {
			my $errormessage = "Varlist argument invalid.\n".
			"  Possible Varlist options:\n";
			for(my $j = 0; $j < scalar @varlistarguments; $j++  ) {
				$errormessage = $errormessage . "    " . ${$varlistarguments[$j]}[0] . "\n";
			}
			printerror ("K", "", $text, $errormessage);
		}
		$text = $rest;
	}
	#Now picked up by Error K
	if ($text =~ /[\S]/) {
		printerror ("P", "", $text, "Varlist line argument structure invalid.");
	}
}
# PARSING PHASE: Takes in a line, parses and processes all value args
sub setvalueargs {
	my $text = $_[0];
	
	$parametersreportflag[scalar @parametersreportflag] = 0;
	$parametersnoreplaceflag[scalar @parametersnoreplaceflag] = 0;

	for (my $i = 0; $i < scalar @valuearguments; $i++) {
		${$valuearguments[$i]}[1] = 0;
	}
	
	while ($text =~ /^[\s]*(([\w]+)(\(([^\)]*)\))?)(.*)$/) {
		my $argmissingflag = 0;
		my $full = $1;
		my $type = $2;
		my $arg;
		
		if (defined $4 && $4 ne "") {
			$arg = $4;
		}
		else {
			$argmissingflag = 1;
		}
				
		 
		my $rest = $5;
		
		my $implemented = 0;
		for (my $i = 0; $i < scalar @valuearguments; $i++) {
			if ($type eq ${$valuearguments[$i]}[0]) {
				#Check Duplicates
				if (${$valuearguments[$i]}[1] == 1) {
					printerror (${$valuearguments[$i]}[2], "", $text, "${$valuearguments[$i]}[0] argument more than once.");
				}
				${$valuearguments[$i]}[1] = 1;
				if (${$valuearguments[$i]}[4] > 0) {
					if ($argmissingflag == 1) {
						$valuechange{$type}(${$valuearguments[$i]}[5]);
						$implemented = 1;
					}
					else {
						for (my $j = 1; $j <= ${$valuearguments[$i]}[4]; $j++) {
							if ($arg eq ${$valuearguments[$i]}[4+$j]) {
								$valuechange{$type}($arg);
								$implemented = 1;
							}		
						}
					}
				}
				elsif (${$valuearguments[$i]}[4] == 0) {
					if ($argmissingflag == 1) {
						my $errormessage = "${$valuearguments[$i]}[0] needs an argument value.\n".
						"  Possible argument values:\n";
						my $number = ${$valuearguments[$i]}[4];
						if ($number == 0) {
							$number = 1;
						}
						for (my $j = 1; $j <= $number; $j++) {
							$errormessage = $errormessage . "    " . ${$valuearguments[$i]}[4+$j] . "\n";
						}
						printerror ("CU", "", $text, $errormessage);
						
					}
					if ($arg) {
						$valuechange{$type}($arg);
						$implemented = 1;
					} 						
				}
				if ($implemented == 0) {
					my $errormessage = "${$valuearguments[$i]}[0] argument value invalid.\n".
					"  Possible argument values:\n";
					my $number = ${$valuearguments[$i]}[4];
					if ($number == 0) {
						$number = 1;
					}
					for (my $j = 1; $j <= $number; $j++) {
						$errormessage = $errormessage . "    " . ${$valuearguments[$i]}[4+$j] . "\n";
					}
					printerror (${$valuearguments[$i]}[3], "", $text, $errormessage);
				}
			}
		}
		if ($implemented == 0) {
			my $errormessage = "Value line argument invalid.\n".
			"  Possible value line options:\n";
			for(my $j = 0; $j < scalar @valuearguments; $j++  ) {
				$errormessage = $errormessage . "    " . ${$valuearguments[$j]}[0] . "\n";
			}
			printerror ("Z", "", $text, $errormessage);
		}
		$text = $rest;
	}
	#Now picked up by Error Z
	if ($text =~ /[\S]/) {
		printerror ("AA", "", $text, "Value line argument structure invalid.");
	}
}
# PARSING PHASE: Takes in a line, parses and processes all variable args
sub setvarargs {
	my $text = $_[0];
	
	$variablesreportflag[scalar @variablesreportflag] = 0;
	
	for (my $i = 0; $i < scalar @vararguments; $i++) {
		${$vararguments[$i]}[1] = 0;
	}
	
	while ($text =~ /^[\s]*(([\w]+)(\(([^\)]*)\))?)(.*)$/) {
		my $argmissingflag = 0;

		my $full = $1;
		my $type = $2;
		my $arg;
		if (defined $4 && $4 ne "") {
			$arg = $4;
		}
		else {
			$argmissingflag = 1;
		}
		my $rest = $5;
		
		my $implemented = 0;
		for (my $i = 0; $i < scalar @vararguments; $i++) {
			if ($type eq ${$vararguments[$i]}[0]) {
			#Check Duplicates
				if (${$vararguments[$i]}[1] == 1) {
					printerror (${$vararguments[$i]}[2], "", $text, "${$vararguments[$i]}[0] argument more than once.");
				}
				${$vararguments[$i]}[1] = 1;
				if (${$vararguments[$i]}[4] > 0) {
					if ($argmissingflag == 1) {
						$varchange{$type}(${$vararguments[$i]}[5]);
						$implemented = 1;
					}
					else {
						for (my $j = 1; $j <= ${$vararguments[$i]}[4]; $j++) {
							if ($arg eq ${$vararguments[$i]}[4+$j]) {
								$varchange{$type}($arg);
								$implemented = 1;
							}		
						}
					}
				}
				elsif (${$vararguments[$i]}[4] == 0) {
					if ($argmissingflag == 1) {
						my $errormessage = "${$vararguments[$i]}[0] needs an argument value.\n".
						"  Possible argument values:\n";
						my $number = ${$vararguments[$i]}[4];
						if ($number == 0) {
							$number = 1;
						}
						for (my $j = 1; $j <= $number; $j++) {
							$errormessage = $errormessage . "    " . ${$vararguments[$i]}[4+$j] . "\n";
						}
						printerror ("CW", "", $text, $errormessage);
						
					}
					if ($arg) {
						$varchange{$type}($arg);
						$implemented = 1;
					} 						
				}
				if ($implemented == 0) {
					my $errormessage = "${$vararguments[$i]}[0] argument value invalid.\n".
					"  Possible argument values:\n";
					my $number = ${$vararguments[$i]}[4];
					if ($number == 0) {
						$number = 1;
					}
					for (my $j = 1; $j <= $number; $j++) {
						$errormessage = $errormessage . "    " . ${$vararguments[$i]}[4+$j] . "\n";
					}
					printerror (${$vararguments[$i]}[3], "", $text, $errormessage);
				}
			}
		}
		if ($implemented == 0) {
			my $errormessage = "Variable line argument invalid.\n".
			"  Possible variable line options:\n";
			for(my $j = 0; $j < scalar @vararguments; $j++  ) {
				$errormessage = $errormessage . "    " . ${$vararguments[$j]}[0] . "\n";
			}
			printerror ("BA", "", $text, $errormessage);
		}
		$text = $rest;
	}
	#Now picked up by Error BA
	if ($text =~ /[\S]/) {
		printerror ("BB", "", $text, "Variable line argument structure invalid.");
	}
}
# PARSING PHASE: Takes in a line, parses and processes all feature args
sub setfeatureargs {
	my $text = $_[0];
	
	$featuressinglelineflag[scalar @featuressinglelineflag] = 0;
	
	for (my $i = 0; $i < scalar @featurearguments; $i++) {
		${$featurearguments[$i]}[1] = 0;
	}
	
	while ($text =~ /^[\s]*(([\w]+)(\(([^\)]*)\))?)(.*)$/) {
		my $argmissingflag = 0;
		my $full = $1;
		my $type = $2;
		my $arg;
		
		if (defined $4 && $4 ne "") {
			$arg = $4;
		}
		else {
			$argmissingflag = 1;
		}
		my $rest = $5;
		
		my $implemented = 0;
		for (my $i = 0; $i < scalar @featurearguments; $i++) {
			if ($type eq ${$featurearguments[$i]}[0]) {
			#Check Duplicates
				if (${$featurearguments[$i]}[1] == 1) {
					printerror (${$featurearguments[$i]}[2], "", $text, "${$featurearguments[$i]}[0] argument more than once.");
				}
				${$featurearguments[$i]}[1] = 1;
				if (${$featurearguments[$i]}[4] > 0) {
					if ($argmissingflag == 1) {
						$featurechange{$type}(${$featurearguments[$i]}[5]);
						$implemented = 1;
					}
					else {
						for (my $j = 1; $j <= ${$featurearguments[$i]}[4]; $j++) {
							if ($arg eq ${$featurearguments[$i]}[4+$j]) {
								$featurechange{$type}($arg);
								$implemented = 1;
							}		
						}
					}
				}
				elsif (${$featurearguments[$i]}[4] == 0) {
					if ($argmissingflag == 1) {
						my $errormessage = "${$featurearguments[$i]}[0] needs an argument value.\n".
						"  Possible argument values:\n";
						my $number = ${$featurearguments[$i]}[4];
						if ($number == 0) {
							$number = 1;
						}
						for (my $j = 1; $j <= $number; $j++) {
							$errormessage = $errormessage . "    " . ${$featurearguments[$i]}[4+$j] . "\n";
						}
						printerror ("BO", "", $text, $errormessage);
						
					}
					if ($arg) {
						$featurechange{$type}($arg);
						$implemented = 1;
					} 						
				}
				if ($implemented == 0) {
					my $errormessage = "${$featurearguments[$i]}[0] argument value invalid.\n".
					"  Possible argument values:\n";
					my $number = ${$featurearguments[$i]}[4];
					if ($number == 0) {
						$number = 1;
					}
					for (my $j = 1; $j <= $number; $j++) {
						$errormessage = $errormessage . "    " . ${$featurearguments[$i]}[4+$j] . "\n";
					}
					printerror (${$featurearguments[$i]}[3], "", $text, $errormessage);
				}
			}
		}
		if ($implemented == 0) {
			my $errormessage = "Feature line argument invalid.\n".
			"  Possible feature line options:\n";
			for(my $j = 0; $j < scalar @featurearguments; $j++  ) {
				$errormessage = $errormessage . "    " . ${$featurearguments[$j]}[0] . "\n";
			}
			printerror ("L", "", $text, $errormessage);
		}
		$text = $rest;
	}
	if ($text =~ /[\S]/) {
		#Shouldnt happen, captured by error N. Incase.
		printerror ("ZZG", "", $text, "Feature line argument structure invalid.");
	}
}

##?##?## PHASE2: TOOLBOX FUNCTIONS ##?##?##

# GENERATING PHASE: Returns 1 if number, 2 if string (with spaces), 0 otherwise
sub numbervsstring {
	my $text = $_[0];
	if ($text =~ /$interegex$/) {
		return 1;
	}
	elsif ($text =~ /^[\w\s]*$/) {
		return 2;
	}
	elsif ($text =~ /^[\'|\"](.*)[\'|\"]$/) {
		return 2;
	}
	else {
		return 0;
	}
}
# GENERATING PHASE: Check if the string is even a boolean statement
#Returns 1 if it is a possible boolean statement, 0 if it is not
#Not a perfect test
sub teststringisboolean {
	my $text = $_[0];
	
	if ($text =~ /^[\s]*$/) {
		return 0;
	}
	#Check if there are words separated by a space
	elsif ($text =~ /[\w] [\w]/) {
		return 0;
	}
	elsif ($text =~ /^([$ineqregex]*)$/) {
		return 1;
	}
	return 0;
}
# GENERATING PHASE: Check if the string is even a math statement
#Returns 1 if it is a possible math statement, 0 if it is not
#Not a perfect test
sub teststringismath {
	my $text = $_[0];
	if ($text =~ /^[\s]*$/) {
		return 0;
	}
	elsif ($text =~ /^[$mathregex\d\s\.]*$/) {
		return 1;
	}
	return 0;
}
# GENERATING PHASE: Eval a boolean statement. Returns 1 if true or 0 if false
sub evaluateboolean {
	my $inequality = $_[0];
	my $infeature = $_[1];
	
	#Test adding quotes to words
	#if ($inequality =~ /([A-Za-z]+)/) {
	#	$inequality =~ s/(^|[^\w"])([\w]+)([^\w"]|$)/$1"$2"$3/g;
	#	$inequality =~ s/"eq"/eq/g;
	#	$inequality =~ s/"ne"/ne/g;
	#	$inequality =~ s/"le"/le/g;
	#	$inequality =~ s/"lt"/lt/g;
	#	$inequality =~ s/"ge"/ge/g;
	#	$inequality =~ s/"gt"/gt/g;
	#}
	
	#replace distributions
	#printP (3, "The boolean we are checking is $inequality.\n");
	#If it is a boolean statement
	if (teststringisboolean($inequality) == 1) {
		#Evaluate it, if true, return 1
		if (eval($inequality)) {
			return 1;
		}
	}
	
	#Otherwise return 0
	return 0;
}
# GENERATION PHASE: Throw error if ranges in a dist arent properly defined

sub checkrangeerrors {
	my $dist = $_[0];
	my $start = $_[1];
	my $end = $_[2];
	for (my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
		if ($start =~ /\$\{$parameters[$pariter]\}/) {
			if (!defined ${$parameterscounters[$currentdepth]}[$pariter]) {
				printerror ("BK", "", "Value $start in $dist", "Start value not defined yet.");
			}
			$start = ${$parameterscounters[$currentdepth]}[$pariter];
		}
		if ($end =~ /\$\{$parameters[$pariter]\}/) {
			if (!defined ${$parameterscounters[$currentdepth]}[$pariter]) {
				printerror ("BL", "", "Value $end in $dist", "End value not defined yet.");
			}
			$end = ${$parameterscounters[$currentdepth]}[$pariter];
		}
	}
	
}

sub throwrangeerror {
	my $dist = $_[0];
	my $range = $_[1];
	if ($range =~ /([-]?[$referegex]+)[\s]*:[\s]*([-]?[$referegex]+)/) {
		my $start = $1;
		my $end = $2;
		if ($start =~ /[^$mathregex\s\d]/) {
			printerror ("AU", "", "Value $start from $range in $dist", "Start value not a valid value to sample from.");
		}
		elsif ($end =~ /[^$mathregex\s\d]/) {
			printerror ("AV", "", "Value $end from $range in $dist", "End value not a valid value to sample from.");
		}
		elsif ($end < $start) {
			printerror ("BG", "", "Value $start:$end from $range in $dist", "End is less than start of range.");
		}
	}

	printerror ("ZZH", "", "$dist with $range", "Something is off with the compiler. Tell Alton.");
}
# GENERATION PHASE: if the feature needs to be in a single line
sub fixsingleline {
	my $text = $_[0];
	my $infeature = $_[1];
	
	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @features; $feaiter++) {
		if ($features[$feaiter] eq $infeature && $featuressinglelineflag[$feaiter] == 1) {
			$insingleline[$currentdepth] = 1;
		}
	}
	
	if ($insingleline[$currentdepth] > 0) {
		#remove all enters
		#$text =~ s/^[^\S\n]//;
		$text =~ s/\n[^\S\n]?//g;
	}
	
	return $text;
}

##?##?## PHASE2: SAMPLE LINES ##?##?##

# GENERATION PHASE: Checks if a line has a keyword to process
sub testLineForKeywords {
	my $text = $_[0];
	my $infeature = $_[1];
	if ($timingflag == 1 && $replacestarttime != 0) {
		if ($replaceendtime > $replacestarttime) {
			my $newreplaceendtime = time;
			$timereplace = $timereplace + ($newreplaceendtime - $replaceendtime);
			$replaceendtime = $newreplaceendtime;
		}
		else {
			$replaceendtime = time;
			$timereplace = $timereplace + ($replaceendtime - $replacestarttime);
		}
	}
	# Three slashes /// is a comment in Genesis
	if ($text =~ /^[\s]*\/\/\//){ 
		printP (3, "Comment. Do nothing.\n");
	}
	elsif ($text =~ /^[\s]*distribution/) {
		handleDistributionLine ($text, $infeature);
		lineCount(1);
	}
	elsif ($text =~ /^[\s]*value/) {
		handleValueLine($text, $infeature);
		lineCount(2);
	}
	elsif ($text =~ /^[\s]*varlist/) {
		handleVarlistLine($text, $infeature);
		lineCount(3);
	}
	elsif ($text =~ /^[\s]*variable/) {
		handleVariableLine($text, $infeature);
		lineCount(4);
	}
	elsif ($text =~ /^[\s]*stored/) {
		handleStoredLine($text, $infeature);
		lineCount(5);
	}	
	elsif ($text =~ /^[\s]*add/) {
		handleAddLine($text, $infeature);
		lineCount(6);
	}
	elsif ($text =~ /^[\s]*remove/) {
		handleRemoveLine($text, $infeature);
		lineCount(7);
		
	}
	elsif ($text =~ /^[\s]*genmath/) {
		handleGenmathLine($text, $infeature);
		lineCount(8);
	}

	elsif ($text =~ /^[\s]*genassert[\s]+([$refqregex]+)[\s]*$/) {
		printP (3, "ASSERT!");
		lineCount(9);
		print "$text";
		my $inequality = $1;
		$inequality = replaceGenesisNamesTop($inequality, $infeature, 1);

		if (evaluateboolean($inequality, $infeature)==0) {
			printG (2, "\nAssert Failed! $inequality");
			$badflag = 1;
		}
	}
	elsif ($ignorevertspaceflag == 1 && $text =~ /^[\s]*$/) {
		printP (3, "Do not include this line\n");
	}
	
	else {
		if ($timingflag == 1) {
			if ($replacestarttime == 0 || $replaceendtime > $replacestarttime) {
				$replacestarttime = time;
			}
			else {
				my $newreplacestarttime = time;
				$timereplace = $timereplace + ($newreplacestarttime - $replacestarttime);
				$replacestarttime = $newreplacestarttime;
			}
		}
		return 0;
	}
	if ($timingflag == 1) {
		if ($replacestarttime == 0 || $replaceendtime > $replacestarttime) {
			$replacestarttime = time;
		}
		else {
			my $newreplacestarttime = time;
			$timereplace = $timereplace + ($newreplacestarttime - $replacestarttime);
			$replacestarttime = $newreplacestarttime;
		}
	}
	return 1;
}
# GENERATION PHASE: Find a varlist line and perform the sampling
sub handleVarlistLine {
	my $text = $_[0];
	my $infeature = $_[1];
	my $keyword;
	my $info;
	($keyword, $info) = split(" ", $text, 2);
	$info =~ s/^\s+|\s+$//g;
	#find a searchid. If it is not eval, it equals another varlist and we need that ID. Otherwise, create/use the next ID.
	my $searchvalue;
	if ($varlistevalflag[$info] == 0){
		for (my $vliter2 = 0; $vliter2 < scalar @varlistname; $vliter2++) {
			if ($varlistname[$vliter2] eq $varlistequalvar[$info]) {
				$searchvalue = $vliter2;
				$varlistvarname[$info] = $varlistvarname[$vliter2];
				$varlistarg[$info] = $varlistarg[$vliter2];
			}
		}
		if (!defined $searchvalue) {
			printerror ("DG", "", "$varlistequalvar[$info]", "Varlist source does not exist.");
		}
	}
	else {
		$searchvalue = $info;
	}
	
	my $numberToAdd = replaceGenesisNamesTop($varlistarg[$searchvalue], $infeature, 0);
	
	#create varlist
	if ($numberToAdd =~ /^[\d]*$/) {

		#Add blank varlists to all varlists in the array
		for (my $i = scalar @varlistavailability; $i < $info; $i++) {
			my @varslist;
			$varlistavailability[$info] = \@varslist;
		}
		#add a varlist, initiate it all to 1
		my @varslist;
		for (my $i = 0; $i < $numberToAdd; $i++) {
			$varslist[scalar @varslist] = 1;
		}
		$varlistavailability[$info] = \@varslist;
		$varlistvalidity[$info] = $currentdepth;
	}
	else {
		printerror ("BF", "", "$varlistarg[$searchvalue]", "Value in the brackets not a number.");
	}
}
# GENERATION PHASE: Find a distribution line and call handleDistribution
sub handleDistributionLine {
	my $text = $_[0];
	my $infeature = $_[1];
	my $keyword;
	my $info;
	($keyword, $info) = split(" ", $text, 2);
	$info =~ s/^\s+|\s+$//g;
	handleDistribution($globaldistributions[$info],1, $infeature, 0);
}
# GENERATION PHASE: Find a distribution and add to valid dists
sub handleDistribution {
	my $distline = $_[0];
	my $underscorecheck = $_[1];
	my $infeature = $_[2];
	my $phase = $_[3];
	my $flag = 0;
	
	if ($distline =~ /^[\s]*[\w]*[\s]*=[\s]*\{[$generegex,:;\s]*\}[\s]*$/) {
		my @valuerange;
		my @value;
		my @prob;
		my @real;
		my $samplevar;
		my $range;
		my $distribute;
		($samplevar, $range) = split("=", $distline, 2);
		$samplevar =~ s/^\s+|\s+$//g;
		$range =~ s/^\s*{\s*|\s*}\s*$//g;
		
		#Variable Terminal Reporting
		my $output = adddepthspacing("Dist: $samplevar with range: $range\n");
		printG (3, "$output");
		
		if ($samplevar =~ /^_/) {
			if ($underscorecheck == 1) {
				printerror ("BI", "", $samplevar, "Underscores allowed but cannot be first char.");
			}
		}
		else {
			my $disthasavalflag = 0;
			
			#check if a distribution is a duplicate
			for (my $pariter = 0; $pariter < scalar @distributions; $pariter++) {
				if ($samplevar eq $distributions[$pariter]) {
					printerror ("BP", "", $samplevar, "Distribution used already.");
				}
			}
			
			#check if a distribution is unused
			for (my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
				if ($parametersevalflag[$pariter] == 1) {
					if ($samplevar eq $parametersdistvar[$pariter]) {
						$disthasavalflag = 1;
					}
				}
			}
			
			#check if a distribution is unused
			for (my $pariter = 0; $pariter < scalar @genmathdistvar; $pariter++) {
				if ($samplevar eq $genmathdistvar[$pariter]) {
					$disthasavalflag = 1;
				}
			}
			
			if ($disthasavalflag == 0) {
				printwarning ("WG", "", $samplevar, "Distribution declared but not used.");
			}
		}
		
		#separate values from the distributions
		($range, $distribute) = split(";;", $range, 2);

		my $divide = 1;
		my $real = 0;
		if (defined $distribute) {
			if ($distribute =~ /^real\((.*)\)$/) {
				$real = $1;
				if ($real =~ /([\d])/ && $real >= 0) {
					$divide = 0;
				}
				else {
					printerror ("DZ", "", $distribute, "Real argument invalid.");				
				}
				$distribute = "real";
			}
			elsif ($distribute =~ /^real$/) {
				$divide = 0;
				$real = 2;
			}
		}
		if ($phase == 1) {
			printP (2, "  Dist: '" .$samplevar . "'\n");
		}

		#separate values
		while ($range =~ /^([^,;\{]*|[^,;\{]*\{[^\$\{\}]*\})[,;](.*)$/) {
			my $current = $1;
			$range = $2;
			
			@valuerange[scalar @valuerange] = $current;
		}
		
		@valuerange[scalar @valuerange] = $range;
		
		my $probexistscheck = -1;
		
		my $probabilitysum = 0;

		for(my $i = 0; $i < scalar @valuerange; $i++) {
			$valuerange[$i] =~ s/^\s+|\s+$//g;
			my $distvalue;
			my $probabilityclause;
			my @probability;
			
			my $probabilityseen = 0;
			my $incrementseen = 0;
					
			if ($valuerange[$i] =~ /^((\$\{|[-\"\}$equaregex,:;\.\s])*)(\{[-$generegex,:;\.\%\s]*\})?$/) {
				$distvalue = $1;
				$probabilityclause = $3;
				
			}
				
			elsif ($valuerange[$i] =~ /^([\'|\"]($refqregex\s])*[\'|\"])(\{[-$generegex,:;\.\%\s]*\})?$/) {
				$distvalue = $1;
				$probabilityclause = $3;
			}
			
			else {
				printerror ("M2", "", $valuerange[$i], "Weird distribution value. Right chars, but format may be off.");
			}
		
			#Split if there is a clause
			if (defined $probabilityclause) {
				@probability = split(",", $probabilityclause);
			}
			#If not put a dummy
			else {
				$probability[0] = "";
			}
			
			if (scalar @probability > 2) {
				printerror ("BU", "", $valuerange[$i], "Too many probability arguments.");
			}
			
			my $increment = "+1";
			my $currentprobability = 100/scalar @valuerange;
			
			for(my $j = 0; $j < scalar @probability; $j++) {
				$probability[$j] =~ s/^\s*{\s*|\s*}\s*$//g;
				if (defined $probability[$j] && $probability[$j] =~ /[^$mathregex\d\.\s\%]/) {
					printerror ("BJ", "", $probability[$j], "Probability is non-numeric.");
				}
				#A probability
				if ($probability[$j] =~ /^([\d][^\%]*)[\%]?$/) {				
					my $cleanprob = $1;
					if ($probabilityseen == 1) {
						printerror ("BV", "", $valuerange[$i], "Too many probabilities.");
					}
					$probabilityseen = 1;
					
					if ($probexistscheck == -1 ) {
						$probexistscheck = 1;		
					}
					if (teststringismath($cleanprob)) {
						$currentprobability = eval($cleanprob);
					}
					else {
						printerror ("ZZI", "", "Prob of $cleanprob" , "Something is off with the compiler. Tell Alton.");
					}
					
				}
				#An increment
				elsif ($probability[$j] =~ /^[\.\s$mathregex]/) {
					if ($incrementseen == 1) {
						printerror ("BW", "", $valuerange[$i], "Too many increments.");
					}
					$incrementseen = 1;
					$increment = $probability[$j]; 
				}
			}
			
			$probabilitysum = $probabilitysum + $currentprobability;
			
			if ($probabilityseen == 0 && $probexistscheck == -1) {
				$probexistscheck = 2;
			}
			
			if ($probexistscheck == 2 && $probabilityseen == 1) {
				printerror ("DA", "", $distline, "Inconsistency. Either give probabilities to every entry in this distribution, or use no probabilities at all.");
			}
			if ($probexistscheck == 1 && $probabilityseen == 0) {
				printerror ("DB", "", $distline, "Inconsistency. Either give probabilities to every entry in this distribution, or use no probabilities at all.");
			}
					
			#range with colon
			if ($distvalue =~ /^(.+)[\s]*:[\s]*(.+)$/) {
			
				my $start = $1;
				my $end = $2;
				
				checkrangeerrors($samplevar, $start, $end);
				$start = replaceGenesisNamesTop($start, $infeature, 0);
					
				$end = replaceGenesisNamesTop($end, $infeature, 0);
					
				if (teststringismath($start)) {
					$start = eval($start);
				}
				
				if (teststringismath($end)) {
					$end = eval($end);
				}
					
				#should be numbers
				if (numbervsstring($start)==1 && numbervsstring($end)==1) {
					if ($end < $start) {
						printerror ("J", "", $distline, "Dist range end less than start value.");
					}
					if (defined $distribute && lc($distribute) eq "real") {
						$value[scalar @value] = "$start:$end";
						$prob[scalar @prob] = "real";
						$real[scalar @real] = $real;
					}
					else {
						#add an entry for every value in the range
						for(my $entry = $start; $entry < $end+1;) {
							$value[scalar @value] = $entry;
							if (defined $distribute && lc($distribute) eq "uniform") {
								$prob[scalar @prob] = 100/(scalar @valuerange*($end-$start+1));
								$real[scalar @real] = 0;
							}
							elsif (teststringismath($currentprobability)) {
								$prob[scalar @prob] = eval($currentprobability)/($end-$start+1);
								$real[scalar @real] = 0;
							}
							else {
								#Shouldnt happen, captured by error BJ if userdeclared. Incase.
								printerror ("ZZJ", "", "Prob of $currentprobability" , "Something is off with the compiler. Tell Alton.");
							}
						
							my $math = $entry.$increment;
							
							if (teststringismath($math)) {
								$entry = eval($math);
							}
							else {
								#Shouldnt happen, captured by error BJ if userdeclared. Incase.
								printerror ("ZZK", "", "Prob of $increment" , "Something is off with the compiler. Tell Alton.");
							}
						}
					}
				}
				# Likely an error if the chars are still in
				else {
					throwrangeerror($samplevar, $distvalue);
					#Should not reach this point
					printerror ("ZZL", "", "$distline" , "Something is off with the compiler. Tell Alton.");
				}
			}
			
			#A word or char string, added quotes
			elsif ($distvalue =~ /^([-]?[\"\w]+)$/ || $distvalue =~ /^([\'|\"][$refqregex]+[\'|\"])$/) {
			
				#Replace the names
				$distvalue = replaceGenesisNamesTop($distvalue, $infeature, 0);
			
				$value[scalar @value] = $1;
				if (defined $currentprobability && $currentprobability =~ /^[\d]/) {
					$prob[scalar @prob] = $currentprobability;
					$real[scalar @real] = 0;
				}
				elsif (defined $distribute && lc($distribute) eq "uniform") {
					$prob[scalar @prob] = 100/scalar @valuerange;
					$real[scalar @real] = 0;
				}
				else {
					$prob[scalar @prob] = 100/scalar @valuerange;
					$real[scalar @real] = 0;
				}
			}
			
			#Error if it makes it here
			else {
				if ($distvalue =~ /^([-]?[\d]+)[\s]*-[\s]*([-]?[\d]+)$/ || $distvalue =~ /^([-]?[\w]+)[\s]*-[\s]*([-]?[\w]+)$/) {
					printerror ("M", "", $valuerange[$i], "Quite possibly using the old distribution method. Fix: Change dashes (-) to colons (:).");
				}
				printerror ("M", "", $valuerange[$i], "Weird distribution value. Right chars, but format may be off.");
			}
		}
		
		if (!(($probabilitysum > 0.99 && $probabilitysum < 1.01) || ($probabilitysum > 99 && $probabilitysum < 101))) {
			printerror ("DC", "", "Prob sum of $probabilitysum", "Probabilities not between 99 and 101.");
		}
		
		#Normalize as necessary so probabilities sum up to 1
		if ($divide == 1) {
			my $probsum = 0;
			for(my $i = 0; $i < scalar @prob; $i++) {
				if (teststringismath($prob[$i])) {
					$probsum = $probsum + eval($prob[$i]);
				}
				else {
					#Shouldnt happen, captured by error BJ if userdeclared. Incase.
					printerror ("ZZM", "", "Prob of $prob[$i]" , "Something is off with the compiler. Tell Alton.");
				}
			}
			
			for(my $i = 0; $i < scalar @prob; $i++) {
				if (teststringismath($prob[$i])) {
					$prob[$i] = eval($prob[$i])/$probsum;
				}
				else {
					#Shouldnt happen, captured by error BJ if userdeclared. Incase.
					printerror ("ZZN", "", "Prob of $prob[$i]" , "Something is off with the compiler. Tell Alton.");
				}
			}
		}
		$distributionsvalues[scalar @distributionsvalues] = \@value;
		$distributionsprob[scalar @distributionsprob] = \@prob;
		$distributionsreal[scalar @distributionsreal] = \@real;
		$distributions[scalar @distributions] = $samplevar;
		if ($phase == 1) {
			printP (2, "		For $samplevar:\n");
			for(my $i = 0; $i < scalar @value; $i++) {
				printP (2, "		Range: '" . $value[$i] ."' with Distribution: '". $prob[$i]. "'\n");
			}
		}

	}
	elsif ($distline =~ /^[\s]*$/) {
		#New F warning
		#printwarning ("WF", "", $distline, "Empty Distribution.");
		
	} 
	else {
		printerror ("O", "", $distline, "Weird distribution value. Some char not allowed.");
	}
}
# GENERATION PHASE: Find a value line and perform the sampling
sub handleValueLine {
#Parse
	my $text = $_[0];
	my $infeature = $_[1];
	my $keyword;
	my $info;
	($keyword, $info) = split(" ", $text, 2);
	$info =~ s/^\s+|\s+$//g;
	for(my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
		if ($parametersnumber[$pariter] eq $info) {
			my $samplevar = $parameters[$pariter];
			my $valuenumber = $info;
			$samplevar =~ s/^\s+|\s+$//g;

			my $bracketnum;
			if ($parametersarrayflag[$pariter] == 1) {
				$bracketnum = replaceGenesisNamesTop($parametersarraybrackets[$pariter], $infeature, 0);
				$bracketnum =~ s/^\s+|\s+$//g;
				# The way this is implemented, the square brackets needs a set number, cannot be a Genesis value,  but at this point all genesis values should have been replaced anyway
				if (numbervsstring($bracketnum) != 1) {
					printerror ("R", "", "Value $parameters[$pariter] with num $bracketnum", "Number for value array is invalid.");
				}
				elsif ($parametersarraybrackets[$pariter] ne "") {
					my @valuearray;
					for(my $arriter = 0; $arriter < $bracketnum; $arriter++){
						$valuearray[$arriter] = "";
					}
					${$parameterscounters[$currentdepth]}[$pariter] = \@valuearray;
				}
				#Shouldnt happen, captured by error Q. Incase.
				else {
					printerror ("DP", "", "$parametersarraybrackets[$pariter]", "Nothing in the brackets.");
				}
			}
			# else, not an array
			else {
				$bracketnum = -1;
			}
			#Enumerating
			if ($parametersfullflag[$pariter] == 1) {
				my $defined = 0;
				my $sampledflag = 0;
				for (my $disiter = 0; $disiter < scalar @distributions; $disiter++) {
					if ($distributions[$disiter] eq $parametersdistvar[$pariter]) {
						$defined = 1;
						${$parameterscounters[$currentdepth]}[$pariter] = ${$distributionsvalues[$disiter]}[0]; 
						${$parameterssampled[$currentdepth]}[$pariter] = 1;
						printG (3, "$parameters[$pariter] replace to ${$parameterscounters[$currentdepth]}[$pariter] \n");
						if ($parametersreportflag[$pariter]==1 && $parametersfullflag[$pariter]==1) {
							$valuereportedflag = 1;
							reportvalue($pariter);
						}
						$sampledflag = 1;
						last;
					}
				}
				if ($sampledflag == 0) {
					printerror ("DO", "", "Value '$samplevar' with distribution '$parametersdistvar[$pariter]'", "Dist for this value does not exist for enumerate.");
				}
			}
			#Sampling (as opposed to =)
			elsif ($parametersevalflag[$pariter]==1) {
				#If this is the first value (alone, or with noreplace)
				if ($currentreplace != $parametersnoreplaceflag[$pariter] || $parametersnoreplaceflag[$pariter] == 0) {
					@sampledalready = ();
					$currentreplace = $parametersnoreplaceflag[$pariter];
				}
				my $sampledflag = 0;
				for (my $disiter = 0; $disiter < scalar @distributions; $disiter++) {
					#Found the corresponding distribution
					if ($distributions[$disiter] eq $parametersdistvar[$pariter]) {

						#Value Terminal Reporting
						my $output = adddepthspacing("Value Sampling $parameters[$pariter] = ");
						printG (3, "$output");
						
						#If it is not a real distribution (no real modifier)
						if (${$distributionsprob[$disiter]}[0] ne "real") {
							my $sampledcorrectly = 0;
							my $i = 0;
							for(my $arriter = 0; $arriter < $bracketnum || $bracketnum == -1; $arriter++){
								if ($currentreplace != $parametersnoreplaceflag[$pariter] || $parametersnoreplaceflag[$pariter] == 0) {
									@sampledalready = ();
									$currentreplace = $parametersnoreplaceflag[$pariter];
								}
								$sampledcorrectly = 0;
								while ($sampledcorrectly == 0) {
									#Check if there are not enough values to sample
									if (scalar @sampledalready == scalar @{$distributionsprob[$disiter]}) {
										printerror ("Y", "", "Value $samplevar with distribution $parametersdistvar[$pariter]", "Not enough distribution to sample all without replacement (" . scalar @sampledalready . " vs " . scalar @{$distributionsprob[$disiter]} . ").");
									}
									#calculate a random probability
									my $randomprob = rand();
									my $runningprob = 0;
									#determine where it indexes to
									for ($i = 0; $runningprob < $randomprob; $i++) {
										$runningprob = $runningprob + ${$distributionsprob[$disiter]}[$i];
									}
									
									#See if it's an array
									if ($bracketnum != -1) {
										${${$parameterscounters[$currentdepth]}[$pariter]}[$arriter] = ${$distributionsvalues[$disiter]}[$i - 1];
									}
									else {
										#set the values and say we sampled it
										${$parameterscounters[$currentdepth]}[$pariter] = ${$distributionsvalues[$disiter]}[$i - 1];
									}
									${$parameterssampled[$currentdepth]}[$pariter] = 1;
									$sampledcorrectly = 1;
									#see if it is already sampled (i.e., noreplace)
									#for now, make sure its not an array
									
									if($parametersarrayflag[$pariter] == 0) {
										for (my $j = 0; $j < scalar @sampledalready; $j++) {
										
											if (${$parameterscounters[$currentdepth]}[$pariter] eq $sampledalready[$j]){
												#so it stays in while loop to sample again
												$sampledcorrectly = 0;
											}
										}
									}
									#if it was still sampled correct, add to sampled already list in case of noreplace
									if ($sampledcorrectly == 1) {
										$sampledalready[scalar @sampledalready] = ${$parameterscounters[$currentdepth]}[$pariter];
									}
								}
								#Report the value
								if ($parametersreportflag[$pariter]==1 && $parametersfullflag[$pariter]==0) {
									$valuereportedflag = 1;
									reportvalue($pariter);
								}
								
								#increase global counters
								if ($printGlobalcountersflag == 1 || $chisquaredtestflag == 1) {
									${$parametersglobalcounter[$pariter]}[$i-1]++;
								}
								if ($printlocalcountersflag == 1) {
									if ($currentdepth == 0) {
										#${$parametersstartcounter[$pariter]}[$i-1]++;
									}
									else {
										#${$parameterslocalcounter[$pariter]}[$i-1]++;
									}
								}
								if ($bracketnum == -1) {
									$bracketnum = 0;
								}
							}
						}
						#Real sampling
						else { 
							if (${$distributionsvalues[$disiter]}[0] =~ /([-\d]*):([\d]*)/) {
								my $start = $1;
								my $end = $2;	
								#Just get a random value
								my $result = (rand($end-$start))+$start;
								${$parameterscounters[$currentdepth]}[$pariter] = sprintf "%.".${$distributionsreal[$disiter]}[0]."f", $result;
								
								${$parameterssampled[$currentdepth]}[$pariter] = 1;
							}	
							#Report the value
							if ($parametersreportflag[$pariter]==1) {
								$valuereportedflag = 1;
								reportvalue($pariter);
							}
						}
						#If we make it here, we've sampled it
						printG (3, "${$parameterscounters[$currentdepth]}[$pariter]\n");
						$sampledflag = 1;
					}
				}
				#Should be taken by Error H
				if ($sampledflag == 0) {
					printerror ("H", "", "Value '$samplevar' with distribution '$parametersdistvar[$pariter]'", "Dist for this value does not exist.");
				}
			}
			#No sampling, just initializing
			elsif ($parametersdistvar[$pariter] eq "" && $parametersequalpar[$pariter] eq "") {
				#Initialize but not sample
				${$parameterssampled[$currentdepth]}[$pariter] = 0;
			}
			#=	
			else {
				my $replacetext = $parametersequalpar[$pariter];	
				$replacetext = replaceGenesisNamesTop($replacetext, $infeature, 0);
				
				#Value Terminal Reporting
				my $output = adddepthspacing("Value Sampling $parameters[$pariter] = ");
				printG (3, "$output");
						
				#If math, evaluate
				if (teststringismath($replacetext)) {
					$replacetext = (eval($replacetext));
				}
				#If it is a string of chars, leave it alone
				elsif (numbervsstring($replacetext) == 2) {
				}
				else {
					# Should be captured by distribution checks
					printerror ("DE", "", "$replacetext" , "String has characters. Put it around quotes or fix the reference.");
				}
				
				#store the value
				${$parameterscounters[$currentdepth]}[$pariter] = $replacetext;
				${$parameterssampled[$currentdepth]}[$pariter] = 1;
				printG (3, " ${$parameterscounters[$currentdepth]}[$pariter]\n");
			}
		}
	}
}

# GENERATION PHASE: Find a stored line and perform the processing
sub handleStoredLine {
#Parse
	my $text = $_[0];
	my $infeature = $_[1];
	my $keyword;
	my $info;
	($keyword, $info) = split(" ", $text, 2);
	$info =~ s/^\s+|\s+$//g;
	for(my $pariter = 0; $pariter < scalar @stored; $pariter++) {
		if ($storednumber[$pariter] eq $info) {
			my $valuenumber = $info;
			
			for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @features; $feaiter++) {
				if ($features[$feaiter] eq $storedvar[$pariter]) {
					my @tempfunction;
					for (my $funiter = 0; $funiter < scalar @{$featureslist[$feaiter]}; $funiter++) {
						my $text = ${$featureslist[$feaiter]}[$funiter];						
						#Process the feature
						if (!testLineForKeywords($text, $features[$feaiter])) {	
							lineCount(12);
							$tempfunction[scalar @tempfunction] = searchForReferences($text, $features[$feaiter]);
						}				
					}
					${$storedsampled[$currentdepth]}[$feaiter] = 1;
					$storedprocessed[$pariter]  = \@tempfunction;
					for (my $funiter = 0; $funiter < scalar @tempfunction; $funiter++) {
						printP (3, "   Feature line $funiter: $tempfunction[$funiter]");
					}
				}
			}
		
		}
	}
}
# GENERATION PHASE: Find a genmath line and perform the action
sub handleGenmathLine {
#Parse
	my $text = $_[0];
	my $infeature = $_[1];
	
	my $keyword;
	my $wholestring;
	
	my $samplevar;
	my $replacetext;
	
	my $bracketnum;
	
	$text = replaceGenesisNamesTop($text, $infeature, 0);

	
	($keyword, $wholestring) = split(" ", $text, 2);

	$wholestring =~ s/^\s+|\s+$//g;
	#Added a negative sign
	
	if ($wholestring =~  /^([\w\[\]]*)[\s]*=[\s]*([\'|\"]?[\$\(\w\-][$generegex\s\"\'\.]*)$/) {
		$samplevar = $1;
		$replacetext = $2;

		if ($samplevar =~ /^([\w]*)\[([\w]*)\]/ ) {
			$samplevar = $1;
			$bracketnum = $2;
		}
		else {
			$bracketnum = -1;
		}
		
		#Replace values in the RHS
		$replacetext = replaceGenesisNamesTop($replacetext, $infeature, 0);
		
		#else, only do it if its mathable. no chars allowed!
		if (teststringismath($replacetext)) {
			$replacetext = (eval($replacetext));
		}
		else {
			# assuming just characters are okay...
			if ($replacetext =~ /^[\w]*$/) {
			}
			#quotes are okay too
			elsif ($replacetext =~ /^[\'|\"](.*)[\'|\"]$/) {
				$replacetext = $1;
			}
			#so stuff like "blab+boo" are invalid
			else {
				printerror ("V", "", "RHS of expression '$replacetext'", "RHS or expression not fully evaluated.");
			}
		}
		
		#Replace the left hand side parameter
		my $sampled = 0;
		for (my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
			if ($parametersfeature[$pariter] eq $infeature || $parametersfeature[$pariter] eq "") {
				if ($samplevar eq $parameters[$pariter]) {
					my $tempdepth = $currentdepth;
					# sampled at 1, 0 are every step above
					#ex "" "" 1 0 0 0
					while ($tempdepth >= 0 && ${$parameterssampled[$tempdepth]}[$pariter] ne "") {
						if ($bracketnum != -1) {
							${${$parameterscounters[$tempdepth]}[$pariter]}[$bracketnum] = $replacetext;
						}
						else {
							${$parameterscounters[$tempdepth]}[$pariter] = $replacetext;
						}
						${$parameterssampled[$tempdepth]}[$pariter] = 0;

						$tempdepth--;
					}
					if ($bracketnum != -1) {
						${${$parameterscounters[$tempdepth+1]}[$pariter]}[$bracketnum] = $replacetext;
					}
					else {
						${$parameterscounters[$tempdepth+1]}[$pariter] = $replacetext;

					}
					${$parameterssampled[$tempdepth+1]}[$pariter] = 1;
					$sampled = 1;
				}
			}
		}
		for (my $loopiter = 0; $loopiter < scalar @genloopvar; $loopiter++) {
			if ($genloopfeature[$loopiter] eq $infeature) {
				if ($genloopvalid[$loopiter] >= 1) {
					if ($samplevar eq $genloopvar[$loopiter]) {
						${$genloopvalue[$loopiter]}[$genloopvalid[$loopiter]-1] = $replacetext;
						$sampled = 1;
					}
				}
			}			
		}
		if ($sampled == 0) {
			printerror ("W", "", "Value $samplevar", "LHS does not exist to genmath.");
		}
		
	}
	
	elsif($wholestring =~ /^([$referegex,\s]*)[\s]+sample[\s]+([$equaregex]+)(.*)$/ || $wholestring =~ /^([$referegex,\s]*)[\s]+sample[\s]+{[-$generegex,:;\s]*}(.*)$/ ) {
	
		my $range;
		my $args; 
		# Value sampling
		if ($wholestring =~ /^([\w,$referegex\s]*)[\s]+sample[\s]+([$equaregex]+)(.*)$/) {
			$samplevar = $1;
			$range = $2;
			$args = $3;
		}
		#Value sampling with in-line distributions
		elsif ($wholestring =~ /^([\w,$referegex\s]*)[\s]+sample[\s]+({[-$generegex,:;\s]*})(.*)$/) {
			$samplevar = $1;
			
			my $tempdistname = "_a" . scalar @localdistributions;
			$range = $tempdistname;
			my $tempdist = $tempdistname . " = " . $2;
			$localdistributions[scalar @localdistributions] = $tempdist;
			handleDistribution($tempdist, 0, "", 0);
			$args = $3;
		}
		
		if ($samplevar =~ /^([\w]*)\[([\w]*)\]/ ) {
			$samplevar = $1;
			$bracketnum = $2;
		}
		else {
			$bracketnum = -1;
		}
		
		#Replace the left hand side parameter
		my $sampled = 0;
		for (my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
			if ($parametersfeature[$pariter] eq $infeature || $parametersfeature[$pariter] eq "") {
				if ($samplevar eq $parameters[$pariter]) {
				
					#If this is the first value (alone, or with noreplace)
					if ($currentreplace != $parametersnoreplaceflag[$pariter] || $parametersnoreplaceflag[$pariter] == 0) {
						@sampledalready = ();
						$currentreplace = $parametersnoreplaceflag[$pariter];
					}
				
					#Figure out value, put in replace text. Copied for now.
					my $sampledflag = 0;
					for (my $disiter = 0; $disiter < scalar @distributions; $disiter++) {
						#Found the corresponding distribution
						if ($distributions[$disiter] eq $range) {

							#Value Terminal Reporting
							my $output = adddepthspacing("Value Sampling $parameters[$pariter] = ");
							printG (3, "$output");
							
							#If it is not real
							if (${$distributionsprob[$disiter]}[0] ne "real") {
								my $sampledcorrectly = 0;
								my $i = 0;
								while ($sampledcorrectly == 0) {
									#Check if there are not enough values to sample
									if (scalar @sampledalready == scalar @{$distributionsprob[$disiter]}) {
										printerror ("Y", "", "Value $samplevar with distribution $range", "Not enough distribution to sample all without replacement (" . scalar @sampledalready . "sampled already vs " . scalar @{$distributionsprob[$disiter]} . "in dist).");
									}
									#calculate a random probability
									my $randomprob = rand();
									my $runningprob = 0;
									#determine where it indexes to
									for ($i = 0; $runningprob < $randomprob; $i++) {
										$runningprob = $runningprob + ${$distributionsprob[$disiter]}[$i];
									}
									
									$replacetext = ${$distributionsvalues[$disiter]}[$i - 1];
									${$parameterssampled[$currentdepth]}[$pariter] = 1;
									$sampledcorrectly = 1;
									
									#see if it is already sampled (i.e., noreplace)
									for (my $j = 0; $j < scalar @sampledalready; $j++) {
										if ($replacetext eq $sampledalready[$j]){
											#so it stays in while loop to sample again
											$sampledcorrectly = 0;
										}
									}
									#if it was still sampled correct, add to sampled already list in case of noreplace
									if ($sampledcorrectly == 1) {
										$sampledalready[scalar @sampledalready] = $replacetext;
									}
								}
								
								#Report the value
								if ($parametersreportflag[$pariter]==1 && $parametersfullflag[$pariter]==0) {
									$valuereportedflag = 1;
									reportvalue($pariter);
								}
								
								#increase global counters
								if ($printGlobalcountersflag == 1 || $chisquaredtestflag == 1) {
									${$parametersglobalcounter[$pariter]}[$i-1]++;
								}
								if ($printlocalcountersflag == 1) {
									if ($currentdepth == 0) {
										#${$parametersstartcounter[$pariter]}[$i-1]++;
									}
									else {
										#${$parameterslocalcounter[$pariter]}[$i-1]++;
									}
								}
							
							}
							#Real sampling
							else { 
								if (${$distributionsvalues[$disiter]}[0] =~ /([-\d]*):([\d]*)/) {
									my $start = $1;
									my $end = $2;	
									#Just get a random value
									$replacetext = (rand($end-$start))+$start;
									${$parameterssampled[$currentdepth]}[$pariter] = 1;
								}	
								#Report the value
								if ($parametersreportflag[$pariter]==1) {
									$valuereportedflag = 1;
									reportvalue($pariter);
								}
							}
							#If we make it here, we've sampled it
							printG (3, "$replacetext\n");
							$sampledflag = 1;
						}
					}
					#Should be taken by Error H
					if ($sampledflag == 0) {
						printerror ("DN", "", "Value '$samplevar' with distribution '$range'", "Distribution in genmath statement does not exist.");
					}				
							
				
					#Replacement goes here
					my $tempdepth = $currentdepth;
					while ($tempdepth >= 0 && ${$parameterssampled[$tempdepth]}[$pariter] ne "") {
					
						#See if it's an array
						if ($bracketnum != -1) {
						
							${${$parameterscounters[$currentdepth]}[$pariter]}[$bracketnum] = $replacetext;
						}
						else {
							${$parameterscounters[$tempdepth]}[$pariter] = $replacetext;
						}
						$tempdepth--;
					}
					$sampled = 1;
				}
			}
		}
		if ($sampled == 0) {
			printerror ("DM", "", "Value '$samplevar' with distribution '$range'", "The LHS value does not exist.");
		}
	}
	else {
		printerror ("U", "", "Value '$wholestring'", "Genmath string not valid.");
	}
}
# GENERATION PHASE: Find a variable line and perform the sampling
sub handleVariableLine {
	my $text = $_[0];
	my $infeature = $_[1];
	my $keyword;
	my $info;
	($keyword, $info) = split(" ", $text, 2);
	$info =~ s/^\s+|\s+$//g;
	for(my $variter = 0; $variter < scalar @variables; $variter++) {
		if ($variablesnumber[$variter] eq $info) {		
			my $varnametouse;
			#If taken from varlist
			if ($variablesevalflag[$variter]==1) {
				my $varlisttouse = replaceGenesisNamesTop($variablesvarlistvar[$variter], $infeature, 0);
				my $sampled = 0;
				for (my $vliter = 0; $vliter < scalar @varlistname; $vliter++) {
				
					if ($varlistname[$vliter] eq $varlisttouse) {
					
						if ($varlistvalidity[$vliter] == -1) {
							printerror ("CM", "", $varlistname[$vliter], "Varlist was not initiated yet.");
						}
						$varnametouse = $varlisttouse;
						${$variablescounters[$currentdepth]}[$variter] = int(rand(scalar @{$varlistavailability[$vliter]}))+1;
						#test empty, if empty, print warning
						my $isempty = 1;
						for (my $i = 0; $i < scalar @{$varlistavailability[$vliter]}; $i++) {
						
							if (${$varlistavailability[$vliter]}[$i] == 1) {
								$isempty = 0;
							}
						}
						#If it is not empty, then sample until one that is available is sampled
						if ($isempty == 0) {
							while (${$varlistavailability[$vliter]}[${$variablescounters[$currentdepth]}[$variter]-1] == 0) {
								${$variablescounters[$currentdepth]}[$variter] = int(rand(scalar @{$varlistavailability[$vliter]}))+1;
							}
						}
						else {
							#Error replaced with a warning for empty varlists
							printwarning ("WDD", "", "'$variables[$variter]' from $varlistname[$vliter]", "Sampling from an Empty Varlist.");
							$badflag = 2;
						}
						$sampled = 1;
						
						#Variable Terminal Reporting
						my $output = adddepthspacing("(Varlist of " . scalar @{$varlistavailability[$vliter]} .") Var Sampling $variables[$variter] = $varlistvarname[$vliter]${$variablescounters[$currentdepth]}[$variter] \n");
						printG (3, "$output");

					}
				}
				if ($sampled == 0) {
					printerror ("I", "", "Variable $variables[$variter] with distribution '$variablesvarlistvar[$variter]'", "Varlist for this variable does not exist.");
				}
			}
			#If taken from another value
			else {
			
				${$variablescounters[$currentdepth]}[$variter] = $variablesequalpar[$variter];
						
				for (my $variter2 = 0; $variter2 < scalar @variables; $variter2++) {
					if (${$variablescounters[$currentdepth]}[$variter] =~ /\$\{$variables[$variter2]\}/) {
						#Use their varname and their value
						$varnametouse = $variablesvarlistvar[$variter];
						${$variablescounters[$currentdepth]}[$variter] =~ s/\$\{$variables[$variter2]\}/${$variablescounters[$currentdepth]}[$variter2]/;
					}
				}
				
				if (teststringismath(${$variablescounters[$currentdepth]}[$variter])) {
					${$variablescounters[$currentdepth]}[$variter] = eval(${$variablescounters[$currentdepth]}[$variter]);
				}
				#Should be captured by Error BT.
				else {
					printerror ("ZZO", "", "$variablesequalpar[$variter]" , "Not a valid varstring math result.");
				}
				
				#Make sure the variable after math is in the varlist
				for (my $vliter = 0; $vliter < scalar @varlistname; $vliter++) {
					if ($varlistname[$vliter] eq $variablesvarlistvar[$variter]) {
						my $maxvalue = scalar @{$varlistavailability[$vliter]};
						my $value = ${$variablescounters[$currentdepth]}[$variter];
						${$variablescounters[$currentdepth]}[$variter] = ((eval($value)-1)%$maxvalue)+1;
					}
				}
			}
			#Report it
			if ($variablesreportflag[$variter]==1) {
				$valuereportedflag = 1;
				reportvariable($variter, $varnametouse);
			}
			
		}
	}

}
# GENERATION PHASE: Find a add line and add variables to varlists
sub handleAddLine {
	printG (3, ' AddVariable!'. "\n");
	my $text = $_[0];
	my $infeature = $_[1];
	my $keyword;
	my $info;
	($keyword, $info) = split(" ", $text, 2);
	$info =~ s/^\s+|\s+$//g;
	for(my $additer = 0; $additer < scalar @addvariables; $additer++) {
		if ( $addvariablesnumber[$additer] eq $info) {
			my $toaddvar;
			my $toadddist;
			
			my $varlisttouse = replaceGenesisNamesTop($addvariablesvarlistvar[$additer], $infeature, 0);
			
			#Add All
			if ($addvariables[$additer] eq "all") {
				for (my $vliter = 0; $vliter < scalar @varlistname; $vliter++) {
					if ($varlisttouse eq $varlistname[$vliter]) {
						
						if ($varlistvalidity[$vliter] == -1) {
							printerror ("CS", "", $varlistname[$vliter], "Varlist was not initiated yet for add all.");
						}
					
						for (my $i = 0; $i < scalar @{$varlistavailability[$vliter]}; $i++) {
							${$varlistavailability[$vliter]}[$i] = 1;
							printG (3, " adding all to $varlisttouse\n");
						}
					}
				}
			}
			#Otherwise add 1
			else {
				#Add a number
				if ($addvariables[$additer] =~ /^[0-9]+$/) {
					$toaddvar = $addvariables[$additer]-1;
					$toadddist = $addvariables[$additer];
					printG (3, " adding $addvariables[$additer] to $varlisttouse\n");
				}
				#Add a value
				else {
					for (my $variter = 0; $variter < scalar @variables; $variter++) {
						if ($addvariables[$additer] eq $variables[$variter] && ($variablesfeature[$variter] eq $infeature || $variablesfeature[$variter] eq "")) {
						
							$toaddvar = ${$variablescounters[$currentdepth]}[$variter]-1;
							$toadddist = ${$variablescounters[$currentdepth]}[$variter];
							printG (3, " adding $variables[$variter] 's ${$variablescounters[$currentdepth]}[$variter] to $varlisttouse\n");
		
						}
					}
					for (my $variter = 0; $variter < scalar @parameters; $variter++) {
						if ($addvariables[$additer] eq $parameters[$variter] && ($parametersfeature[$variter] eq $infeature || $parametersfeature[$variter] eq "")) {
							$toadddist = ${$parameterscounters[$currentdepth]}[$variter];
							$toaddvar = ${$parameterscounters[$currentdepth]}[$variter];
							printG (3, " adding $parameters[$variter] 's ${$parameterscounters[$currentdepth]}[$variter] to $varlisttouse\n");
				
						}
					}
					for (my $loopiter = 0; $loopiter < scalar @genloopvar; $loopiter++) {
						if ($genloopfeature[$loopiter] eq $infeature) {
							if ($addvariables[$additer] eq $genloopvar[$loopiter] && $genloopvalid[$loopiter] >= 1) {
								$toaddvar = ${$genloopvalue[$loopiter]}[$genloopvalid[$loopiter]-1]-1;
								$toaddvar = ${$genloopvalue[$loopiter]}[$genloopvalid[$loopiter]-1];
								print (2, " adding $genloopvar[$loopiter] 's $toaddvar to $varlisttouse\n");
							}
						}
					}
				}
			
				#The actual add to the availability list
				for (my $vliter = 0; $vliter < scalar @varlistname; $vliter++) {
					if ($varlisttouse eq $varlistname[$vliter]) {
						if ($varlistvalidity[$vliter] == -1) {
							printerror ("CQ", "", $varlistname[$vliter], "Varlist was not initiated yet for add.");
						}
					
						${$varlistavailability[$vliter]}[$toaddvar] = 1;
						printG (3, "  add successful!");
					}
				}
				
				#The actual add to the distribution
				for (my $disiter = 0; $disiter < scalar @distributions; $disiter++) {
					if ($distributions[$disiter] eq $varlisttouse) {
						if (${$distributionsprob[$disiter]}[0] ne "real") {
		
							my $size = scalar @{$distributionsprob[$disiter]};
							my $total = 1 + 1/$size;
							
							#Add new value
							${$distributionsvalues[$disiter]}[scalar @{$distributionsvalues[$disiter]}] = $toadddist;
							
							#add distributions
							${$distributionsprob[$disiter]}[scalar @{$distributionsprob[$disiter]}] = 1/$size;
							${$distributionsreal[$disiter]}[scalar @{$distributionsreal[$disiter]}] = 0;
							
							for (my $i = 0; $i < scalar @{$distributionsprob[$disiter]}; $i++) {
								${$distributionsprob[$disiter]}[$i] = ${$distributionsprob[$disiter]}[$i]/$total;
							}
							
							printG (3, " adding $addvariables[$additer] to $distributions[$disiter]\n");
							
						}
						else { 
							printerror ("BQ", "", $varlisttouse, "Add cannot work with real values.");
						}
					}
				}
			}
		}
	}
}
# GENERATION PHASE: Find a add line and remove variables from varlists
sub handleRemoveLine {
	#Remove variables from varlists
	printG (3, ' RemVariable!'. "\n");
	my $text = $_[0];
	my $infeature = $_[1];
	my $keyword;
	my $info;
	($keyword, $info) = split(" ", $text, 2);
	$info =~ s/^\s+|\s+$//g;
	for(my $remiter = 0; $remiter < scalar @remvariables; $remiter++) {
		if ($remvariablesnumber[$remiter] eq $info) {
			my $toremvar;
			my $toremdist;
			my $varlisttouse = replaceGenesisNamesTop($remvariablesvarlistvar[$remiter], $infeature, 0);

			#Remove All
			if ($remvariables[$remiter] eq "all") {
				for (my $vliter = 0; $vliter < scalar @varlistname; $vliter++) {
								
					if ($varlisttouse eq $varlistname[$vliter]) {
					
						if ($varlistvalidity[$vliter] == -1) {
							printerror ("CT", "", $varlistname[$vliter], "Varlist was not initiated yet for remove all.");
						}
					
						for (my $i = 0; $i < scalar @{$varlistavailability[$vliter]}; $i++) {
							${$varlistavailability[$vliter]}[$i] = 0;
							printG (3, " removing all to $varlisttouse\n");
							
						}
					}
				}
			}
			#Remove 1
			else {
				#Remove a number
				if ($remvariables[$remiter] =~ /^[0-9]+$/) {
					$toremvar = $remvariables[$remiter]-1;
					$toremdist = $remvariables[$remiter];
					printG (3, " removing $remvariables[$remiter] to $varlisttouse\n");
				}
				#Remove a value
				else {
					for (my $variter = 0; $variter < scalar @variables; $variter++) {
						if ($remvariables[$remiter] eq $variables[$variter] && ($variablesfeature[$variter] eq $infeature || $variablesfeature[$variter] eq "")) {
							$toremvar = ${$variablescounters[$currentdepth]}[$variter]-1;
							$toremdist = ${$variablescounters[$currentdepth]}[$variter];
							
							printG (3, " removing $variables[$variter] 's ${$variablescounters[$currentdepth]}[$variter] from $varlisttouse\n");
						}
					}
					for (my $variter = 0; $variter < scalar @parameters; $variter++) {
						if ($remvariables[$remiter] eq $parameters[$variter] && ($parametersfeature[$variter] eq $infeature || $parametersfeature[$variter] eq "")) {
							$toremdist = ${$parameterscounters[$currentdepth]}[$variter];
							$toremvar = ${$parameterscounters[$currentdepth]}[$variter];
							printG (3, " reming $variables[$variter] 's ${$variablescounters[$currentdepth]}[$variter] from $varlisttouse\n");
						}
					}
					for (my $loopiter = 0; $loopiter < scalar @genloopvar; $loopiter++) {
						if ($genloopfeature[$loopiter] eq $infeature) {
							if ($remvariables[$remiter] eq $genloopvar[$loopiter] && $genloopvalid[$loopiter] >= 1) {
								$toremvar = ${$genloopvalue[$loopiter]}[$genloopvalid[$loopiter]-1]-1;
								$toremvar = ${$genloopvalue[$loopiter]}[$genloopvalid[$loopiter]-1];
								printG (3, " reming $variables[$loopiter] 's ${$variablescounters[$currentdepth]}[$loopiter] from $varlisttouse\n");
							}
						}
					}
				}
			
				#The actual remove from the availability list
				for (my $vliter = 0; $vliter < scalar @varlistname; $vliter++) {
				
					if ($varlisttouse eq $varlistname[$vliter]) {
					
						if ($varlistvalidity[$vliter] == -1) {
							printerror ("CR", "", $varlistname[$vliter], "Varlist was not initiated yet for remove.");
						}
					
						${$varlistavailability[$vliter]}[$toremvar] = 0;
						printG (3, "  rem successful!\n");
					}
				}
				
				#The actual remove from the distribution
				for (my $disiter = 0; $disiter < scalar @distributions; $disiter++) {
					if ($distributions[$disiter] eq $varlisttouse) {
						if (${$distributionsprob[$disiter]}[0] ne "real") {
		
							for (my $i = 0; $i < scalar @{$distributionsvalues[$disiter]}; $i++) {
							
								if (${$distributionsvalues[$disiter]}[$i] == $remvariables[$remiter]) {
									my $total = 1 - ${$distributionsprob[$disiter]}[$i];
									
									${$distributionsprob[$disiter]}[$i] = 0;
									${$distributionsreal[$disiter]}[$i] = 0;
									
									for (my $j = 0; $j < scalar @{$distributionsvalues[$disiter]}; $j++) {
									
										${$distributionsprob[$disiter]}[$j] = ${$distributionsprob[$disiter]}[$j]/$total;
										
									}
								}								
							}
					
							printG (3, " removing $remvariables[$remiter] to $distributions[$disiter]\n");
							
						}
						else { 
								printerror ("BR", "", $varlisttouse, "Remove cannot work with real values.");
						}
					}
				}
			}
		}
	}
}

##?##?## PHASE2: REPLACE LINES ##?##?##

# GENERATION PHASE: Pushup values to next depth level
sub pushupValueDepth {
	my @parameterscounterlocal;
	my @parameterssampledlocal;
	
	#TODO: passing up and down should deep copy for arrays

	for (my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
		$parameterscounterlocal[$pariter] = ${$parameterscounters[$currentdepth-1]}[$pariter];
		if (!defined ${$parameterssampled[$currentdepth-1]}[$pariter] || ${$parameterssampled[$currentdepth-1]}[$pariter] eq "") {
			$parameterssampledlocal[$pariter] = "";
		}
		else {
			$parameterssampledlocal[$pariter] = 0;
		}
		
	}
	$parameterscounters[$currentdepth] = \@parameterscounterlocal;
	$parameterssampled[$currentdepth] = \@parameterssampledlocal;
}
# GENERATION PHASE: Pushup variables to next depth level
sub pushupVariableDepth {
	my @variablescounterlocal;
	for (my $variter = 0; $variter < scalar @variables; $variter++) {
		$variablescounterlocal[$variter] = ${$variablescounters[$currentdepth-1]}[$variter];
	}
	$variablescounters[$currentdepth] = \@variablescounterlocal;
}
# GENERATION PHASE: Increase depth and all the things that go with it
sub increaseDepth {
	$currentdepth++;
	$distvalidlocality[$currentdepth] = scalar @distributions;
	$insingleline[$currentdepth] = $insingleline[$currentdepth-1];
	$lastlevelflag = 1;
	$currentindent[$currentdepth] = $currentindent[$currentdepth-1];
	pushupValueDepth();
	pushupVariableDepth();
}
# GENERATION PHASE: Decrease depth, clean up lists
sub decreaseDepth {
	#remove unneeded distributions
	while ($distvalidlocality[$currentdepth] != scalar @distributions) {
		splice(@distributions, scalar @distributions-1, 1);
		splice(@distributionsvalues, scalar @distributionsvalues-1, 1);
		splice(@distributionsprob, scalar @distributionsprob-1, 1);
		splice(@distributionsreal, scalar @distributionsreal-1, 1);
	}
	
	#Remove unneeded varlists
	for (my $vliter = 0; $vliter < scalar @varlistname; $vliter++) {
		if ($varlistvalidity[$vliter] eq $currentdepth) {
			my @varslist;
			$varlistavailability[$vliter] = \@varslist;
			$varlistvalidity[$vliter] = -1;
		}
	}
	
	$insingleline[$currentdepth+1] = 0;
	
	$currentdepth--;
}

##?##?## REPLACEMENT LINES ##?##?##

# GENERATION PHASE: Replace all genesis names that have to do with strings
sub replaceGenesisNames {
	my $replacetext = $_[0];	
	my $reference = $_[1];
	my $referencename = $_[2];
	my $infeature = $_[3];
	my $inequalityflag = $_[4];
	if ($referencereplaced == 0) {
		$replacetext = replaceFeatureParameters($replacetext, $reference, $referencename, $infeature, $inequalityflag);
	}
	if ($referencereplaced == 0) {
		$replacetext = replaceGenloopsVariables($replacetext, $reference, $referencename, $infeature, $inequalityflag);
	}
	if ($referencereplaced == 0) {
		$replacetext = replaceValueReferences($replacetext, $reference, $referencename, $infeature, $inequalityflag);
	}
	if ($referencereplaced == 0) {
		$replacetext = replaceVarlistReferences($replacetext, $reference, $referencename, $infeature, $inequalityflag);
	}
	if ($referencereplaced == 0) {
		$replacetext = replaceVariableReferences($replacetext, $reference, $referencename, $infeature, $inequalityflag);
	}

	return $replacetext;
}

sub replaceGenesisNamesTop {
	my $replacetext = $_[0];	
	my $infeature = $_[1];
	my $inequalityflag = $_[2];
	if ($timingflag == 1) {
		if ($replacestarttime == 0 || $replaceendtime > $replacestarttime) {
			$replacestarttime = time;
		}
		else {
			my $newreplacestarttime = time;
			$timereplace = $timereplace + ($newreplacestarttime - $replacestarttime);
			$replacestarttime = $newreplacestarttime;
		}
	}
	
	while ($badflag == 0 && $replacetext =~ /(^|[^\\])(\$\{([^\$\{\}]*)\})/) {
	
		my $reference = $2;
		my $referencename = $3;
		
		$referencereplaced = 0;

		$replacetext = replaceGenesisNames($replacetext, $reference, $referencename, $infeature, $inequalityflag);
		
		if ($referencecheck == 1 && $referencereplaced == 0) {
			printerror ("DH2", "", $referencename, "Reference found with a non-existent Genesis name.");
		}
		$referencereplaced = 0;
	}
	if ($timingflag == 1) {
		if ($replaceendtime > $replacestarttime) {
			my $newreplaceendtime = time;
			$timereplace = $timereplace + ($newreplaceendtime - $replaceendtime);
			$replaceendtime = $newreplaceendtime;
		}
		else {
			$replaceendtime = time;
			$timereplace = $timereplace + ($replaceendtime - $replacestarttime);
		}
	}
	return $replacetext;
}
# GENERATION PHASE: Replace all varlist references
sub replaceVarlistReferences {
	my $text = $_[0];	
	my $reference = $_[1];
	my $referencename = $_[2];
	my $infeature = $_[3];
	my $inequalityflag = $_[4];
		
	#replace distributions
	if ($referencename =~ /^([^\s\(\[]*)[^\S\n]*(\((.*)\))?[^\S\n]*(\[(.*)\])?$/) {
		my $referencename2 = $1;
		$referencename2 =~ s/^\s+|\s+$//g;

		my $bracketnum;
		my $parameterslist;
		
		if (defined $3) {
			$parameterslist = $3;
			$parameterslist =~ s/^\s+|\s+$//g;
		} 
		
		if (defined $5) {
			$bracketnum = $5;
			$bracketnum =~ s/^\s+|\s+$//g;
		}
		
		for (my $vliter = 0; $badflag == 0 && $vliter < scalar @varlistname; $vliter++) {
			if  ($referencename2 eq $varlistname[$vliter]) {
			
				lineCount(16);
			
				my $replace;
				if ((!defined $parameterslist || $parameterslist eq "size") && !defined $bracketnum) {
					my $counter = 0;
					for (my $i = 0; $i < scalar @{$varlistavailability[$vliter]}; $i++) {
						if (${$varlistavailability[$vliter]}[$i] == 1) {
							$counter++;
						}
					}
					
					$replace = $counter;
				}
				
				elsif (defined $parameterslist && $parameterslist eq "name") {
					$replace = $varlistvarname[$vliter];
				}
				#Check bracket bounds
				#TODO: check init all values
				elsif (defined $parameterslist && $parameterslist eq "value") {
					if (!defined $bracketnum) {
						printerror ("DY", "", "$reference", "Value arg needs an index.");
					}
					if (numbervsstring($bracketnum) == 2) {
						printerror ("DV", "", "$reference", "Varlist's Value arg not a number.");
					}
					elsif ($bracketnum > scalar @{$varlistavailability[$vliter]}) {
						printerror ("DW", "", "$reference", "Number for value arg of varlist is out of bounds: over.\nRemember indices for varlists start at 1.");
					}
					elsif ($bracketnum <= 0) {
						printerror ("DX", "", "$reference", "Number for value arg of varlist is out of bounds: under.\nRemember indices for varlists start at 1.");
					}
					
					else {
						if ($varlistinitallflag[$vliter]) {
							$replace = $varlistinitvalue[$vliter];
						}
						else {
							my @values = split(",", $varlistinitvalue[$vliter], 2);
							if (defined $values[$bracketnum]) {
								$replace = $values[$bracketnum];
							}
							else {
								$replace = 0;
							}
						}
					}
				}
				
				elsif (defined $parameterslist) {
					printerror ("DI", "", $parameterslist, "Not a proper argument for a varlist.");
				}
				
				else {
					$replace = $varlistvarname[$vliter] . $bracketnum;
				}
				
				#Strict made it not work before because eval(chars) is not defined with strict.

				#If it is in a genif, add quotes to the genloop variable
				if ($inequalityflag == 1) {
					$replace =~ s/^[\'|\"]([$generegex,:;]*)[\'|\"]$/\"$1\"/;
				}
				else {
					$replace =~ s/^[\'|\"]([$generegex,:;]*)[\'|\"]$/$1/;
				}
				
				my $before;
				my $end;
				
				$referencename = fixBracketsForRegEx($referencename);
				
				if ($text =~ /(^|[^\\])\$\{$referencename\}/) {
					if (defined $1) {
						$before = $1;
					}
					else {
						$before = "";
					}
					#Things are replaced once. removed /g.
					$text =~ s/(^|[^\\])\$\{$referencename\}/$before$replace/;
				}
				else {
					printerror ("ZZP", "", $text, "Something is off with the compiler. Tell Alton.");
				}
			
				$referencereplaced = 1;
				#debug_printcurrentparameterset;
				if (!defined $replace) {
					printerror ("ZZQ", "", $text, "Something is off with the compiler. Tell Alton.");
				}
			}
			$text =~ s/\\$varlistname[$vliter]/$varlistname[$vliter]/g;
		}
	}
	return $text;
}

sub checkTemplateValues {
	my $text = $_[0];
	for (my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
		if ($text =~ /^$parameters[$pariter]$/) {
			printerror ("BH", "", $text, "Feature repetition value not allowed in template program.");
		}
	}
}

sub fixBracketsForRegEx {
	my $text = $_[0];
	$text =~ s/\(/\\\(/g;
	$text =~ s/\)/\\\)/g;
	$text =~ s/\[/\\\[/g;
	$text =~ s/\]/\\\]/g;
	$text =~ s/\*/\\\*/g;
	$text =~ s/\//\\\//g;
	$text =~ s/\-/\\\-/g;
	$text =~ s/\=/\\\=/g;
	$text =~ s/\+/\\\+/g;
	return $text;		
}

# GENERATION PHASE: Replace all value references
sub replaceValueReferences {
	my $text = $_[0];
	my $reference = $_[1];
	my $referencename = $_[2];	
	my $infeature = $_[3];
	my $inequalityflag = $_[4];
	my $arrayflag = 0;
	my $bracketnum = -1;
		
	if ($referencename =~ /^([\w]*)\[([\d]*)\]/ ) {
		$referencename = $1;
		$bracketnum = $2;
		$arrayflag = 1;
		
		if (!defined $bracketnum || $bracketnum eq "") {
			printerror ("DQ", "", "$reference", "No number used for array value.");
		}
	}
	elsif ($referencename =~ /^([\w]*)\[(-[\d]*)\]/ ) {
		printerror ("DT", "", "$reference", "Number is out of bounds: under.\nRemember indices for value arrays start at 0.");
	}
	
	#replace distributions
	for (my $pariter = 0; $badflag == 0 && $pariter < scalar @parameters; $pariter++) {
		if ($referencename eq $parameters[$pariter]) {
			#Check if this value is in the template code (not allowed for now) 
			if ($infeature eq "" && (($referencecheck == 1 && $referencereplaced == 0) || $referencecheck == 0)){
				#if it is, this function will end processing
				checkTemplateValues($referencename);
			}
			#else check we're in the right feature and the value is defined
			elsif (($parametersfeature[$pariter] eq $infeature || $parametersfeature[$pariter] eq "") && (defined ${$parameterssampled[$currentdepth]}[$pariter])) {
				if (${$parameterssampled[$currentdepth]}[$pariter] ne "") {
					my $tempdepth = $currentdepth;
					# sampled at 1, 0 are every step above
					#ex "" "" 1 0 0 0

					while ($tempdepth >= 0 && ${$parameterssampled[$tempdepth]}[$pariter] eq "0") {
						$tempdepth--;
					}
					
					if ($tempdepth != -1 && ${$parameterssampled[$tempdepth]}[$pariter] eq "" && ${$parameterssampled[$tempdepth+1]}[$pariter] eq "0" && !defined ${$parameterscounters[$currentdepth]}[$pariter] ) {
						printerror ("DJ", "", $text, "Value used exists but has no sampled value yet.");
					}
					elsif ($tempdepth == -1 && ${$parameterssampled[0]}[$pariter] eq "0" && !defined ${$parameterscounters[$currentdepth]}[$pariter]){
						if ($equalWithoutGenmathFlag == 0) {
							printerror ("DK", "", $text, "Value used in global or program section and exists but has no sampled value yet.");
						}
						else {
							printerror ("DK1", "", $text, "Value used in global or program section and exists but has no sampled value yet. (Did you forget a genmath when assigning a value?)");
						}
					}
					
					lineCount(14);
					
					#Take what value replaces the reference
					my $replace;
					if ($parametersarrayflag[$pariter] == 1) {
					
						if ($arrayflag == 1) {
							if ($bracketnum >= scalar @{${$parameterscounters[$currentdepth]}[$pariter]}) {
								printerror ("DS", "", "Array $parameters[$pariter] with index $parametersarraybrackets[$pariter]", "Number is out of bounds: over. (value is $bracketnum while size is " . scalar @{${$parameterscounters[$currentdepth]}[$pariter]} .").\nRemember indices for value arrays start at 0.");
							}
							else {
								$replace = ${${$parameterscounters[$currentdepth]}[$pariter]}[$bracketnum];
							}
						}
						else {
							printerror ("DU", "", "$reference", "No index brackets used for array value.");
						}						
					}
					else {
						if ($arrayflag == 1) {
							printerror ("DR", "", "$parametersarraybrackets[$pariter]", "Number used for non-array value.");
						}
						else {
							$replace = ${$parameterscounters[$currentdepth]}[$pariter];
						}
					}
					#Strict made it not work before because eval(chars) is not defined with strict.
						
					if ($inequalityflag == 1) {
						$replace =~ s/^[\'|\"]([$generegex,:;]*)[\'|\"]$/\"$1\"/;
					}
					else {
						$replace =~ s/^[\'|\"]([$generegex,:;]*)[\'|\"]$/$1/;
					}
					
					my $before;
					my $end;
					
					$referencename = fixBracketsForRegEx($referencename);
					if ($text =~ /(^|[^\\])\$\{$referencename(\[$bracketnum\])?\}/) {
					
						if (defined $1) {
							$before = $1;
						}
						else {
							$before = "";
						}
												
						#Things are replaced once. removed /g.
						$text =~ s/(^|[^\\])\$\{$referencename(\[$bracketnum\])?\}/$before$replace/;
					}

					else {
						printerror ("ZZR", "", $text, "Something is off with the compiler. Tell Alton.");
					}
					
					$referencereplaced = 1;
					#debug_printcurrentparameterset;
					if (!defined $replace) {
						printerror ("ZZS", "", $text, "Something is off with the compiler. Tell Alton.");
					}
				}
			}
		}

		$text =~ s/\\$parameters[$pariter]/$parameters[$pariter]/g;
	}
	return $text;
}
# GENERATION PHASE: Replace all variable references
sub replaceVariableReferences {
	my $text = $_[0];
	my $reference = $_[1];
	my $referencename = $_[2];
	my $infeature = $_[3];
	my $inequalityflag = $_[4];
	
	for (my $variter = 0; $badflag == 0 && $variter < scalar @variables; $variter++) {
		if ($variablesfeature[$variter] eq $infeature) {
			if ($referencename eq $variables[$variter]) {
				my $varitersearch;
				my $varlisttouse;
				my $value;
				if ($variablesevalflag[$variter]==1) {
					$varitersearch = $variter;
					$varlisttouse = replaceGenesisNamesTop($variablesvarlistvar[$varitersearch], $infeature, 0);
					$value = "$reference";
				}
				#=
				else {
					for (my $variter2 = 0; $badflag == 0 && $variter2 < scalar @variables; $variter2++) {
						if ($variablesequalpar[$variter] =~ /$variables[$variter2]/) {			
							$varitersearch = $variter2;
														
							$value = $variablesequalpar[$variter];
							#printG (3, "Value for before $variables[$variter]: $variablesvarlistvar[$variter]\n");

							#$value =~ s/$variables[$variter2]/$variablesequalpar[$variter2]/;
							$variablesvarlistvar[$variter] = $variablesvarlistvar[$variter2];
							
							$varlisttouse = replaceGenesisNamesTop($variablesvarlistvar[$varitersearch], $infeature, 0);
							
							#printG (3, "Value for after $variables[$variter]: $variablesvarlistvar[$variter]\n");
						}
					}
				}
				
				#Find the varlist to know the name of the varlist, and replace
				for (my $vliter = 0; $badflag == 0 && $vliter < scalar @varlistname; $vliter++) {
					if ($varlistname[$vliter] eq $varlisttouse) {
						my $varnametouse;
						if ($varlistevalflag[$vliter] != 0){
							$varnametouse = $varlistvarname[$vliter];
						}
						else {
							$varnametouse = $varlistequalvar[$vliter];
						}
						$value =~s/\$\{$variables[$varitersearch]\}/${$variablescounters[$currentdepth]}[$varitersearch]/;

						my $maxvalue = scalar @{$varlistavailability[$vliter]};
						
						if (teststringismath($value)) {
							$value = ((eval($value)-1)%$maxvalue)+1;
							${$variablescounters[$currentdepth]}[$variter] = $value;
						}
						else {
							printerror ("ZZT", "", "$value" , "Something is off with the compiler. Tell Alton.");
						}
							
						lineCount(15);
						if ($inequalityflag == 1) {
							$text =~ s/(^|[^\\])\$\{$referencename\}/\"$1$varnametouse$value\"/g;
						}
						else {
							$text =~ s/(^|[^\\])\$\{$referencename\}/$1$varnametouse$value/g;
						}

						$referencereplaced = 1;
					}
				}
			}
		}
		$text =~ s/\\$variables[$variter]/$variables[$variter]/g;

	}
	return $text;
}
# GENERATION PHASE: Replace all stored feature references
sub replaceStoredReferences {
	my $text = $_[0];
	my $reference = $_[1];
	my $referencename = $_[2];
	my $infeature = $_[3];
	my $currentlastlevelflag = 1;
	#replace distributions
	for (my $pariter = 0; $pariter < scalar @stored; $pariter++) {
		if (($storedfeature[$pariter] eq $infeature && defined ${$storedsampled[$currentdepth]}[$pariter] && ${$storedsampled[$currentdepth]}[$pariter] ne "") || $storedfeature[$pariter] eq "") {
			if ($referencename eq $stored[$pariter]) {	
				#Work on spacing
				if ($currentlastlevelflag == 1 && $text =~ /^([^\S\n]*)/) {
				
					my $space = $1;
					#if ($infeature ne "" && $space =~ /^([\t])([^\S\n]*)/)
					#	$space = $2;
					#
					$currentindent[$currentdepth] = $currentindent[$currentdepth] . $space;
				}
								
				lineCount(17);				
				$currentlastlevelflag = 0;
	
	
				my $replacetext = "";
				for (my $funiter = 0; $funiter < scalar @{$storedprocessed[$pariter]}; $funiter++) {
					my $addtext = ${$storedprocessed[$pariter]}[$funiter];
					$addtext = searchForReferences($addtext, $infeature, 0);
					#$addtext =~ s/(^|\n)/$1$currentindent[$currentdepth]/g;
					#$addtext =~ s/$currentindent[$currentdepth]$//g;
										
					if ($addtext ne "" && (($lastlevelflag == 1 && $insingleline[$currentdepth] == 0) ||
					(defined $insingleline[$currentdepth+1] && $insingleline[$currentdepth+1] == 1 && $insingleline[$currentdepth] == 0))) {
						#$addtext =~ s/^/$currentindent[$currentdepth]/;
						#Case: reference[2] is put in 1 line, each needs an indent
						$addtext =~ s/\n/\n$currentindent[$currentdepth]/g;
						$addtext =~ s/\n[^\S\n]*$/\n/;

						#$text = $currentindent[$currentdepth] . $text;
					}
					
					$replacetext = $replacetext . $addtext;
					
				}
				
				my $before;
				my $end;
				
				$text =~ s/^([^\S\n]*)//;

										
				if ($text =~ /(^|[^\\])\$\{$referencename\}/) {
				
					if (defined $1) {
						$before = $1;
					}
					else {
						$before = "";
					}

					$replacetext =~ s/\n$//;
					
					#Things are replaced once. removed /g.
					$text =~ s/(^|[^\\])\$\{$referencename\}/$before$replacetext/;
				}

				else {
					printerror ("ZZU", "", $text, "Something is off with the compiler. Tell Alton.");
				}
				
				$referencereplaced = 1;
			}
		}
		
		if ($currentlastlevelflag == 0) {
			$lastlevelflag = 0;
		}
		
		$text =~ s/\\$stored[$pariter]/$stored[$pariter]/g;
	}
	return $text;
}
# GENERATION PHASE: Replace all genloop iterator references
sub replaceGenloopsVariables {
	my $text = $_[0];
	my $reference = $_[1];
	my $referencename = $_[2];
	my $infeature = $_[3];
	my $inequalityflag = $_[4];

	for (my $loopiter = 0; $loopiter < scalar @genloopvar; $loopiter++) {
		if ($genloopfeature[$loopiter] eq $infeature || $genloopfeature[$loopiter] eq "") {
			if ($genloopvalid[$loopiter] >= 1) {
				my $replace = ${$genloopvalue[$loopiter]}[$genloopvalid[$loopiter]-1];
				
				#If it is in a genif, add quotes to the genloop variable
				if ($inequalityflag == 1) {
					$replace =~ s/^[\'|\"]([$generegex,:;]*)[\'|\"]$/\"$1\"/;
				}
				else {
					$replace =~ s/^[\'|\"]([$generegex,:;]*)[\'|\"]$/$1/;
				}
				
				if  ($referencename eq $genloopvar[$loopiter]) {
					
					lineCount(22);
					
					if ($text =~ /(^|[^\\])\$\{$genloopvar[$loopiter]\}/) {
						$text =~ s/(^|[^\\])\$\{$genloopvar[$loopiter]\}/$1$replace/g;
					}
					else {
						$text =~ s/(^|[^\w\\])$genloopvar[$loopiter]($|\W)/$1$replace$2/g;
					}
					$referencereplaced = 1;
				}
			}
			$text =~ s/\\$genloopvar[$loopiter]/$genloopvar[$loopiter]/g;
		}
	}
	return $text;
}
# GENERATION PHASE: Replace all feature parameter references
sub replaceFeatureParameters {
	my $text = $_[0];
	my $reference = $_[1];
	my $referencename = $_[2];
	my $infeature = $_[3];
	my $inequalityflag = $_[4];

	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @features; $feaiter++) {
		if ($infeature eq $features[$feaiter]) {
			if ($featuresparams[$feaiter] != 0) {
				for (my $pariter = 0; $pariter < scalar @{$featuresparams[$feaiter]}; $pariter++) {
					my $replace = ${${$featuresparameterlist[$feaiter]}[$featuresparamsvalid[$feaiter]-1]}[$pariter];
					
					#If it is in a genif, add quotes to the feature variable
					if ($inequalityflag == 1) {
						$replace =~ s/^[\'|\"]([$generegex,:;]*)[\'|\"]$/\"$1\"/;
					}
					else {
						$replace =~ s/^[\'|\"]([$generegex,:;]*)[\'|\"]$/$1/;
					}	
					
					my $counter = 0;
					$counter++ while ($text =~ /(^|[^\\])\$\{${$featuresparams[$feaiter]}[$pariter]\}/g);

					my $counter2 = 0;
					if  ($referencename eq ${$featuresparams[$feaiter]}[$pariter]) {
						
						lineCount(19);
					
						$counter2++;
						$text =~ s/(^|[^\\])\$\{$referencename\}/$1$replace/;
						$referencereplaced = 1;
						if ($counter2 > $counter) {
							printerror ("DF", "", "\$\{${$featuresparams[$feaiter]}[$pariter]\}", "Probably an endless loop of replacement.");
						}					
					}
				}
			}
		}
	}
	return $text;
}

sub generateOnDemand {
	my $text = $_[0];
	my $bracketnum = $_[1];
	my $feaiter = $_[2];
	my $replacetext = "";
	
	for (my $i = 0; $badflag == 0 && $i < $bracketnum; $i++) {
		increaseDepth();

		my $textatnum = "";
		$featuresvalid[$feaiter] = 1;
		
		#Cycle the lines and search lines for references
		for (my $funiter = 0; $badflag == 0 && $funiter < scalar @{$featureslist[$feaiter]}; $funiter++) {
			my $text = ${$featureslist[$feaiter]}[$funiter];

			#re-sample
			if (!testLineForKeywords($text, $features[$feaiter])) {
				$text = searchForReferences($text, $features[$feaiter]);					
				$textatnum = $textatnum . $text;
			}
		}

		$featuresvalid[$feaiter] = 0;
		
		if ($textatnum ne "" && (($lastlevelflag == 1 && $insingleline[$currentdepth] == 0) ||
		(defined $insingleline[$currentdepth+1] && $insingleline[$currentdepth+1] == 1 && $insingleline[$currentdepth] == 0))) {
			#TODO: check: Which case needs this?
			#$textatnum =~ s/^/$currentindent[$currentdepth]/;
			#$text =~ s/\n/\n$currentindent[$currentdepth]/g;
			#$text = $currentindent[$currentdepth] . $text;
		}
		
		$replacetext = $replacetext . $textatnum;
		
		decreaseDepth();
	}
	return $replacetext;
}


# GENERATION PHASE: Replace all feature references
sub replaceFeatureReferences {

	if ($dotcounter % 10 == 0) {
		printG (2, ".");
		$dotcounter = 0;
	}
	$dotcounter++;

	my $text = $_[0];

	my $reference = $_[1];
	my $referencename = $_[2];
	my $infeature = $_[3];
	my $currentlastlevelflag = 1;
	
	if ($referencename =~ /^([^\s\(\[]*)[^\S\n]*(\((.*)\))?[^\S\n]*(\[(.*)\])?$/) {

		my $referencename2 = $1;
		$referencename2 =~ s/^\s+|\s+$//g;

		my $bracketnum;
		my $parameterslist;
		
		if (defined $3) {
			$parameterslist = $3;
		} 
		
		if (defined $5) {
			$bracketnum = $5;
			$bracketnum =~ s/^\s+|\s+$//g;
		}
		if (!defined $bracketnum) {
			$bracketnum = 1;
		}

		for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @features; $feaiter++) {
			if ($referencename2 eq $features[$feaiter]) {
				#Check for no recursion
				if ($recursionflag == 0) {
					if ($infeature eq $features[$feaiter]) {
						printerror ("CO", "", "$infeature", "$infeature has recursion. Either turn on recursion flag or remove it completely.");
					}
				}
				
				if ($featuresvalid[$feaiter] == 1) {
					printerror ("CP", "", "$features[$feaiter]", "$features[$feaiter] has circular recursion. Either turn on recursion flag or remove it completely.");
				}
				
				printG (3, "$features[$feaiter] reference found.\n");
					
				#Work on spacing
				if ($currentlastlevelflag == 1 && $text =~ /^([^\S\n]*)/) {
				
					my $space = $1;
					#if ($infeature ne "" && $space =~ /^([\t])([^\S\n]*)/)
					#	$space = $2;
					#
					$currentindent[$currentdepth] = $currentindent[$currentdepth] . $space;
				}
				$currentlastlevelflag = 0;
				
				my @parameterlist;
				
				if (defined $parameterslist && scalar @{$featuresparams[$feaiter]} != 0) {
					@parameterlist = split(",", $parameterslist);
					for (my $i = 0; $i < scalar @parameterlist; $i++) {
						$parameterlist[$i] =~ s/^\s+|\s+$//g;
						$parameterlist[$i] = replaceGenesisNamesTop($parameterlist[$i], $infeature, 0);

					}
				}
				
				${$featuresparameterlist[$feaiter]}[$featuresparamsvalid[$feaiter]] = \@parameterlist;
				
				$featuresparamsvalid[$feaiter]++;

				if (scalar @parameterlist > scalar @{$featuresparams[$feaiter]}) {
					printerror ("S", "", $text, "Too many parameters in this feature.");
				}
				elsif (scalar @parameterlist < scalar @{$featuresparams[$feaiter]}) {
					printerror ("T", "", $text, "Too few parameters in this feature.");
				}
				
			
				#Added during May 27 reordering
				#Replace names in brackets
				$bracketnum = replaceGenesisNamesTop($bracketnum, $infeature, 0);

				lineCount(18);
				
				#Evaluate
				my $replacetext = "";
				if (teststringismath($bracketnum)) {
					$bracketnum = eval($bracketnum);
				}
				else {
					printerror ("G", "", $text, "Feature repetition value/number not valid.");
				}

				#Generate on Demand
				#my $replacetext = generateOnDemand($text, $bracketnum, $feaiter);
				
				#Do that many feature references based on $num
				for (my $i = 0; $badflag == 0 && $i < $bracketnum; $i++) {
					increaseDepth();

					my $textatnum = "";
					$featuresvalid[$feaiter] = 1;
					
					#Cycle the lines and search lines for references
					for (my $funiter = 0; $badflag == 0 && $funiter < scalar @{$featureslist[$feaiter]}; $funiter++) {
					
						my $text = ${$featureslist[$feaiter]}[$funiter];

						#re-sample
						if (!testLineForKeywords($text, $features[$feaiter])) {
							lineCount(12);
							$text = searchForReferences($text, $features[$feaiter]);					
							$textatnum = $textatnum . $text;
						}
					}

					$featuresvalid[$feaiter] = 0;
					
					if ($textatnum ne "" && (($lastlevelflag == 1 && $insingleline[$currentdepth] == 0) ||
					(defined $insingleline[$currentdepth+1] && $insingleline[$currentdepth+1] == 1 && $insingleline[$currentdepth] == 0))) {
						#TODO: Check: Which case needs this?
						#$textatnum =~ s/^/$currentindent[$currentdepth]/;
						#$text =~ s/\n/\n$currentindent[$currentdepth]/g;
						#$text = $currentindent[$currentdepth] . $text;
					}
					
					$replacetext = $replacetext . $textatnum;
					
					decreaseDepth();
				}

				$text =~ s/^([^\S\n]*)//;

				$referencename = fixBracketsForRegEx($referencename);
				
				#Simple replacement if the feature is at the beginning of the line
				if($text =~ /^([^\S\n]*)\$\{$referencename\}([^\S\n]*)/) {
					$replacetext =~ s/\n$//;
					$text =~ s/(^|([^\\]))\$\{$referencename\}/$replacetext/;
					#$text =~ s/\n$//;
				}
				
				#Feature anywhere else
				else {
					$replacetext =~ /^([^\S\n]*)/;
					my $savespace = $1;
					$replacetext =~ s/^([^\S\n]*)//;
					$replacetext =~ s/(\s*)$//;

					if ($text =~ /(^|([^\\]))\$\{$referencename\}/) {
						my $end = $9;
						if (!defined $end) {
							$end = "";
						}
						$text =~ s/(^|([^\\]))\$\{$referencename\}/$1$replacetext$end/;
					}
										
					$text = $savespace.$text;
				}
				$referencereplaced = 1;
				$featuresparamsvalid[$feaiter]--;
			}

					
			if ($currentlastlevelflag == 0) {
				$lastlevelflag = 0;
			}
			$text =~ s/\\$features[$feaiter]/$features[$feaiter]/g;
			$text =~ s/^([\s]*)\\\/\/\//$1\/\/\//g;
			$text =~ s/^([\s]*)\\value/$1value/g;
			$text =~ s/^([\s]*)\\variable/$1variable/g;
			$text =~ s/^([\s]*)\\add/$1add/g;
			$text =~ s/^([\s]*)\\remove/$1remove/g;
			$text =~ s/^([\s]*)\\assert/$1assert/g;

		}
	}
	return $text;
}

# GENERATION PHASE: Replace all feature references
sub replaceFeatureReferencesIR {
	my $text = $_[0];
	return $text;
	for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @features; $feaiter++) {
		while ($text =~ /((^|([^\\]))(\$\{))($features[$feaiter])(([^\S\n])*(\((.*)\))?[^\S\n]*(\[[^\S\n]*(.*)[^\S\n]*\])?\})/) {
			$text =~ s/((^|([^\\]))(\$\{))($features[$feaiter])(([^\S\n])*(\((.*)\))?[^\S\n]*(\[[^\S\n]*(.*)[^\S\n]*\])?\})/$1_F$feaiter$6/;
		}
	}	
	return $text;
}



# GENERATION PHASE: Replace all feature references
sub replaceFeatureReferencesNew {

	if ($dotcounter >= 10) {
		printG (2, ".");
		$dotcounter = 0;
	}
	$dotcounter++;
	
	my $text = $_[0];
	my $infeature = $_[1];
	my $currentlastlevelflag = 1;
	while ($text =~ /(^|([^\\]))\$\{_F([\d])(([^\S\n])*(\((.*)\))?[^\S\n]*(\[[^\S\n]*(.*)[^\S\n]*\])?\})/) {
		my $feaiter = $3;
				
		#Check for no recursion
		if ($recursionflag == 0) {
			if ($infeature eq $features[$feaiter]) {
				printerror ("CO", "", "$infeature", "$infeature has recursion. Either turn on recursion flag or remove it completely.");
			}
		}
		
		if ($featuresvalid[$feaiter] == 1) {
			printerror ("CP", "", "$features[$feaiter]", "$features[$feaiter] has circular recursion. Either turn on recursion flag or remove it completely.");
		}
		
		printG (3, "$features[$feaiter] reference found.\n");
			
		#Work on spacing
		if ($currentlastlevelflag == 1 && $text =~ /^([^\S\n]*)/) {
		
			my $space = $1;
			#if ($infeature ne "" && $space =~ /^([\t])([^\S\n]*)/)
			#	$space = $2;
			#
			$currentindent[$currentdepth] = $currentindent[$currentdepth] . $space;
		}
		$currentlastlevelflag = 0;
		
		my $bracketnum;
		my @parameterlist;
		#Type 1 is ${parameter}, see parameters if needed
		if ($text =~ /(^|([^\\]))\$\{_F([\d])([^\S\n])*(\((.*)\))?[^\S\n]*(\[[^\S\n]*(.*)[^\S\n]*\])?\}/) {
			if (defined $5 && scalar @{$featuresparams[$feaiter]} != 0) {
				@parameterlist = split(",", $5);
				for (my $i = 0; $i < scalar @parameterlist; $i++) {
					$parameterlist[$i] =~ s/^\s+|\s+$//g;
					$parameterlist[$i] = replaceGenesisNamesTop($parameterlist[$i], $infeature, 0);

				}
			}
			
		
			if (defined $7) {
			$bracketnum = $7;
			}
			if (!defined $bracketnum) {
				$bracketnum = 1;
			}
		}
		${$featuresparameterlist[$feaiter]}[$featuresparamsvalid[$feaiter]] = \@parameterlist;
		
		$featuresparamsvalid[$feaiter]++;

		if (scalar @parameterlist > scalar @{$featuresparams[$feaiter]}) {
			printerror ("XS", "", $text, "Too many parameters in this feature.");
		}
		elsif (scalar @parameterlist < scalar @{$featuresparams[$feaiter]}) {
			printerror ("XT", "", $text, "Too few parameters in this feature.");
		}
		#If target code, give an error if it is a parameter in brackets
		if ($currentdepth == 1){
			if ($bracketnum =~ /^[$generegex\d\s]*$/) {
			}
			else {
				for (my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
					if ($parametersfeature[$pariter] eq "" && $bracketnum =~ /^\$\{$parameters[$pariter]\}$/) {
						printerror ("BH", "", $text, "Feature repetition value not allowed in target code.");
					}
				}
			}
		}
		
		#Added during May 27 reordering
		#Replace names in brackets
		$bracketnum = replaceGenesisNamesTop($bracketnum, $infeature, 0);
		
		#Evaluate
		if (teststringismath($bracketnum)) {
			$bracketnum = eval($bracketnum);
		}
		else {
			printerror ("G", "", $text, "Feature repetition value/number not valid.");
		}

		my $replacetext = generateOnDemand($text, $bracketnum, $feaiter);
		#Do that many feature references based on $num
		

		#Do the replacement, type 1 is brackets	
		$text =~ s/^([^\S\n]*)//;

		#Simple replacement if the feature is at the beginning of the line
		if($text =~ /^([^\S\n]*)\$\{_F([\d])([^\S\n])*(\((.*)\))?[^\S\n]*(\[[^\S\n]*(.*)[^\S\n]*\])?\}([^\S\n]*)$/) {
			$replacetext =~ s/\n$//;
			$text =~ s/(^|([^\\]))\$\{_F([\d])([^\S\n])*(\((.*)\))?[^\S\n]*(\[[^\S\n]*(.*)[^\S\n]*\])?\}/$replacetext/;
			#$text =~ s/\n$//;
		}
		
		#Feature anywhere else
		else {
			$replacetext =~ /^([^\S\n]*)/;
			my $savespace = $1;
			$replacetext =~ s/^([^\S\n]*)//;
			$replacetext =~ s/(\s*)$//;
			
			if ($text =~ /(^|([^\\]))\$\{_F([\d])([^\S\n])*(\((.*)\))?[^\S\n]*(\[[^\S\n]*(.*)[^\S\n]*\])?\}/) {
				my $end = $9;
				if (!defined $end) {
					$end = "";
				}
				$text =~ s/(^|([^\\]))\$\{_F([\d])([^\S\n])*(\((.*)\))?[^\S\n]*(\[[^\S\n]*(.*)[^\S\n]*\])?\}/$1$replacetext$end/;
			}
			
			$text = $savespace.$text;
		}

		$featuresparamsvalid[$feaiter]--;
	}
	if ($currentlastlevelflag == 0) {
		$lastlevelflag = 0;
	}
		
	#for (my $feaiter = 0; $badflag == 0 && $feaiter < scalar @features; $feaiter++) {
	#	$text =~ s/\\$features[$feaiter]/$features[$feaiter]/g;
	#	$text =~ s/^([\s]*)\\\/\/\//$1\/\/\//g;
	#	$text =~ s/^([\s]*)\\value/$1value/g;
	#	$text =~ s/^([\s]*)\\variable/$1variable/g;
	#	$text =~ s/^([\s]*)\\add/$1add/g;
	#	$text =~ s/^([\s]*)\\remove/$1remove/g;
	#	$text =~ s/^([\s]*)\\assert/$1assert/g;
	
	return $text;
}
# GENERATION PHASE: Replace all genloops
sub replaceGenloops {
	my $text = $_[0];
	my $infeature = $_[1];
	my $currentlastlevelflag = 1;
	# Parse out genloop first
	if ($text =~ /(^|^[^\w\\])genloop/) {
		if ($text =~ /(^|^[^\w\\])genloop[\s]*([\w]*):([$generegex]*):([$generegex]*)(:[$generegex]*)? *([\w]*)[^\S\n]*/) {
			my $var = $2;
			my $valueStart = $3;
			my $valueEnd = $4;
			my $valueStride;
			my $id = $6;
			if (defined $5) {
				$valueStride = $5;
				$valueStride =~s/^://;
			}
			if (!defined $valueStride) {
				$valueStride = 1;
			}
			
			#Added during May 27 reordering
			$valueStart = replaceGenesisNamesTop($valueStart, $infeature, 0);		
			$valueEnd = replaceGenesisNamesTop($valueEnd, $infeature, 0);
			$valueStride = replaceGenesisNamesTop($valueStride, $infeature, 0);
			
			if (teststringismath($valueStart)) {
				$valueStart = eval($valueStart);
			}
			else {
				printerror ("AG", "", "$valueStart", "valueStart not fully evaluated.");
			}
			
			if (teststringismath($valueEnd)) {
				$valueEnd = eval($valueEnd);
			}
			else {
				printerror ("AH", "", "$valueEnd", "valueEnd not fully evaluated.");
			}
			
			if (teststringismath($valueStride)) {
				$valueStride = eval($valueStride);
			}
			else {
				printerror ("AI", "", "$valueStride", "valueStride not fully evaluated.");
			}
			lineCount(11);
			lineCount(21);
			my $replacetext = "";
			# Find the right loop info
			for (my $loopiter = 0; $badflag == 0 && $loopiter < scalar @genloopvar; $loopiter++) {

				if ($genloopid[$loopiter] eq $id) {

					$genloopvalid[$loopiter]++;
					
					#Stride is positive
					if ($valueStride > 0) {
						#Do the genloop
						for (my $loopvariter = $valueStart; $badflag == 0 && $loopvariter <= $valueEnd; $loopvariter = $loopvariter + $valueStride) {
							${$genloopvalue[$loopiter]}[$genloopvalid[$loopiter]-1] = $loopvariter;
							#Iterate through the lines in the genloop
							for (my $funiter = 0; $funiter < scalar @{$genlooplist[$loopiter]}; $funiter++) {
								my $changedtext = ${$genlooplist[$loopiter]}[$funiter];
								#re-sample
								if (!testLineForKeywords($changedtext, $infeature)) {
									lineCount(12);
									$changedtext = searchForReferences($changedtext, $infeature);
									$replacetext = $replacetext . $changedtext;
									#$replacetext = $replacetext . $changedtext . "\n";
								}
							}
							$currentlastlevelflag = 0;
							# Moved to end of for loop, only done once?
							#$replacetext =~ s/[^\S\n]*\n$//;
						}
					}
					
					#Stride is negative
					else {
						#Do the genloop
						for (my $loopvariter = $valueStart; $loopvariter >= $valueEnd; $loopvariter = $loopvariter + $valueStride) {
							${$genloopvalue[$loopiter]}[$genloopvalid[$loopiter]-1] = $loopvariter;
							#Iterate through the lines in the genloop
							for (my $funiter = 0; $funiter < scalar @{$genlooplist[$loopiter]}; $funiter++) {
								my $changedtext = ${$genlooplist[$loopiter]}[$funiter];
								#re-sample
								if (!testLineForKeywords($changedtext, $infeature)) {
									$changedtext = searchForReferences($changedtext, $infeature);
									$replacetext = $replacetext . $changedtext;
									#$replacetext = $replacetext . $changedtext . "\n";
								}
							}
							$currentlastlevelflag = 0;
							# Moved to end of for loop, only done once?
							#$replacetext =~ s/[^\S\n]*\n$//;
						}
					}
					
					$genloopvalid[$loopiter] --;
				}
				lineCount(11);
			}
			#Moved here
			#$replacetext =~ s/^[^\S\n]*//;
			$replacetext =~ s/[^\S\n]*\n$//;
			if ($text =~ /(^|^[^\w\\])genloop[\s]*([\w]*):([$generegex]*):([$generegex]*)(:[$generegex]*)?[\s]*([\w]*)[^\S\n]*/) {
				my $before;
				if (defined $1) {
					$before = $1;
				}
				else {
					$before = "";
				}
				$text =~ s/(^|^[^\w\\])genloop[\s]*([\w]*):([$generegex]*):([$generegex]*)(:[$generegex]*)?[\s]*([\w]*)[^\S\n]*/$before$replacetext/;
			}
			else {
				printerror ("ZZV", "", "$text", "Do not think this should happen. Tell Alton if it does.");
			}
			#$text =~ s/\n$//;
		}
		elsif ($text =~ /(^|^[^\w\\])genloop[\s]*(([$referegex]*)[\s]*(==|>=|<=|>|<|!=)[\s]*([$referegex]*)) *([\w]*)[^\S\n]*/) {
			my $condition = $2;
			my $id = $6;
			my $replacetext = "";
			#PROBLEM: scoping means condition stays the same...?
			#No longer a problem due to genmath
			for (my $loopiter = 0; $loopiter < scalar @genloopvar; $loopiter++) {
				if ($genloopid[$loopiter] eq $id){
					my $newcondition = replaceGenesisNamesTop($genloopinequality[$loopiter], $infeature, 1);
					while (evaluateboolean($newcondition, $infeature)) {
				
						for (my $funiter = 0; $funiter < scalar @{$genlooplist[$loopiter]}; $funiter++) {
							my $changedtext = ${$genlooplist[$loopiter]}[$funiter];
							#re-sample
							if (!testLineForKeywords($changedtext, $infeature)) {
								$changedtext = searchForReferences($changedtext, $infeature);
								$replacetext = $replacetext . $changedtext;
							}
						}
						$currentlastlevelflag = 0;
						$newcondition = replaceGenesisNamesTop($genloopinequality[$loopiter], $infeature, 1);
					}
				}
			}
			$replacetext =~ s/\n$//;
			$text =~ s/(^|^[^\w\\])genloop[\s]*(([$referegex]*)[\s]*(==|>=|<=|>|<|!=)[\s]*([$referegex]*)) *([\w]*)[^\S\n]*/$1$replacetext/;
			#$text =~ s/\n$//;
		}
	}
	if ($currentlastlevelflag == 0) {
		$lastlevelflag = 0;
	}
	$text =~ s/\\genloop/genloop/g;
	return $text;
}
# GENERATION PHASE: Replace all genifs
sub replaceGenifs {
	my $text = $_[0];
	my $infeature = $_[1];
	my $currentlastlevelflag = 1;
	my $geniffound = 0;
	my $genifreplaced = 0;
	if ($text =~ /(^|^[^\w\\])genif ([\d]*)[\s]*$/) {
		$geniffound = 1;
		my $id = $2;
		
		#Added during May 27 reordering
		for (my $ifiter = 0; $badflag == 0 && $ifiter < scalar @genifinequality; $ifiter++) {
			if ($genifid[$ifiter] eq $id){
				#If the genif area has not be evaluated yet or if it is the first
				if ($geniftype[$ifiter] == 0) {
					$inagenifflag = 0;
					$genifevaledflag = 0;
				}
				if ($genifevaledflag == 0 || $geniftype[$ifiter] == 0){	
					lineCount(10);
					my $condition = replaceGenesisNamesTop($genifinequality[$ifiter], $infeature, 1);						
					if (evaluateboolean($condition, $infeature)==1) {
						lineCount(20);
						my $replacetext = "";
						for (my $funiter = 0; $funiter < scalar @{$geniflist[$ifiter]}; $funiter++) {
							my $changedtext = ${$geniflist[$ifiter]}[$funiter];
							#re-sample
							if (!testLineForKeywords($changedtext, $infeature)) {
								lineCount(12);
								$changedtext = searchForReferences($changedtext, $infeature);

								$replacetext = $replacetext . $changedtext;
							}
						}
						$replacetext =~ s/\n$//;
						$text =~ s/(^|^[^\w\\])genif ([\d]*)/$1$replacetext/;
						$genifreplaced = 1;
						$currentlastlevelflag = 0;	
						if ($geniftype[$ifiter] == 0 || $geniftype[$ifiter] == 1) {
							$genifevaledflag = 1;
						}
					}
				}
				if ($geniftype[$ifiter] == 2) {
					$geniffound = 0;
				}
			}
		}
		#if the genif is not replaced, remove the genif completely
		if ($genifreplaced == 0) {
			if ($text =~ /(^|^[^\w\\])genif ([\d]*)[\s]*\n/) {
				$text =~ s/(^|^[^\w\\])genif ([\d]*)[\s]*\n/$1/;
			}
			# Happens on fixsingleline now
			else {
				$text =~ s/(^|^[^\w\\])genif ([\d]*)[\s]*/$1/;
				$text =~ s/\n$//;
			}
		}
		$inagenifflag = 1;
	
	}
	if ($geniffound == 0) {
		$inagenifflag = 0;
		$genifevaledflag = 0;
	}
	if ($currentlastlevelflag == 0) {
		$lastlevelflag = 0;
	}
	$text =~ s/\\genif/genif/g;
	return $text;
}
# GENERATION PHASE: Replace all genspaces
sub replaceGenspaces {
	my $text = $_[0];
	my $infeature = $_[1];
	while ($text =~ /(^|^[^\w\\])genspace[\s]*$/) {
		$text =~ s/(^|^[^\w\\])genspace[\s]*$/\n/;
	}

	$text =~ s/\\genspace/genspace/g;
	return $text;
}
# GENERATION PHASE: Replace all gentabs
sub replaceGentabs {
	my $text = $_[0];
	my $infeature = $_[1];
	while ($text =~ /(^|[^\w\\])gentab/) {
		$text =~ s/(^|[^\w\\])gentab/$1\t/;
	}

	$text =~ s/\\gentab/gentab/g;
	return $text;
}
# GENERATION PHASE: Replace all genevals
sub replaceGenevals {
	my $text = $_[0];
	my $infeature = $_[1];
	#find geneval
	while ($text =~ /(^|([^\w\\]))geneval[\s]*\(([^\)]*)\)[\s]*$/) {
		my $condition = $3;
		my $replacetext;
		#old thing that geneval did: call eval
		
		if (teststringismath($condition)) {
			$replacetext = eval($condition);
		}
		else {
			$replacetext = searchForReferences($condition, $infeature);
		}
		
		#substitute
		$text =~ s/(^|([^\w\\]))geneval[\s]*\(([^\)]*)\)/$1$replacetext/;
	}
	$text =~ s/\\geneval/geneval/g;
	return $text;
}

##?##?## FEATURE FLOW ##?##?##

# GENERATION PHASE: Search for all feature references
sub searchForReferences {

	my $text = $_[0];
	my $infeature = $_[1];
	
	increaseDepth();
	#print "Current Depth++: $currentdepth\n";
	#print "Text1: '$text'\n";

	$text = fixsingleline($text, $infeature);

	$text = replaceGenloops($text, $infeature);
	$text = replaceGenifs($text, $infeature);
	if ($timingflag == 1) {
		if ($replacestarttime == 0 || $replaceendtime > $replacestarttime) {
			$replacestarttime = time;
		}
		else {
			my $newreplacestarttime = time;
			$timereplace = $timereplace + ($newreplacestarttime - $replacestarttime);
			$replacestarttime = $newreplacestarttime;
		}
	}
	
	my $laststring = "";
	
	while ($text =~ /(^|[^\\])(\$\{([^\$\{\}]*)\})/) {
		#Reference found
		my $reference = $2;
		my $referencename = $3;
		#check if we are still in the same place
		if ($laststring eq $text) {
			printerror ("DL", "", $laststring, "Either infinite recursion or an error with the compiler.");
		}
		else {
			$laststring = $text;
		}

		$referencereplaced = 0;
		$text = replaceFeatureReferences($text, $reference, $referencename, $infeature);
		if ($referencereplaced == 0) {
			$text = replaceStoredReferences($text, $reference, $referencename, $infeature);
		}
		if ($referencereplaced == 0) {
			$text = replaceGenesisNames($text, $reference, $referencename, $infeature, 0);
		}
		if ($referencereplaced == 0) {
			$text = replaceGenevals($text, $infeature);
		}
		if ($referencereplaced == 0) {
			$text = replaceGenspaces($text, $infeature);
		}
		if ($referencecheck == 1 && $referencereplaced == 0) {
			printerror ("DH1", "", $reference, "Reference found with a non-existent Genesis name.");
		}
	}
	$referencereplaced = 0;
	if ($timingflag == 1) {
		if ($replaceendtime > $replacestarttime) {
			my $newreplaceendtime = time;
			$timereplace = $timereplace + ($newreplaceendtime - $replaceendtime);
			$replaceendtime = $newreplaceendtime;
		}
		else {
			$replaceendtime = time;
			$timereplace = $timereplace + ($replaceendtime - $replacestarttime);
		}
	}
	#if ($lastlevelflag == 0) {
	#	$text =~ s/(^|\n)/$1$currentindent[$currentdepth]/g;
	
	# If Lowest level, and not a single line, and there is text
	# or we just got out of a singleline
	# Add indenting
	
	if ($text ne "" && (($lastlevelflag == 1 && $insingleline[$currentdepth] == 0) ||
	  (defined $insingleline[$currentdepth+1] && $insingleline[$currentdepth+1] == 1 && $insingleline[$currentdepth] == 0))) {
		$text =~ s/^/$currentindent[$currentdepth]/;
	}
	
	#$text = replaceGentabs($text, $infeature);
	
	#print "Returning '$text'\n";
	#print "Current Depth--: $currentdepth\n";
	
	decreaseDepth();
		
	return $text;
}
# GENERATION PHASE: Parses generate, returns number of files (sets) to generate
sub parseGenerateLine {
	my $gensetnumber = $_[0];
	my $generate = 0;
	
	#Reset the distributions
	@distributions = ();
	@distributionsvalues = ();
	@distributionsprob = ();
	@distributionsreal = ();
	
	if ($gentouch[$gensetnumber] == 0){
		$generatetouchflag = 0;
	}
	else {
		$generatetouchflag = 1;
	}
	if (looks_like_number($generates[$gensetnumber])) {
		printG (3, $generates[$gensetnumber] . " to be generated... with this distribution set" . "\n");
		$generate = $generates[$gensetnumber];
	}
	else {
		printerror ("B", "", $generates[$gensetnumber], "Number to be distributed invalid: $generates[$gensetnumber].");	
		
	}

	if ($gendistribute[$gensetnumber] =~ /^[\s]*,/ ||
	$gendistribute[$gensetnumber] =~ /,[\s]*,/ || $gendistribute[$gensetnumber] =~ /,[\s]*$/) {
		printwarning ("WF", "", $gendistribute[$gensetnumber], "This line contains an empty distribution.");
	}
	my @distributiontemp = split(",", $gendistribute[$gensetnumber]);
	my $bracketflag = 0;
	my $joinskip = 0;
	my @distribution;

	
	my $globalandlocal = scalar @globaldistributions + scalar @localdistributions;
	for(my $disiter = 0; $disiter < scalar @distributiontemp; $disiter++) {
		
		if (!defined $distribution[$disiter-$joinskip]) {
			$distribution[$disiter-$joinskip] = $distributiontemp[$disiter];
		}
		else {
			$distribution[$disiter-$joinskip] = $distribution[$disiter-$joinskip].",".$distributiontemp[$disiter];
		}
		printG (3, " Distributions " . ($disiter-$joinskip). ": '". $distribution[$disiter-$joinskip]. "'\n");
		
		#I do not think ordering needs fixing here. Error M/O detects order
		$bracketflag++ while ($distributiontemp[$disiter] =~ /\{/g);
		$bracketflag-- while ($distributiontemp[$disiter] =~ /\}/g);
		
		if ($bracketflag >= 1) {
			$joinskip++;
		}
	}
	for(my $disiter = 0; $disiter < scalar @distribution; $disiter++) {
		handleDistribution($distribution[$disiter],1, "",1);
	}
	for(my $disiter = 0; $disiter < scalar @localdistributions; $disiter++) {
		handleDistribution($localdistributions[$disiter],0, "",1);
	}
	
	return $generate;
}
# GENERATION PHASE: Add spacing to line based on depth
sub adddepthspacing {
my $distline = $_[0];

my $output = "";	
for (my $a = 0; $a < $currentdepth; $a++) {
	$output = $output . " ";
}

$output = $output . $distline;
return $output;
}
# GENERATION PHASE: Sample the global section, returns if it is still enumerating
sub sampleglobal {
	my $lastiteration = $_[0];

	#update enum
	my $i = 0;
	my $updated = 0;
	for ($i = scalar @globalenum-1; $updated == 0 && $i >= 0; $i--) {
		for (my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
			if ($globalcodelines[$globalenum[$i]] =~ /^value $parametersnumber[$pariter]$/ && defined ${$parameterscounters[$currentdepth]}[$pariter]) {
				for (my $disiter = 0; $disiter < scalar @distributions; $disiter++) {
					if ($distributions[$disiter] eq $parametersdistvar[$pariter]) {
						for (my $disiter2 = 0; $disiter2 < scalar @{$distributionsvalues[$disiter]} && $updated == 0; $disiter2++) {
							if (${$distributionsvalues[$disiter]}[$disiter2] eq ${$parameterscounters[$currentdepth]}[$pariter]) {
								if ($disiter2+1 != scalar @{$distributionsvalues[$disiter]}) {
									${$parameterscounters[$currentdepth]}[$pariter] = ${$distributionsvalues[$disiter]}[$disiter2+1];
									${$parameterssampled[$currentdepth]}[$pariter] = 1;
									
									printG (3, "$parameters[$pariter] replace to ${$parameterscounters[$currentdepth]}[$pariter] \n");
	
									#removing header lines sampled in features
									#as long as there are still lines to remove, and not removed too many lines, and there are still more feature samples than program samples
									for (my $j = scalar @globalreport-1; scalar @headertemplines > 0 && $j >= 0 && $globalreport[$j] >= $globalenum[$i] ; $j--) {
										splice(@headertemplines, scalar @headertemplines-1, 1);
									}
									
									if ($parametersreportflag[$pariter]==1 && $parametersfullflag[$pariter]==1) {
										$valuereportedflag = 1;
										reportvalue($pariter);
									}
									$updated = 1;
								}
							}
						}
					}
				}
			}
		}
	}
		
	#If it is the last iteration and there is no more enum, stop sampling
	#Only sample if its not last iteration, or if something updated
	if ($lastiteration == 0 || $updated == 1) {
	
		#figure out where to continue processing.
		#$i+1, cause it goes one over before checking updated
		#+1 because the same line should not be run twice
		my $startglobal;
		if ($updated == 1) {
			$startglobal = $globalenum[$i+1]+1;
		}
		elsif ($updated == 0) {
			@headerprogramtemplines = ();
			$startglobal = 0;
			
		}
		else {
			printerror ("ZZW", "", "Updated != 0 or 1 sanity" , "Something is off with the compiler. Tell Alton.");
		}

		for (my $j = scalar @globaldist-1; $j >= 0 && $startglobal <= $globaldist[$j] && $distvalidlocality[$currentdepth] < scalar @distributions; $j--) {
			splice(@distributions, scalar @distributions-1, 1);
			splice(@distributionsvalues, scalar @distributionsvalues-1, 1);
			splice(@distributionsprob, scalar @distributionsprob-1, 1);
			splice(@distributionsreal, scalar @distributionsreal-1, 1);
		}
		
		for (my $funiter = $startglobal; $funiter < scalar @globalcodelines; $funiter++) {
			my $text = $globalcodelines[$funiter];
			#re-sample
			if (!testLineForKeywords($text, "global", 0)) {	
				$text = searchForReferences($text, "global", 0);
			}
		}
	}
	return $updated;
}
# GENERATION PHASE: Sample the program section, returns if it is still enumerating 
sub sampleprogram {
	my $lastiteration = $_[0];
	
	#update enum
	my $i = 0;
	my $updated = 0;
	for ($i = scalar @programenum-1; $updated == 0 && $i >= 0; $i--) {
		for (my $pariter = 0; $pariter < scalar @parameters; $pariter++) {
			if ($programcodelines[$programenum[$i]] =~ /^value $parametersnumber[$pariter]$/ && defined ${$parameterscounters[$currentdepth]}[$pariter]) {
				for (my $disiter = 0; $disiter < scalar @distributions; $disiter++) {
					if ($distributions[$disiter] eq $parametersdistvar[$pariter]) {
						for (my $disiter2 = 0; $disiter2 < scalar @{$distributionsvalues[$disiter]} && $updated == 0; $disiter2++) {
							if (${$distributionsvalues[$disiter]}[$disiter2] eq ${$parameterscounters[$currentdepth]}[$pariter]) {
								if ($disiter2+1 != scalar @{$distributionsvalues[$disiter]}) {
									${$parameterscounters[$currentdepth]}[$pariter] = ${$distributionsvalues[$disiter]}[$disiter2+1];
									${$parameterssampled[$currentdepth]}[$pariter] = 1;

									printG (3, "$parameters[$pariter] replace to ${$parameterscounters[$currentdepth]}[$pariter] \n");
									
									#removing header lines sampled in features
									#as long as there are still lines to remove, and not removed too many lines, and there are still more feature samples than program samples
									for (my $j = scalar @programreport-1; scalar @headerprogramtemplines > 0 && $j >= 0 && scalar @headerprogramtemplines > scalar @programreport; $j--) {										
										splice(@headerprogramtemplines, scalar @headerprogramtemplines-1, 1);
									}
									
									#removing header lines sampled in program
									#as long as there are still lines to remove, and not removed too many lines, and the report line is after (or the same as) the enum changed line
									for (my $j = scalar @programreport-1; scalar @headerprogramtemplines > 0 && $j >= 0 && $programreport[$j] >= $programenum[$i] ; $j--) {
									
										splice(@headerprogramtemplines, scalar @headerprogramtemplines-1, 1);
									}
									
									if ($parametersreportflag[$pariter]==1 && $parametersfullflag[$pariter]==1) {
										$valuereportedflag = 1;
										reportvalue($pariter);
									}
									$updated = 1;
								}
							}
						}
					}
				}
			}
		}
	}
	
	#If it is the last iteration and there is no more enum, stop sampling
	#Only sample if its not last iteration, or if something updated
	if ($lastiteration == 0 || $updated == 1) {
	
		#figure out where to continue processing.
		#$i+1, cause it goes one over before checking updated
		#+1 because the same line should not be run twice
		my $startprogram;
		if ($updated == 1) {
			$startprogram = $programenum[$i+1]+1;
		}
		elsif ($updated == 0) {
			@headerprogramtemplines = ();
			$startprogram = 0;
		}
		else {
			printerror ("ZZX", "", "Updated != 0 or 1 sanity" , "Something is off with the compiler. Tell Alton.");
		}

		for (my $j = scalar @programdist-1; $j >= 0 && $startprogram <= $programdist[$j] && $distvalidlocality[$currentdepth] < scalar @distributions; $j--) {
			splice(@distributions, scalar @distributions-1, 1);
			splice(@distributionsvalues, scalar @distributionsvalues-1, 1);
			splice(@distributionsprob, scalar @distributionsprob-1, 1);
			splice(@distributionsreal, scalar @distributionsreal-1, 1);
		}

		for (my $funiter = $startprogram; $funiter < scalar @programcodelines; $funiter++) {
			my $text = $programcodelines[$funiter];
			#re-sample
			if (!testLineForKeywords($text, "program", 0)) {	
				$text = searchForReferences($text, "program", 0);
			}
		}
	}
	else {
		while ($distvalidlocality[$currentdepth] != scalar @distributions) {
			splice(@distributions, scalar @distributions-1, 1);
			splice(@distributionsvalues, scalar @distributionsvalues-1, 1);
			splice(@distributionsprob, scalar @distributionsprob-1, 1);
			splice(@distributionsreal, scalar @distributionsreal-1, 1);
		}
	}

	return $updated;
}
# GENERATION PHASE: Report value to beginning of file
sub reportvalue {
	my $pariter= $_[0];
	my $line = "Set value " . $parameters[$pariter]. ": ".${$parameterscounters[$currentdepth]}[$pariter]. "\n";
	$headerprogramtemplines[scalar @headerprogramtemplines] = $reportcharacter;
	for (my $a = 0; $a < $currentdepth; $a++) {
		 $headerprogramtemplines[scalar @headerprogramtemplines-1] = $headerprogramtemplines[scalar @headerprogramtemplines-1] . " ";
	}
	$headerprogramtemplines[scalar @headerprogramtemplines-1] = $headerprogramtemplines[scalar @headerprogramtemplines-1] . $line;
	
}
# GENERATION PHASE: Report variable to beginning of file
sub reportvariable {
	my $variter= $_[0];
	my $varnametouse= $_[1];
	my $line = "Set variable " . $variables[$variter]. ": ". $varnametouse.${$variablescounters[$currentdepth]}[$variter]. "\n";
	$headerprogramtemplines[scalar @headerprogramtemplines] = $reportcharacter;
	for (my $a = 0; $a < $currentdepth; $a++) {
		 $headerprogramtemplines[scalar @headerprogramtemplines-1] = $headerprogramtemplines[scalar @headerprogramtemplines-1] . " ";
	}
	$headerprogramtemplines[scalar @headerprogramtemplines-1] = $headerprogramtemplines[scalar @headerprogramtemplines-1] . $line;	
}

# GENERATION PHASE: Iterate through the target code, making feature replacements as necessary
sub iterateThroughTargetCode {
	printG (0, " Working..");
	#For each target code line
	for (my $linesiter = 0; $badflag == 0 && $linesiter < scalar @templateproglines; $linesiter++) {
		my $text = $templateproglines[$linesiter];
		
		lineCount(12);
		#Perform text replacements
		increaseDepth();
		
		if ($timingflag == 1) {
			$replacestarttime = time;
		}
		
		while ($badflag == 0 && $text =~ /(^|[^\\])(\$\{([^\$\{\}]*)\})/) {
			my $reference = $2;
			my $referencename = $3;
			$referencereplaced = 0;
			
			checkTemplateValues($referencename);
			###$referencename = replaceGenesisNamesTop($referencename, "", 0);
			$text = replaceFeatureReferences($text, $reference, $referencename, "", 0);
			if ($referencereplaced == 0) {
				$text = replaceStoredReferences($text, $reference, $referencename, "", 0);
			}
			if ($referencecheck == 1 && $referencereplaced == 0) {
				printerror ("DD", "", $reference, "Reference found, no feature has this Genesis name.");
			}
		}

		if ($timingflag == 1) {
			$replaceendtime = time;
			$timereplace = $timereplace + ($replaceendtime - $replacestarttime);
		}
		
		if (($lastlevelflag == 1 && $insingleline[$currentdepth] == 0) ||
		  (defined $insingleline[$currentdepth+1] && $insingleline[$currentdepth+1] == 1 && $insingleline[$currentdepth] == 0)
		  && $text ne '') {
			$text =~ s/^/$currentindent[$currentdepth]/;
			#$text =~ s/\n/\n$currentindent[$currentdepth]/g;
			#$text = $currentindent[$currentdepth] . $text;
		}
		
		$currentindent[$currentdepth] = "";
		decreaseDepth();
		
		#If the line is blank and ignore vertical space, ignore line
		if ($ignorevertspaceflag == 1 && $text =~ /^[\s]*$/) {
			printG (3, "Do not include this line");
		}
		
		#Otherwise it is a normal line and just place it normally
		else {
			$templines[scalar @templines] = $text;
		}
	}
	printG (2, " \n");
}
# GENERATION PHASE: Print single instance of target code to single file
sub printtofile {
	#Formerly called addheader
	my $geniter = $_[0];
	my $enumeratenumber = $_[1];
	open (OUTPUTFILE, ">:crlf", $outname1.$geniter."_".$enumeratenumber.$outname2) or die "cannot read new file: $!";

	if ($headerflag == 1) {
		print OUTPUTFILE "$reportcharacter$reportcharacter"." Genesis Program:  $filename\n";
		
		if (defined $filename2) {
			print OUTPUTFILE "$reportcharacter$reportcharacter"." Template Program: $filename2\n";
		}
		
		print OUTPUTFILE "$reportcharacter$reportcharacter"."File created: $outname1$geniter"."_"."$enumeratenumber$outname2 \n";
		if ($valuereportedflag == 1) {
			print OUTPUTFILE "\n$reportcharacter"."Sampled Reported Values:\n";
		}
		
		
		for (my $linesiter = 0; $linesiter < scalar @headertemplines; $linesiter++) {
			my $text = $headertemplines[$linesiter];
			print OUTPUTFILE $text;
		}				
		for (my $linesiter = 0; $linesiter < scalar @headerprogramtemplines; $linesiter++) {
			my $text = $headerprogramtemplines[$linesiter];
			print OUTPUTFILE $text;
		}
	}
	
	
	for (my $linesiter = 0; $linesiter < scalar @templines; $linesiter++) {
		my $text = $templines[$linesiter];
		print OUTPUTFILE $text;
	}
	print OUTPUTFILE "\n";
	print OUTPUTFILE "\n";	
	
	close (OUTPUTFILE);
	
	
}

##?##?## REGULAR FLOW ##?##?##

# PARSING PHASE: Top Level Parsing Phase function
sub phase1Parse {
	if ($timingflag == 1) {
		$starttime = time;
	}
	TEST: while ($checkoneheaderflag == 0) {
		my $text = <GENPROGFILE>;
		$linenumber++;
		
		#$/ = "\r\n";
		chomp($text);
		my $keyword;
		my $info;
		($keyword, $info) = split(" ", $text, 2);

		if (defined $keyword and $keyword eq "begin" and defined $info and $info eq "genesis") {
		
			printP (2, "Begin genesis!\n");

			my @temp;
			$namesforlocality[$parsebracketcounter+1] = \@temp;
			
			while ($checkoneheaderflag == 0) {
				my $text = <GENPROGFILE>;
				
				parseGenesisLine($text);			
			}
			if ($checkoneheaderflag == 0) {
				printerror ("AC", "", "End of header", "No end genesis line.");
			}
			if ($programexistsflag == 0) {
				printwarning ("WH", "", "End of header", "No program segment.\n");
			}
			if ($globalexistsflag == 0) {
				printwarning ("WJ", "", "End of header", "No global segment.\n");
			}
		}
		elsif ($text =~ /^\#/) {
			printP (2, "Ignore comment line, before language barriers.\n");
		}
		elsif ($text =~ /^[\s]*$/) {
			printP (2, "Ignore whitespace line, before language barriers.\n");
		}
		else {
			printerror ("CJ", "", "Before header", "First non-whitespace line is not 'begin genesis'.");
		}
	}
	if ($timingflag == 1) {
		$endtime = time;
		$timeparse = $endtime - $starttime;
	}
	printP (2, "End parse!\n\n");
	$parsingflag = 0;
	printeverything;

	if ($filename2 eq "") {	
		TEST2: while (my $text = <GENPROGFILE>) {
			#TODO: if we want an IR 
			#$text = replaceFeatureReferencesIR($text);
			$templateproglines[scalar @templateproglines] = $text;
		}
	}
	else {
		while (my $text = <TEMPLATEPROGFILE>) {
			#TODO: if we want an IR 
			#$text = replaceFeatureReferencesIR($text);
			$templateproglines[scalar @templateproglines] = $text;
		}
		close (TEMPLATEPROGFILE);
	}
	close (GENPROGFILE);
}
# GENERATION PHASE: Top Level Generation Phase function
sub phase2Generate {
	if ($generateflag == 1) {
	
		if (! (-d "./GeneratedInstancePrograms")) {
			#Open Instance Program
			mkdir("./GeneratedInstancePrograms", 0700) unless(-d "./GeneratedInstancePrograms");
		}
		chdir("./GeneratedInstancePrograms") or die "cannot chdir ./GeneratedInstancePrograms\n";

		if (! (-d "./$outDir")) {
			#Open Instance Program
			mkdir("./$outDir", 0700) unless(-d "./$outDir");
			chdir("./$outDir") or die "cannot chdir ./$outDir\n";
		}
		else {
			$foldercounter++;
			while (-d "./$outDir$foldercounter") {
				$foldercounter++;
			}
			
			mkdir("./$outDir$foldercounter", 0700) unless(-d "./$outDir$foldercounter");
			chdir("./$outDir$foldercounter") or die "cannot chdir ./$outDir$foldercounter\n";
			
		}
		#Order of operations stuff (OOO)
	
		#This is implemented for now
		#OOO1: Global is global for each line
		#Parse the distributions in the global line
		#Go through globals
		#Generate the number indicated
		#Enumerate global as necessary
		
		#OOO2: Global is sampled once for everything
		#That means we cannot have distributions in the generate line (with them, there is no knowledge of which distribution to use)
		
		#OOO3: Old method
		#Enumerate global for everything
		#The number indicated is the final number of programs, i.e., enumerated global should be 5 if instance programs is 5
		#Gives user flexibility
		#Problem is non enumerated values will mess things up and screws up the idea of ordering
		my $generateupto = 1;	#Generate up to this value
		#FOR EACH GENERATE LINE
		for (my $gensiter = 0; $gensiter < scalar @generates; $gensiter++) {
			if ($timingflag == 1) {
				$starttime = time;
			}
			@headertemplines= ();
		
			#Get the number of files (sets) to generate, parse all the dists
			my $generate = parseGenerateLine($gensiter);
			
			#setup global counters for this generate line (with this set of dists)
			setupGlobalCounters();
			#setupparamstartcounters;
			
			#Total number of sets
			$setcounter = $setcounter + $generate;
			
			#the number of valid distributions at this point
			$distvalidlocality[$currentdepth] = scalar @distributions;
			
			my $stillenumeratingglobal = 1;
			my $firstiteration = 1;
			
			#FOR EACH STILL ENUMERATING
			
			while ($stillenumeratingglobal == 1 && 
			(scalar @globalenum > 0 || $firstiteration == 1) ) {
				@headerprogramtemplines = ();

				#Returns whether we're still enumerating 
				if ($gensiter == scalar @generates) {
					$stillenumeratingglobal = sampleglobal(1);
				}
				else {
					$stillenumeratingglobal = sampleglobal(0);

				}
				
				if (scalar @globalenum == 0) {
					$stillenumeratingglobal = 0;
				}
				if ($firstiteration == 1 || $stillenumeratingglobal == 1) {
					if ($firstiteration == 1) {
						$stillenumeratingglobal = 1;
					}
					#not the first iteration
					$firstiteration = 0;
					
					#Generate from genstart to generateupto
					my $genstart = $generateupto;
					$generateupto = $generateupto + $generate;
					printG (2, "Generating " . $generate . " now!" . "\n");
					
					#Transfer all the globally sampled lines to its own array and clear old one
					for (my $i = 0; $i < scalar @headerprogramtemplines; $i++) {
						$headertemplines[scalar @headertemplines] =$headerprogramtemplines[$i];
					}
					@headerprogramtemplines = ();

					#Total global distributions.
					$distvalidlocality[$currentdepth] = scalar @distributions;

					#Line moved to before first sample
					#setupGlobalCounters();
					
					my $enumeratenumber = 1;
					my $overflowflag = 0;
					
					#FOR EACH INDIVIDUAL FILE
					
					for (my $geniter = $genstart; $overflowflag == 0 && $geniter < $generateupto+1; $geniter++) {
						#?# April 30: Removed
						#setupparamstartcounters;
						#setupparamlocalcounters;
						
						my $stillenumerating;
						
						#last set, maybe, send a flag. If last set, no need to sample.
						if ($geniter == $generateupto) {
							#might be over the limit
							$stillenumerating = sampleprogram(1);
						}
						else {
							#Regular flow is here
							$stillenumerating = sampleprogram(0);
						}
						
						
						#If we're no longer enumerating, reset the enum counter
						if ($stillenumerating == 0) {
							$enumeratenumber = 1;
						}
						#Else, we are enumerating, increase the number, stick with the old set number
						else {
							$enumeratenumber++;
							$geniter--;
						}
						#Alternative to break. If we are beyond what we are supposed to generate, set overflow flag.
						if ($geniter >=	 $generateupto){
							$overflowflag = 1;
						}
						#else, continue normal processing.
						else {
							$generatecounter++;
							$dotcounter = 10;
							if ($enumeratenumber == 1) {
								printG (2, "\nGenerating #$geniter\n");
							}
							if (scalar @programenum > 0) {
								if ($enumeratenumber != 1) {
									printG (2, "\n");
								}
								printG (2, "  Enumerating #$enumeratenumber\n");
							}
				
							$genbracketcounter = 0;
							
							@templines = ();
							
							iterateThroughTargetCode();					
							
							if ($timingflag == 1) {
								$endtime = time;
								$timecreate = $timecreate + ($endtime - $starttime);
							}
							
							if ($badflag == 0) {
								if ($timingflag == 1) {
									$starttime = time;
								}
							
								printtofile($geniter, $enumeratenumber);
								
								if ($timingflag == 1) {
									$endtime = time;
									$timegen = $timegen + ($endtime - $starttime);
								}
								
							}
							
							else {
								my $removalflag = 0;
								if ($badflag == 1) {
									$removalflag = 1;
									printwarning ("W1", "", "Bad flag", "BAD FLAG 1 - Assert fail\n");
								}
								elsif ($badflag == 2) {
									#Original Action: Delete and retry
									if ($emptyvarlistactionflag == 0) {
										$removalflag = 1;
										printwarning ("W2", "", "Bad flag", "BAD FLAG 2 - Empty Var List\n");
										$duplicatecounter++;
										if ($duplicatecounter == 100) {
											#may be removed later
											printerror ("ZZZ", "", "A", "Way too many duplicates for some reason. Exiting for now to prevent infinite loop.");
										}
									}
									#New Action: Delete and move on
									else {
										$errorlist[scalar @errorlist] = $geniter;
										$errorlist2[scalar @errorlist2] = $enumeratenumber;
										$removalflag = 1;
										$badflag = 0;
									}
								}
								elsif ($badflag == 3 || $badflag == 4) {
									$removalflag = 1;
									$duplicatecounter++;
									if ($duplicatecounter == 100) {
										#may be removed later
										printerror ("AD", "", "A", "Way too many duplicates for some reason. Exiting for now to prevent infinite loop.");
									}
								}
								
								if ($removalflag == 1) {
									$badflag = 0;
									$removalflag = 0;
									unlink $outname1.$geniter."_".$enumeratenumber.$outname2;
								}
								else {
									$duplicatecounter = 0;
								}
						
							}
							
							#printParamlocalcounters;
						}	
					}
					printParamglobalcounters;
				}
			}
		}
	}
	else {
		print "Generate flag off: Nothing to generate.";
	}
	printG (2, " \n");
	
	printfinalreport;
		
}

#Normal flow of the program
if ($printintroflag != 0) {
	print "\n Opening Genesis Version $versionnumber!\n\n";
}
handleArguments();
openOutputFiles();
phase1Parse();
phase2Generate();

exit;
