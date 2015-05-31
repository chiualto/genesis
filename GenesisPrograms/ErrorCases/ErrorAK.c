begin genesis

feature test0
	TEST0 - should output CCC RRR
	value zero sample dist0
	genelse
		DDD
	end
	RRR
	
end

generate 1 with dist0 = {0}, dist1 = {1}, dist2 = {2}
end genesis

__kernel
void kernel_mc02_orig(unsigned int outer_tc, unsigned int inner_tc, __global __volatile float *arr){

	${test0}
 
}
