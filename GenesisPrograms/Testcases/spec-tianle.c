begin genesis
	global
	end
	
	program
		value numepochs sample epochdist report(1)
		value numvars sample numvardist
		value tempinit sample initdist
		value fooinit sample initdist
		value start[2] sample startdist
		value end[2] sample startdist
		varlist startval[2] type(int) init(${start[1]},${start[2]})
		varlist endval[2] type(int) init(${start[1]}+${end[1]},${start[2]}+${end[2]})
		varlist stepval[2] type(int) initall(1)
		varlist converttemp[1] type(int) init(${tempinit})
		varlist temp[5] type(int) init(converttemp1)
		varlist convertfoo[1] type(int) init(${fooinit})
		varlist foo[5] type(int) init(convertfoo1)
	end 

	feature computation 
		variable dest from temp
		variable source1 from temp
		variable source2 from temp
		${dest} = ${source1} + ${source2};
	end

	feature access
		printf("%f\n",temp1);
	end

	feature epoch
		value numcomps sample compdist report(1)
		${computation[${numcomps}]}
		${access}
	end

	feature code
		{
		for (unsigned int it00 = ${startval[1]}; it00 < ${endval[1]}; it00 += ${stepval[1]}) {
			printf("=====================it00:%d=====================\n",it00);
			for (unsigned int it01 = ${startval[2]; it01 < ${endval[2]}; it01 += ${stepval[2]}) {
				printf("it01:%d\n",it01);
				${epoch[5]}
			}
		}
	end
	

	generate 5 notouch with numvardist = {2:8},epochdist = {1:5},compdist = {1:5},initdist= {0:14}, startdist={0:99}
end genesis

#include "/usr/include/stdio.h"
int program(int argc, char *argv[]){
	#pragma hicuda kernel matrixMul tblock(1,1) thread(4,4)
	${code}
	#pragma hicuda kernel_end
	}
 
}
