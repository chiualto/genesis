begin genesis

feature test1
	test1 - should output DDD RRR
	value one sample dist1
	genif ${one}=?0
		CCC
	genelse
		DDD
	end
	RRR
end


generate 1 with dist1 = {1}
end genesis

	${test1}
}
