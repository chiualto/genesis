begin genesis
	global
	end
	
	program
		varlist foo[3]
		varlist bar[5] name(temp)
	end

	feature access
		variable dest from foo
		value location sample arraylocations
		${dest} = arr[${location}];
		
		${foo(value)}
		${foo(2)}
		${foo}
		${foo(name)}
		${foo(size)}
		${foo[1]}
		${foo[2]}
		
		
		${bar(1)}
		${bar(2)}
		${bar}
		${bar(name)}
		${bar(size)}
	end

	generate 5 with arraylocations = {2:10}
end genesis

__kernel
int program(__global __volatile float *arr){

	${access}
	
}
