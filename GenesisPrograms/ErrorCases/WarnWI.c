begin genesis
	program
		value tester1 sample arraylocations report(1)
		value location1 enumerate arraylocations report(1)
		value location2 enumerate arraylocations report(1)
		value tester2 sample arraylocations report(1)
	end

	feature access
		SAME THROUGH SET: tester1 
		ENUMERATED: location1
		ENUMERATED: location2
		RANDOM: tester2
	end

	generate 8 with arraylocations = {1:3}
end genesis

__kernel
int program(__global __volatile float *arr){

	${access}
	
}
