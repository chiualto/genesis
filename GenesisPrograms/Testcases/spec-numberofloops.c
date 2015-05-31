begin genesis
	global
	end
	
	geninclude gen_c.glb
	
	program
		value numepochs sample epochdist report(1)
		value numvars sample numvardist
		value numloops sample loopdist
		varlist temp[${numvars}]
		varlist foo[${numvars}]
	end

	feature computation 
		variable dest from temp
		variable source1 from temp
		variable source2 from temp
		variable source3 from temp
		${grabspacingdef}${dest} = ${source1} * ${source2} + ${source3};
	end

	feature access
		variable varj from temp
		value offset sample dist1 report(1)
		${grabspacingdef}varj = arr[${insidearray} ${offset}];
	end

	feature singleline(1) insidearray
		genloop test3:0:${numloops}
			${insidestride(${test3})} + 
		end
	end

	feature insidestride (iterator)
		value stride1 sample dist1 report(1)
		${stride1}*it${iterator}
	end

	feature epoch
		value numcomps sample compdist report(1)
		${computation[${numcomps}]}
		${access}
	end

	feature loopheader (numloops)
		genloop test:0:${numloops}
			${singleloop(${test})}
		end
	end

	feature loopend (numloops)
		genloop test2:${numloops}:0:-1
			${singleend(${test2})}
		end
	end

	feature singleline(1) grabspacingdef
		${grabspacing(${numloops})}
	end

	feature singleline(1) grabspacing (test)
		genloop test3:1:${test}
			${gentab}
		end
	end

	feature singleline(1) singleloop (test)
		${grabspacing(${test})}
		for (unsigned int it${test} = get_local_id(${test}); it${test} < outer_tc; it${test} += get_local_size(${test})) {
	end

	feature singleline(1) singleend (test)
		${grabspacing(${test})}
		}
	end

	feature nestedloop
		${loopheader(${numloops})}
			${epoch[${numepochs}]}
		${loopend(${numloops})}
	end

	generate 4 with dist1 = {1:10},numvardist = {2:8},epochdist = {1:5},compdist = {1:5},loopdist = {1:4}
end genesis



__kernel
void kernel_mc02_orig(unsigned int outer_tc, unsigned int inner_tc, __global __volatile float *arr){
	${nestedloop}
}
