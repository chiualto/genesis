begin genesis
global
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

feature access (stride1)
	variable varj from temp
	value stride2 sample dist1 report(1)
	value offset sample dist1 report(1)
	${varj} = arr[${stride1}*it00 + ${stride2}*it01 + ${offset}];
end

feature epoch
	value bound sample compdist report(1)
	value arraytest[10] sample dist1 report(1)
	genloop test:1:bound:2
		QQQ arraytest[test] WWW
		
		${computation}
		genif test==1
			AAA
			
		end
		genif 3==test
			${computation}[test]
			${access}(${test})
			BBB
			
		end
		${access}(${test})
end




__kernel
void kernel_mc02_orig(unsigned int outer_tc, unsigned int inner_tc, __global __volatile float *arr){

	for (unsigned int it00 = get_local_id(0); it00 < outer_tc; it00 += get_local_size(0)) {
		for (unsigned int it01 = get_local_id(1); it01 < inner_tc; it01 += get_local_size(1)) {
            ${epoch}
        }
	}
 
}
