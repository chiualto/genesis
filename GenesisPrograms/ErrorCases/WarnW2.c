begin genesis

	global
	end
	
	program
	end

	feature test1
		Test1: 1 in 3 have a bad assert
		value numcomps sample compdist report(1)
		genassert ${numcomps}!=3
		numcomps = ${numcomps}
	end


	generate 10 with compdist = {1:3}
end genesis

${test1}
