begin genesis

	global
	end

	program
		value numepochs sample epochdist report(1)
		value numvars sample numvardist
		varlist temp[5]
		varlist foo from temp
	end

	feature computation 
		variable source1,source2 from temp ; source3 from temp
		add source1, source2 to foo ; source3 to foo
		variable dest from foo
		remove dest from foo
		${dest} = ${source1} * ${source2} + ${source3};
	end

	feature access
		variable varj from foo
		value stride1 , stride2 sample dist1 ;  offset sample dist1
		${varj} = arr[${stride1}*it00 + ${stride2}*it01 + ${offset}];
		remove varj from foo
	end

	feature epoch
		value numcomps sample compdist report(1)
		${computation[${numcomps}]}
		${access}
	end

	feature epochs
		${epoch[${numepochs}]}
	end

	generate 5 with dist1 = {1:10},numvardist = {2:8},epochdist = {1:5},compdist = {1:5}
end genesis



__kernel
void kernel_mc02_orig(unsigned int outer_tc, unsigned int inner_tc, __global __volatile float *arr){

	for (unsigned int it00 = get_local_id(0); it00 < outer_tc; it00 += get_local_size(0)) {
		for (unsigned int it01 = get_local_id(1); it01 < inner_tc; it01 += get_local_size(1)) {
            ${epochs}
        }
	}
 
}
