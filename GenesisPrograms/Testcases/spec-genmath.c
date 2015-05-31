begin genesis
	
	global
		value globalValue
		genloop iter:1:5
			genmath globalValue = ${iter}
		end
	end
	
	program
		value programValue sample {0}
		value programValue2
		genif ${programValue}==1
			genmath programValue2 sample {2:3}
		genelse
			genmath programValue2 sample {4:5}
		end
		value programValue3 sample {1}
		value programValue4
		genif ${programValue3}==1
			genmath programValue4 sample {2:3}
		genelse
			genmath programValue4 sample {4:5}
		end
		
		distribution badDist={1}
		value buggedValue
		genmath buggedValue sample {1:3}
	end

	feature test1
		TEST1: genmath
		value i_symbol = i
		genmath i_symbol = a
		s ${i_symbol} s
	end

	feature test2
		TEST2: locality
		value loops=0
		// C1 (t2: 0): ${loops}
		${subt2}
		// C3 (t2:0): ${loops}
	end

	feature subt2
		value loops=0
		genmath loops=${loops} + 1
		// C2 (st2: 1): ${loops}
	end
	
	feature test3
		TEST3: distance
		value loops=0
		genloop i:1:5
			genif 1==1
				genmath loops=${loops} + 1
			end
			// In genloop: ${loops}
		end
		// Final result: ${loops}
	end
	
	feature test4
		TEST4: Inited value 
		value location
		genmath location = a
		arr[${location}];
	end
	
	feature test5
		TEST5: Global and Program outputs: 4/5 and 2/3 and 5
		${programValue2} 
		${programValue4}
		${globalValue}
	end
	
	feature test6
		TEST6: This was a bug prior to 1.01.200
		buggedValue  ${buggedValue}
	end

generate 2
end genesis

	${test1}

	${test2}
	
	${test3}
	
	${test4}
	
	${test5}