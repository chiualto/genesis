begin genesis
	global
	end
	
	program
		varlist foo[5] type(int)
	end

	feature access
		variable dest from foo
		value location sample arraylocations
		${dest} = arr[${location}];
	end

	generate 5 with arraylocations = {1:10}
end genesis

__kernel
int program(__global __volatile float *arr){

	int cvariable = 5;

	${access}	

}
