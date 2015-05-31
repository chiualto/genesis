begin genesis
	global
	end
	
	program
	end

	generate 5 with arraylocations = {1:10{+2}; 11:20{40,+3}}
end genesis

__kernel
int program(__global __volatile float *arr){

}
