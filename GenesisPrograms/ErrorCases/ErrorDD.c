begin genesis

global
value dummyval sample epochdist report(1)
end

feature foo
	LALA
end

feature bar
    ${foo[5]}
end

generate 1 with epochdist = {1:4}

end genesis

${bar[${doesntexist}]}
