begin genesis

	geninclude gen_c.glb

	global
		varlist temp[5] type(float) init(4) endtouch(0)
	end
	
	program
		value numvars sample numvardist
		varlist foo[${numvars}] type(int) endtouch(1)
		varlist bar[5] type(random) init(0,2,3) endtouch(0)
		varlist another[${numvars}] type(char) name(temp) endtouch(0) initall(1)
		varlist bsome[2] type(float)
	end
	
	feature test1
		varlist asome[2] type(float)
		Test1 - Sample from list of 2 until 1 left. This test is done twice.
		variable vara from asome
		remove vara from asome
		variable varb from asome
		The two vars are vara and varb
		End of Test
	end
	
	feature test2
		Test2 - Sample from program list of 2 until 1 left.
		variable vara from bsome
		remove vara from bsome
		variable varb from bsome
		The two vars are vara and varb
		End of Test
	end
	
	feature test3
		Test2 - Various arguments in varlist references.
		${foo}
		${foo(name)}
		${foo(size)}
		${foo[1]}
		
		${foo(value)[2]}

		${bar}
		${bar(name)}
		${bar(size)}
		${bar[1]}
		${bar[2]}
		
		${bar(value)[2]}
	end

	generate 1 with numvardist = {2:8}
end genesis

__kernel
void kernel_mc02_orig(unsigned int outer_tc, unsigned int inner_tc, __global __volatile float *arr){

	${varlistDeclare(int, bar)}
	${varlistDeclare(int, another)}

	${test1}
	
	${test1}
	
	${test2}
	
	${test3}
	
}