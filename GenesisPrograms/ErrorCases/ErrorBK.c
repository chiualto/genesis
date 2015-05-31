begin genesis

global
	varlist temp[5]
end

	feature epoch
		variable varj from temp report(1)
		distribution insnsdist3={${CSE1}:1}
		value stride1, stride3, stride4 sample insnsdist3 noreplacement(1)

		value CSE1 sample {2}
		${stride1} stride3 stride4 stride5
	end


	generate 5 with dist1 = {1:10}
end genesis



__kernel
void kernel_mc02_orig(unsigned int outer_tc, unsigned int inner_tc, __global __volatile float *arr){

	for (unsigned int it00 = get_local_id(0); it00 < outer_tc; it00 += get_local_size(0)) {
		for (unsigned int it01 = get_local_id(1); it01 < inner_tc; it01 += get_local_size(1)) {
			${epoch}
		}
	}
 
}
