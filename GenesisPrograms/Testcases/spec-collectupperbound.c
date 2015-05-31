begin genesis

	global
	end

	program
		value numepochs sample epochdist report(1)
		value numvars sample numvardist
		value outertc sample bound report(1)
		value innertc sample bound report(1)
		varlist temp[${numvars}]
		varlist foo[${numvars}]
	end

	feature computation 
		variable dest from temp
		variable source1 from temp
		variable source2 from temp
		variable source3 from temp
		${dest} = ${source1} * ${source2} + ${source3};
	end

	feature access
		variable varj from temp
		value stride1 sample dist1 report(1)
		value stride2 sample dist1 report(1)
		value offset sample dist1 report(1)
		${varj} = arr[${stride1}*it00 + ${stride2}*it01 + ${offset}];
	end

	feature epoch
		value numcomps sample compdist report(1)
		${computation[${numcomps}]}
		${access}
	end


	feature loop
		value linterchange sample dist4
		genif ${linterchange}==0
			for (unsigned int it00 = get_local_id(0); it00 < ${outertc}; it00 += get_local_size(0)) {
				for (unsigned int it01 = get_local_id(1); it01 < innertc; it01 += get_local_size(1)) {
					${epoch[${numepochs}]}
				}
			}
		end
		genif ${linterchange}==1
			for (unsigned int it01 = get_local_id(0); it01 < ${innertc}; it01 += get_local_size(0)) {
				for (unsigned int it00 = get_local_id(1); it00 < outertc; it00 += get_local_size(1)) {
					${epoch[${numepochs}]}
				}
			}
		end
	end

	generate 5 with dist1 = {1:10},numvardist = {2:8},epochdist = {1:5},compdist = {1:5},dist4 = {0:1},bound={1:50}
end genesis

__kernel
void kernel_mc02_orig(__global __volatile float *arr){
	${loop}
}
