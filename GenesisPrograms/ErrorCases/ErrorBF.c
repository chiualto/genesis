begin genesis

global
value numepochs sample epochdist report(1)
varlist temp[abd]
end

feature epoch
	variable source2 from temp
	lala;
end

generate 1 with epochdist = {1:4}

end genesis


${epoch[${numepochs}]}