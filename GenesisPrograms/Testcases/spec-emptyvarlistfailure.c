begin genesis
	global
	end
	
	program
		varlist temp[5] type(float)
	end

	feature epoch
		1 in 5 have a remove all
		value numcomps sample compdist report(1)
		The sampled value is numcomps
		genif ${numcomps} == 5
			remove all from temp
		end
		variable varj from temp report(1)
		The sampled var is ${varj}
	end


	generate 5 with compdist = {1:5}
end genesis

${epoch[5]}
