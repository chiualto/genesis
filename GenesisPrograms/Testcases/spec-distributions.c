#distributions
#distinfeature

begin genesis
	global
		value globalvalue1 sample dist2
		distribution globaldist={a}
		value globalvalue2 sample globaldist
	end
	
	program
		value programvalue1 sample dist2
		distribution programdist={b}
		value programvalue2 sample programdist
		
		value test5value sample dist1
		distribution test5dist={5:${test5value}+5}
	end

	feature test1
		TEST1: Multipart Distribution: One should be 1, one should be 5
		value CSE1 sample dist1
		distribution insnsdist3={1:${CSE1}; 5}
		value stride1, stride3 sample insnsdist3 noreplacement(1) report(1)
		${stride1} ${stride3}
	end

	feature test2
		TEST2: Distribution ordering test: 2 values should be 1-5 and not 15-20
		last value should be 15-20 and not 1-5
		value lowerlimit = 1
		value upperlimit = 5
		distribution insnsdist={${lowerlimit}:${upperlimit}}
		value stride2 sample insnsdist
		genmath lowerlimit = 15
		genmath upperlimit = 20
		value stride3 sample insnsdist
		distribution insnsdist2={${lowerlimit}:${upperlimit}}
		value stride4 sample insnsdist2
		${stride2} ${stride3}
		${stride4}
	end
	
	feature test3
		TEST3: Global and Program dists
		Global value, a, sampled once all programs: 
		${globalvalue1} ${globalvalue2}
		Program value, b, sampled once per program:
		${programvalue1} ${programvalue2}
	end
	
	feature test4
		TEST4: Add and remove: the dist is 1,2,4,5,10
		distribution addremdist={1:5}
		add 10 to addremdist
		remove 3 from addremdist
		value stride4 sample addremdist
		${stride4}
	end
	
	feature test5
		TEST5: Distribution with math: ether 5 or 6 outputted
		value stride5 sample test5dist
		${stride5}
	end
	

	generate 5 with dist1 = {1}, dist2 = {1:100}
	
end genesis

    ${test1}

	${test2}

	${test3}
	
	${test4}
	
	${test5}