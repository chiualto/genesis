begin genesis
global
end

feature epoch
	varlist foo[5]
	variable test from foo
	${test}
end

generate 1 with epochdist = {1:4}

end genesis

            ${epoch}
 