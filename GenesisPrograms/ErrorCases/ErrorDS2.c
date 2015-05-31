 begin genesis
	global
	end
	
	program
		value test sample dist1
		value arraytest[${test}] sample dist1
	end
	
	feature bleh
		${test}
		genloop i:0:${test}
			${i}: ${arraytest[${i}]}
		end
	end
	
	generate 3 with dist1 = {1:10}
end genesis

${bleh}