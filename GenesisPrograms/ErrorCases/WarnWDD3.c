#should result in first one successful, 2nd file fails

begin genesis
	global
		varlist temp[5] type(float) init(4) endtouch(0)
		varlist bsome[2] type(float)
	end
	
	program
		value numvars sample numvardist
		varlist foo[${numvars}] type(int) endtouch(1)
		varlist bar[5] type(random) init(0,2,3) endtouch(0)
		varlist another[${numvars}] type(char) endtouch(0) initall(1)
	end
	
	
	feature test2
		Test2 - Sample from program list of 2 until 1 left.
		should result in first one successful, 2nd file fails
		variable vara from bsome
		remove vara from bsome
		variable varb from bsome
		The two vars are vara and varb
		End of Test
	end

	generate 2 with numvardist = {2:8}
	end genesis

	${test2}