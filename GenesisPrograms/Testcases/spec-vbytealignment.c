begin genesis

	global
	end

	program
		value numepochs sample epochdist report(1)
		value numvars sample numvardist
		distribution varsample = {1:${numvars}}
		value bytealign sample vbadist
	end

	feature vardeclare
		genloop loopvar:1:${numvars}
			float temp${loopvar} = 0;
			genif ${bytealign}==8
				float padding${loopvar} = 0;
			end
			genif ${bytealign}==12
				float paddingA${loopvar} = 0;
				float paddingB${loopvar} = 0;
			end
			genif ${bytealign}==16
				float paddingA${loopvar} = 0;
				float paddingB${loopvar} = 0;
				float paddingC${loopvar} = 0;
			end
		end
	end


	feature computation
		value dest sample varsample
		value source1 sample varsample
		value source2 sample varsample
		value source3 sample varsample
		temp${dest} = temp${source1} * temp${source2} + temp${source3};
	end

	feature access
		value varj sample varsample
		value stride1 sample dist1 report(1)
		value stride2 sample dist1 report(1)
		value offset sample dist2 report(1)
		temp${varj} = arr[${stride1}*it00 + ${stride2}*it01 + ${offset}];
	end

	feature epoch
		value numcomps sample compdist report(1)
		${computation[${numcomps}]}
		${access}
	end

	feature epochs
		${epoch[${numepochs}]}
	end

	generate 5 with dist1 = {1:10},numvardist = {2:8},epochdist = {1:5},compdist = {1:5},dist2 = {1:10;;real}, vbadist = {4; 8; 12; 16}
end genesis



__kernel
void kernel_mc02_orig(unsigned int outer_tc, unsigned int inner_tc, __global __volatile float *arr){

	${vardeclare}

	for (unsigned int it00 = get_local_id(0); it00 < outer_tc; it00 += get_local_size(0)) {
		for (unsigned int it01 = get_local_id(1); it01 < inner_tc; it01 += get_local_size(1)) {
            ${epochs}
        }
	}
 
}
