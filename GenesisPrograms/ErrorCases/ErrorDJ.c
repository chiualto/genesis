begin genesis
	global
	end
	
	program
		varlist foo[3]
	end

	feature access
		variable dest from foo
		value location
		${dest} = arr[${location}];
	end

	generate 5 with arraylocations = {2:10}
end genesis

__kernel
int program(__global __volatile float *arr){

	${access}
	
}
