begin genesis

	global
	end
	
	program
		value abc sample dist1
	end

	feature access1
		${grabspacingdef} varj = arr[${insidearray} offset];
	end

	feature access2
		varj ${grabspacingdef} = arr[${insidearray} offset];
	end

	feature singleline(1) insidearray
		BBB ${abc}
	end

	feature singleline(1) grabspacingdef
		AAA ${abc}
	end

	generate 1 with dist1 = {2:8}
end genesis

void kernel_mc02_orig(unsigned int outer_tc, unsigned int inner_tc, __global __volatile float *arr){
	${access1}
	${access2}
}
