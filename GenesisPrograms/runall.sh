#!/usr/bin/sh
#
#    Runs Genesis on all the provided spec files. Acts as a testcase. Places programs in Directory GenAllResults

# NOTE: Genif test produces the following warnings (in stderr, unpiped to file):
# Argument "abc" isn't numeric in numeric eq (==) at (eval 166) line 1.
# Argument "abc" isn't numeric in numeric eq (==) at (eval 166) line 1.
# Argument "abc" isn't numeric in numeric eq (==) at (eval 171) line 1.
# Argument "abc" isn't numeric in numeric eq (==) at (eval 171) line 1.
# Argument "abc" isn't numeric in numeric eq (==) at (eval 172) line 1.
# Argument "abc" isn't numeric in numeric eq (==) at (eval 172) line 1.
#

GenFlag=1
FunFlag=1
ParFlag=1
ErrFlag=1
WarFlag=1

#Counters
CorrectOuts=0
InCorrectOuts=0
CorrectOuts2=0
InCorrectOuts2=0
CorrectErrs=0
InCorrectErrs=0
CorrectWarns=0
InCorrectWarns=0

#Spec name. Argument. Genesis file location. Warning check. Diff check.
testcase()
{
    echo " Running $1"
    if [ $3 == 1 ]; then
		if [ -z "$2" ]
			then
				./genesis.pl ./Testcases/spec-$1.c > ./output.out
			else
				./genesis.pl ./Testcases/spec-$1.c ./Testcases/spec-$2.c > ./output.out
		fi
        
    fi
    if [ $3 == 2 ]; then
		if [ -z "$2" ]
			then
				./genesis.pl ./Thesis/figure-$1.c > ./output.out
			else
				./genesis.pl ./Thesis/figure-$1.c ./Thesis/figure-$2.c > ./output.out
		fi
    fi
    
    if grep "Error" ./output.out > ./grep.out
    
    then
        # code if found
        echo "  Found an error, bad."
	    InCorrectOuts=$((InCorrectOuts+1))
		
	else
		CorrectOuts=$((CorrectOuts+1))
    fi
    if [ $4 == 1 ]; then
        if grep "Warning" ./output.out > ./grep.out
        then
            # code if found
            echo "  Found a warning, bad."
			CorrectOuts=$((CorrectOuts-1))
			InCorrectOuts=$((InCorrectOuts+1))
        fi
    fi
    
    if [ $5 == 1 ]; then
        if diff -q ./GeneratedInstancePrograms/Gen/* "./Testcases/GenAllResults/spec-$1.c"
        then
            echo "  Correct output."
            CorrectOuts2=$((CorrectOuts2+1))
        else
            echo "  Incorrect output."
            InCorrectOuts2=$((InCorrectOuts2+1))
        fi
    fi
    
    rm ./grep.out
    mv ./output.out ./GeneratedInstancePrograms/Gen/output.out
    mv ./GeneratedInstancePrograms/Gen ./GenAllResults/Gen-$1
}


errorcase()
{
    echo " Running $1"
    ./genesis.pl ./ErrorCases/Error$1.c outfile=gen*.c > ./output.out
    
    if [ $# -eq 1 ]; then
        Code=$1
    fi
    if [ $# -eq 2 ]; then
    Code=$2
    fi
    
    if grep "Error Code $Code" ./output.out > ./grep.out
    then
        # code if found
        echo "  Found, correct error."
        CorrectErrs=$((CorrectErrs+1))
	elif grep "Error" ./output.out
    then
        # code if found
        echo "  Found a different error."
        InCorrectErrs=$((InCorrectErrs+1))
    else
        # code if not found
        echo "  Not found, missing error."
        InCorrectErrs=$((InCorrectErrs+1))
        
    fi
    if [ -d "./GeneratedInstancePrograms/Gen" ]; then
    mv ./grep.out ./GeneratedInstancePrograms/Gen/grep.out
    mv ./output.out ./GeneratedInstancePrograms/Gen/output.out
    mv ./GeneratedInstancePrograms/Gen ./GenAllResults/Gen-Error$1
    else
        mv ./output.out ./GenAllResults/Gen-Error$1.output.out
        mv ./grep.out ./GenAllResults/Gen-Error$1.grep.out
    fi
}

warncase()
{
    echo " Running $1"
    ./genesis.pl ./ErrorCases/Warn$1.c > ./output.out
    
    if [ $# -eq 1 ]; then
        Code=$1
    fi
    if [ $# -eq 2 ]; then
    Code=$2
    fi
    
    if grep "Warning Code $Code" ./output.out > ./grep.out
    then
        # code if found
        echo "  Found, correct warning."
        CorrectWarns=$((CorrectWarns+1))
    else
        # code if not found
        echo "  Not found, missing warning."
        InCorrectWarns=$((InCorrectWarns+1))
    fi
    mv ./grep.out ./GeneratedInstancePrograms/Gen/grep.out
    mv ./output.out ./GeneratedInstancePrograms/Gen/output.out
    mv ./GeneratedInstancePrograms/Gen ./GenAllResults/Gen-Warn$1
}

if [ -d "./GeneratedInstancePrograms/Gen" ]; then
    echo "Deleting Gen"
    rm ./GeneratedInstancePrograms/Gen
fi

if [ -d "./GenAllResults2" ]; then
    echo "Deleting GenAllResults2"
    rm ./GenAllResults2
fi
if [ -d "./GenAllResults" ]; then
    echo "Moving GenAllResults into GenAllResults2"
    mv ./GenAllResults ./GenAllResults2
fi

echo "Creating GenAllResults"
mkdir ./GenAllResults

if [ $GenFlag == 1 ]; then
echo "Working on General Testcases" 
testcase "plain"         "" 1 1 0;    # Simple with just function substitution 
testcase "simplefeature" "simplefeature2" 1 1 0;    # Simple Example, single feature
testcase "demo"          "" 1 1 0;    # Three basic terms - epoch/comp/access, real sampling
testcase "demoorig"          "" 1 1 0;    # Three basic terms - epoch/comp/access, real sampling
testcase "demo1"         "" 1 1 0;    # Demo with compressed lines
testcase "demo2a"        "" 1 1 0;    # While loop. sources in last epoch are chosen from checker
testcase "demo2b"        "" 1 1 0;    # singleline(1) access at the end touches what's needed.
testcase "tianle"        "" 1 1 0;    # Tianle's example
fi

if [ $FunFlag == 1 ]; then
echo "Working on Functionality Testcases" 
testcase "distributions"       "" 1 1 0;    # Distribution tests
testcase "arrays"              "" 1 1 0;    # Array tests
testcase "sample"              "" 1 1 0;    # Various sampling tests
testcase "naming"              "" 1 1 0;    # Testing variable locality and substitution
testcase "varlist"             "" 1 1 0;    # Tests varlist features (types, init, endtouch)
testcase "cross"               "" 1 1 0;    # Another simple example, with a cross
testcase "crossglobal"         "" 1 1 0;    # Another simple example, with a cross in the global
testcase "crossmix"            "" 1 1 0;    # Another simple example, with a cross in the global
testcase "genif"               "" 1 1 0;    # Tests genif
testcase "genloop"             "" 1 1 0;    # Tests genloop functionality
testcase "geneval"             "" 1 1 0;    # Tests geneval functionality
testcase "genmath"             "" 1 0 0;    # Tests genmath functionality
testcase "stored"              "" 1 1 0;    # Tests stored features
testcase "arguments"           "" 1 1 0;    # Tests function arguments
testcase "addremovevar"        "" 1 0 0;    # Tests Add/remove - comps and accesses, no dead code DCE
testcase "singleline"          "" 1 1 0;    # Single Line cases with indenting
testcase "multigen"            "" 1 1 0;    # Tests multigen functionality 
fi

if [ $ParFlag == 1 ]; then
echo "Working on Parametrizable Testcases" 
testcase "simpleexample"      "" 1 1 0;    # Simple Example, single feature
testcase "ifloopinterchange"  "" 1 1 0;    # Tests if statement functionality
testcase "collectupperbound"  "" 1 1 0;    # Upperbound testcase
testcase "consecutivestrides" "" 1 1 0;    # Consecutive Stride testcase
testcase "numberofloops"      "" 1 1 0;    # loops vary from 1-5, doesnt work
testcase "cpucores"           "" 1 1 0;    # CPU cores
testcase "vbytealignment"     "" 1 1 0;    # Variable byte alignment
#testcase "unroll"            "" 1 1 0;    # Unroll a single epoch
testcase "padding"            "" 1 1 0;    # Padding
fi

if [ $ErrFlag == 1 ]; then
echo "Working on Error Testcases" 
errorcase "A";            # Invalid value line.
errorcase "B";            # Number to be distributed invalid.
errorcase "C";            # Invalid varlist line.
errorcase "D";            # Invalid variable line.
errorcase "E";            # Invalid add line.
errorcase "E1";           # Invalid add line. (HINT: varlist)
errorcase "F";            # Invalid rem line.
errorcase "F1";           # Invalid rem line. (HINT: varlist)
errorcase "G";            # Feature repetition value/number not valid.
errorcase "H";            # Dist for this value does not exist.
errorcase "I";            # Varlist for this variable does not exist.
errorcase "J";            # Dist range end less than start value.
errorcase "K";            # Varlist line argument invalid.
errorcase "L";            # Feature line argument invalid.
errorcase "M";            # Weird dist value. Right chars, but format off?
errorcase "N";            # Invalid feature line.
errorcase "O";            # Weird dist value. Some char not allowed.
#subsumed by error K, since no args are allowed now
errorcase "P" "K";        # Varlist line argument structure invalid.
errorcase "Q";            # Nothing in the brackets for value array.
errorcase "R";            # Number for value array is invalid.
errorcase "S";            # Too many arguments in this feature.
errorcase "T";            # Too few arguments in this feature.
errorcase "U";            # Genmath string not valid.
errorcase "V";            # RHS or expression not fully evaluated for Genmath.
errorcase "W";            # LHS does not exist to genmath.
errorcase "X";            # Duplicate name exists as an Value/Variable
errorcase "X2";           # Duplicate name exists as an Value/Variable (global)
errorcase "X3";           # Duplicate name exists as an Value/Variable (program)
errorcase "Y";            # Not enough distribution to sample all without replacement.
errorcase "Z";            # Value line argument invalid.
#subsumed by error Z, since no args are allowed now
errorcase "AA" "Z";        # Value line argument structure invalid.
errorcase "AB";            # Missing 'end' statement.
errorcase "AC";            # No end genesis line.
#errorcase "AD";            # Way too many duplicates for some reason.
errorcase "AE";            # Generate line in feature.
#subsumed by error Y, since no more on demand sampling.
errorcase "AF" "Y";        # Dynamic Not enough distribution to sample all without replacement.
errorcase "AG";            # valuestart not fully evaluated.
errorcase "AH";            # valueend not fully evaluated.
errorcase "AI";            # valuestride not fully evaluated.
errorcase "AJ";            # Genelsif without genif
errorcase "AK";            # Genelse without genif
errorcase "AL";            # Enumerate is invalid while in a feature.
errorcase "AM";            # Type argument more than once.
errorcase "AN";            # Init argument more than once.
errorcase "AO";            # Initall argument more than once.
errorcase "AP";            # Endtouch argument more than once.
errorcase "AQ";            # Report argument more than once.
errorcase "AR";            # Noreplacement argument more than once.
errorcase "AS";            # Singleline argument more than once.
errorcase "AT";            # Blank variable line.    
errorcase "AU";            # Start value not a valid value to sample from.
errorcase "AV";            # End value not a valid value to sample from.
errorcase "AW";            # Bad genif condition.
errorcase "AX";            # Bad genelsif condition.
errorcase "AY";            # Genelse should not have a condition.
# errorcase "AZ";            # Varlists is invalid (for now) while in a feature.
errorcase "BA";            # Variable line argument invalid.
#subsumed by error BA, since no args are allowed now
errorcase "BB" "BA";       # Variable line argument structure invalid.
errorcase "BC";            # Report argument more than once.
errorcase "BD";            # Varlists using 'from' should not have any arguments.
errorcase "BE";            # Weird argument for generate.
errorcase "BF";            # Value in the brackets not a number.
#subsumed by error J, since no more on demand sampling.
errorcase "BG" "J";        # End is less than start of range.
errorcase "BH";            # Feature repetition value not allowed in target code.
errorcase "BI";            # Underscores allowed but cannot be first char.
errorcase "BJ";            # Probability is non-numeric.
errorcase "BK";            # Start value not defined yet.
errorcase "BL";            # End value not defined yet.
errorcase "BM";            # More than one program segment.
errorcase "BN";            # Feature cannot be named "program".
#errorcase "BO";           # Testcase not possible yet
errorcase "BP";            # Distribution used already.
errorcase "BQ";            # Add cannot work with real values.
errorcase "BR";            # Remove cannot work with real values.
errorcase "BS";            # Invalid value line. (Maybe change 'from' to 'sample'?)
errorcase "BT";            # Not a valid varstring math result.
errorcase "BU";            # Too many probability arguments.
errorcase "BV";            # Too many probabilities.
errorcase "BW";            # Too many increments.
errorcase "BX";            # No number to generate!
errorcase "BY";            # Blank value line.
errorcase "BZ";            # Genloop with no arguments!
errorcase "CA";            # 'Type' argument value invalid.
errorcase "CB";            # 'Init' argument value invalid.
errorcase "CC";            # 'Initall' argument value invalid.
errorcase "CD";            # 'Endtouch' argument value invalid.
errorcase "CE";            # 'Report' argument value invalid.
errorcase "CF";            # 'Noreplacement' argument value invalid.
errorcase "CG";            # 'Report' argument value invalid.
errorcase "CH";            # 'Singleline' argument value invalid.
errorcase "CI";            # Blank stored line.
errorcase "CJ";            # First non-whitespace line is not 'begin genesis'.
errorcase "CK";            # A line is outside the global/program/features section.
errorcase "CL";            # More than one global.
errorcase "CM";            # Varlist was not initiated yet.
errorcase "CN";            # Invalid stored line.
errorcase "CO";            # feature has recursion. A->A
errorcase "CP";            # feature has circular recursion.  A->B->A
errorcase "CQ";            # Varlist was not initiated yet for add.
errorcase "CR";            # Varlist was not initiated yet for remove.
errorcase "CS";            # Varlist was not init yet for add all.
errorcase "CT";            # Varlist was not init yet for remove all.
#errorcase "CU";           # Testcase not possible yet
errorcase "CV";            # Varlist needs an argument value.
#errorcase "CW";           # Testcase not possible yet
errorcase "CX";            # Genif with no arguments!
errorcase "CY";            # Genelsif with no arguments!
errorcase "CZ";            # Feature cannot be named "global".
errorcase "DA";            # Inconsistency. Either give probabilities to every entry in this distribution, or use no probabilities at all.
errorcase "DB";            # Inconsistency. Either give probabilities to every entry in this distribution, or use no probabilities at all.
errorcase "DC";            # Probabilities not between 99 and 101.
errorcase "DD";		       # Reference found, no feature has this Genesis name.
errorcase "DE";            # String has characters. Put it around quotes or fix the reference.
#subsumed by error DH1, cant pass in a string like that anymore.
errorcase "DF" "DH1";      # Probably an endless loop of replacement.
errorcase "DG";            # Varlist source does not exist.
errorcase "DH1";           # Reference found but does not exist in this scope.
errorcase "DH2";		   # Reference found but does not exist in this scope.
errorcase "DI";            # Not a proper argument for a varlist
errorcase "DJ";            # Value exists but has no sampled value yet.
errorcase "DK";            # Value exists but has no sampled value yet.
errorcase "DK1";           # Value exists but has no sampled value yet.
# errorcase "DL";            # Either infinite recursion or an error with the compiler.
errorcase "DM";            # The LHS value does not exist.
errorcase "DN";            # Distribution in genmath statement does not exist.
errorcase "DO";            # Dist for this value does not exist to enum.
errorcase "DP" "Q";        # No number used for array size declaration.
errorcase "DQ";            # No number used for array value reference.
errorcase "DR";            # Number used for non-array value.
errorcase "DS";            # Number out of bounds: over.
errorcase "DS2" "DS";      # Number out of bounds: over.
errorcase "DT";            # Number out of bounds: under (-1).
errorcase "DT2" "DT";      # Number out of bounds: under.
errorcase "DU";            # No index brackets used for array value.
errorcase "DV";            # Varlist's Value arg not a number.
errorcase "DW";            # Number for value arg is out of bounds: over.
errorcase "DX";            # Number for value arg is out of bounds: under.
errorcase "DY";            # Value arg needs an index.
errorcase "DZ";            # Real argument invalid.
fi

if [ $WarFlag == 1 ]; then
echo "Working on Warning Testcases" 
warncase "WB";            # "Value", "Done at end of feature?
warncase "WC";            # "Varlist", "Done at end of feature?
warncase "WD";            # "Variable", "Done at end of feature?
warncase "WE";            # "Distribution", "Done at end of feature?
warncase "WF";            # Empty Distribution.
warncase "WG";            # Distribution declared but not used.
warncase "WH";            # No program segment.
warncase "WJ";            # No global segment.
warncase "WK";            # Code snippet in global section will not be used.
warncase "WL";            # Code snippet in program section will not be used.
warncase "WDD";           # Sampling from an Empty Varlist.
warncase "WDD2" "WDD";    # errorvarlistprogram
warncase "WDD3" "WDD";    # errorvarlistglobal
warncase "WDD4" "WDD";    # emptyvarlistfailure
warncase "W1";            # emptyvarlistfailure
warncase "W2" "W1";       # emptyvarlistfailure

fi


echo "Normal Case Successful: $CorrectOuts";
echo "Normal Case Errors: $InCorrectOuts";
echo "Correct Errors: $CorrectErrs";
echo "Incorrect Errors: $InCorrectErrs";
echo "Correct Warnings: $CorrectWarns";
echo "Incorrect Warnings: $InCorrectWarns";