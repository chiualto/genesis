begin genesis

global
value numepochs sample epochdist report(1)
value numvars sample numvardist
varlist temp[5] type(float)
varlist foo[${numvars}] type(int)
end

feature computation 
	ABC
end

feature access
	DEF
end

feature epoch
	value numcomps sample compdist report(1)
	${computation[${numcomps}]}
	${access}
end

generate 5 with dist1 = {1:10},numvardist = {2:32{*2}},epochdist = {1:5},compdist = {1:5},dist2 = {1:10}
end genesis

${epoch[${numepochs}]}