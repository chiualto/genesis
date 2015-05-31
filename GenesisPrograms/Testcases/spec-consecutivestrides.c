begin genesis
	global
		varlist temp[3]
		varlist foo[2]
	end
	
	program
		value numvars sample numvardist
	end

	feature computation 
		variable dest from temp
		variable source1 from temp
		variable source2 from temp
		variable source3 from temp
		${dest} = ${source1} * ${source2} + ${source3};
	end

	feature access
		value stride1 sample dist1 report(1)
		value stride2 = ${stride1} report(1)
		${varj} = arr[${stride1}*it00 + ${stride2}*it01 + ${offset}];
	end

	feature epoch
		value numeps sample epochdist report(1)
		value numcomps1 sample compdist report(1)
		value numcomps2 sample compdist report(1)
		value numcomps3 sample compdist report(1)
		value numcomps4 sample compdist report(1)
		value numcomps5 sample compdist report(1)
		value offset1 sample dist1 report(1)
		value offset2 = ${offset1}+1 report(1)
		value offset3 = ${offset1}+2 report(1)
		value offset4 = ${offset3}+1 report(1)
		value offset5 = ${offset1}+4 report(1)
		variable varj1 from temp report(1)
		variable varj2 = ${varj1}+1 report(1)
		variable varj3 = ${varj1}+2 report(1)
		variable varj4 = ${varj3}+1 report(1)
		variable varj5 = ${varj1}+4 report(1)
		genif ${numeps}==1
			${computation[${numcomps1}]}
			${varj1} = arr[${offset1}];
		end
		genif ${numeps}==2
			${computation[${numcomps1}]}
			${varj1} = arr[${offset1}];
			${computation[${numcomps2}]}
			${varj2} = arr[${offset2}];
		end
		genif ${numeps}==3
			${computation[${numcomps1}]}
			${varj1} = arr[${offset1}];
			${computation[${numcomps2}]}
			${varj2} = arr[${offset2}];
			${computation[${numcomps3}]}
			${varj3} = arr[${offset3}];
		end
		genif ${numeps} == 4
			${computation[${numcomps1}]}
			${varj1} = arr[${offset1}];
			${computation[${numcomps2}]}
			${varj2} = arr[${offset2}];
			${computation[${numcomps3}]}
			${varj3} = arr[${offset3}];
			${computation[${numcomps4}]}
			${varj4} = arr[${offset4}];
		end
		genif ${numeps}==5
			${computation[${numcomps1}]}
			${varj1} = arr[${offset1}];
			${computation[${numcomps2}]}
			${varj2} = arr[${offset2}];
			${computation[${numcomps3}]}
			${varj3} = arr[${offset3}];
			${computation[${numcomps4}]}
			${varj4} = arr[${offset4}];
			${computation[${numcomps5}]}
			${varj5} = arr[${offset5}];
		end
	end


	generate 5 with dist1 = {1:10},numvardist = {2:8},epochdist = {1:5},compdist = {1:5}
end genesis



__kernel
void kernel_mc02_orig(unsigned int outer_tc, unsigned int inner_tc, __global __volatile float *arr){

	for (unsigned int it00 = get_local_id(0); it00 < outer_tc; it00 += get_local_size(0)) {
		for (unsigned int it01 = get_local_id(1); it01 < inner_tc; it01 += get_local_size(1)) {
            ${epoch}
        }
	}
 
}
