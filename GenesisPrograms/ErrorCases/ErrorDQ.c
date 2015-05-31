begin genesis
	global
	end
	
	program
		value test[2] sample dist1
	end
	
	feature test1		
		${test[]}
	end
		
	generate 3 with dist1 = {1:100}
end genesis

    ${test1[2]}
