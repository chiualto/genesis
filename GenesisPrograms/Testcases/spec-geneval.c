begin genesis

	///Genesis comment

	global
	end

	program
		varlist temp[5] type(float)
	end
	
	feature test1
		TEST1:
		variable varj from temp report(1)
		value stride1 sample dist1 report(1)
		geneval(${stride1})
	end
	
	feature test2
		TEST2: geneval differences. 1 is plain, 2 is evaled, 3 is escaped:
		1+2
		geneval(1+2)
		\geneval(1+2)
	end

	generate 5 with dist1 = {varj}
end genesis

${test1}

${test2}