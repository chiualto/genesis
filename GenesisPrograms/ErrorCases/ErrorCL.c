begin genesis

	global
		value numvars2 sample dist1	
	end
	
	global
		value numvars4 sample dist1	
	end
	
	
	feature computation
		value numvars3 sample dist1	
		SAME ALL PROGRAMS numepochs
		SAME ALL PROGRAMS numvars
		DIFFERENT PER PROGRAM numvars2
		DIFFERENT IN PROGRAM numvars3
	end

	generate 3 with dist1 = {1:100},numvardist = {1:10},epochdist = {1:20}
end genesis

scoping:
    computation[2]