#contains a loop
#test1
#	-sampled bounds
#	-loop increment of 2
#	-loop variable used as a parameter inside an if

#test2 tests while loop
#test3 tests varlists inside while loop inequality


begin genesis

	global
	end
	
	program
		value test2s sample compdist
		varlist test3var[5] type(float)
	end

	feature passedfeature (passed)
		In this feature, we Passed in: ${passed}
	end

	feature test1
		TEST1 - Sampled bounds, increment of 2, iter used as argument
		value bound sample compdist report(1)
		value arraytest[10] sample dist1 report(1)
		
		Bound: ${bound}
		genloop iter:0:${bound}-1:2
			Iter: ${iter}
			Array at Iter: ${arraytest[${iter}]}
			genif ${iter}==0
				This is the first Iter.
			genelsif 2==${iter}
				This is the 2nd Iter (Iter=2 due to 2 increment).
				Passing in Iter for just Iter=2 (in genif).
				${passedfeature(${iter})}
				End Iter=2.
			end
			Passing in Iter for all iterations.
			${passedfeature(${iter})}
			
		end
		End of Test
	end

	feature test2
		TEST2 - Sample until 2 is sampled.
		First Sample: ${test2s}
		genloop ${test2s}!=2
			value test2s2b sample compdist
			genmath test2s = ${test2s2b}
			Sampling in the loop: ${test2s}
		end
		Final sample: ${test2s}
		End of Test
	end

	feature test3
		Test3 - Sample from list of 5 until 1 left.
		genloop ${test3var}>1
			variable varsam from test3var
			Pulled ${varsam}
			remove varsam from test3var
		end
		
		variable vark from test3var
		${vark} is the last var reprograming
		End of Test
	end



	generate 5 with dist1 = {2:10},compdist = {1:10}
end genesis

${test1}

${test2}

${test3}