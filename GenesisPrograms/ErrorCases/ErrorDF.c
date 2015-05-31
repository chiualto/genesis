begin genesis
	global
	end
	
	program
	end

	feature loopheader (numloops)
		genloop test:0:${numloops}
			TEST
		end
	end

	feature nestedloop
		#Numloops doesnt exist, it passes in the string
		${loopheader(${numloops})}
	end

	generate 1
end genesis



__kernel
void kernel_mc02_orig(unsigned int outer_tc, unsigned int inner_tc, __global __volatile float *arr){
	${nestedloop}
}
