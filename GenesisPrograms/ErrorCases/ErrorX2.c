begin genesis

	global
		value numepochs sample epochdist report(1)
	end
	
	program
		value numepochs sample epochdist report(1)
	end

	generate 5 with dist1 = {1:10},numvardist = {2:8},epochdist = {1:5},compdist = {1:5},dist2 = {1:10;;real}
end genesis


	${testers}
	${epoch}

