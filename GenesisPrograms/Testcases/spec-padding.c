begin genesis
	global
	end
	
	program
		value numepochs sample epochdist report(1)
		value numvars sample numvardist

		varlist temp[5] type(float)
		varlist foo[${numvars}] type(int)
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
		value offset sample dist2 report(1)
		${varj} = arr[${stride1}*it00 + ${stride2}*it01 + ${offset}];
	end

	feature epoch
		value numcomps sample compdist report(1)
		${computation[${numcomps}]}
		${access}
	end

	feature intpadding
		value numpad sample paddingdist report(1)
		int padding[${numpad}];
	end

	feature structurewithpadding
		struct padstruct {
			char c1;
			short s1;
			char c2;
			long l1;
			char c3;
		};
	end

	feature declarestructs
		value loopfactor sample loopdist report(1)
		genloop loopiter:1:${loopfactor}
			${structurewithpadding}
			genif ${loopfactor}!=${loopiter}
				${intpadding}
			end
			
		end
	end

	generate 5 with dist1 = {1:10},numvardist = {2:8},epochdist = {1:5},compdist = {1:5},dist2 = {1:10;;real},loopdist = {5:10},paddingdist={1:4}
end genesis



__kernel
void kernel_mc02_orig(unsigned int outer_tc, unsigned int inner_tc, __global __volatile float *arr){

	${declarestructs}
	
	for (unsigned int it00 = get_local_id(0); it00 < outer_tc; it00 += get_local_size(0)) {
		for (unsigned int it01 = get_local_id(1); it01 < inner_tc; it01 += get_local_size(1)) {
            ${epoch[5]}
        }
	}
 
}
