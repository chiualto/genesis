begin genesis
	global
		varlist temp[5] type(float) init(4) endtouch(0)
	end
	
	program
		varlist bsome[2] type(float)
	end
	
	
	feature test2
		Test2 - Sample from program list of 2 until 1 left.
		should result in 1 failed file since we try to Test2 twice
		variable vara from bsome
		remove vara from bsome
		variable varb from bsome
		The two vars are vara and varb
		End of Test
	end

	generate 1 with dist1 = {1:10},numvardist = {2:8},epochdist = {1:5},compdist = {1:5},dist2 = {1:10;;real}
end genesis

	${test2}
	
	${test2}