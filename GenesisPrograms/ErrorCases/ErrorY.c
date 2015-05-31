begin genesis

feature access
	value stride1,stride4 sample dist1 noreplacement(1) 
	${stride1} ${stride4};
end

generate 5 with dist1 = {1}
end genesis

${access}
   