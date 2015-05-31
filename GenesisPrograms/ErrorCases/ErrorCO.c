begin genesis
	global
	end
	
	program
	end

	feature loop
		${loop}
	end

	generate 5 with dist1 = {1:10},dist4 = {0:1}
end genesis

__kernel
void kernel_mc02_orig(unsigned int outer_tc, unsigned int inner_tc, __global __volatile float *arr){

	${loop}
 
}
