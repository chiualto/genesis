begin genesis
global
	value numepochs sample epochdist report(1)
	value numvars sample numvardist
	varlist temp[${numvars}]
end

feature computation 
	variable dest from temp
	variable source1 from temp
	variable source2 from temp
	variable source3 from temp
	${dest} = ${source1} * ${source2} + ${source3};
end

feature access (stride1,stride2,offset)
	variable varj from temp
	${varj} = arr[${stride1}*it00 + ${stride2}*it01 + ${offset}];
end

feature epoch
	value numcomps sample compdist
	genmath numacomps=${numcomps}+1
	${computation[${numcomps}]}
	${access(1,2,3)}
end

feature epochs
	${epoch[5]}
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
