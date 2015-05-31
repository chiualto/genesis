begin genesis
	global
	end
	
	program
		value test[2] sample dist1 report(1)
		value arraytest[10] sample dist1 report(1)
		value genmathTest[2]
		genmath genmathTest[1] = 3
		value arraysize sample dist1
		value sizearray[${arraysize}] sample dist1
	end
	
	feature test1
		TEST1: Arrays with genmaths
		test0 test1
		${test[0]} ${test[1]}
		
		making them equal (test0=test1)
		genmath test[0]=${test[1]}
		
		results in
		${test[0]} ${test[1]}
		
		${genmathTest[1]}
	end
		
	feature test2
		TEST2: Unknown Bounds
		Array size is: {arraysize}
		genloop i:0:${arraysize}-1
			${i} is ${sizearray[${i}]}
		end
	end
			
	generate 3 with dist1 = {1:100}
end genesis

    ${test1[2]}
	
	${test2}