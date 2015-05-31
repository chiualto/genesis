begin genesis
	global
		value numvars sample numvardist
		varlist temp[${numvars}]
	end

	feature epoch
		value bound sample compdist report(1)
		value arraytest[10] sample dist1 report(1)
		genloop test:1:bound:2
			genif 3==test
				${computation}
			end
			${access}
		end

end genesis



__kernel
void kernel_mc02_orig(unsigned int outer_tc, unsigned int inner_tc, __global __volatile float *arr){

	for (unsigned int it00 = get_local_id(0); it00 < outer_tc; it00 += get_local_size(0)) {
		for (unsigned int it01 = get_local_id(1); it01 < inner_tc; it01 += get_local_size(1)) {
            ${epoch}
        }
	}
 
}
