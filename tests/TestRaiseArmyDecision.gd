extends TestCase
class_name TestRaiseArmyDecision

func test_should_raise_examples_yes_cases() -> void:
	# yes, we have not many armies, many regions and good amount of recruits and gold
	assert_true(RaiseArmyDecision.should_raise_army_simple(20, 2, 5.0, 100, 150))
	# yes, ratio is ok, but armies are far away, and we have a lot of recruits and gold
	assert_true(RaiseArmyDecision.should_raise_army_simple(20, 4, 10.0, 150, 200))
	# yes, while we might be hitting our army limit ratio, we flood with recruits, gold and distance is huge
	assert_true(RaiseArmyDecision.should_raise_army_simple(20, 5, 15.0, 300, 500))
	# yes, our ratio is very bad, and we have some room to hire new
	assert_true(RaiseArmyDecision.should_raise_army_simple(20, 1, 1.0, 100, 100))

func test_should_raise_examples_no_cases() -> void:
	# no, while we have recruits and gold, we have too many armies and they are close
	assert_false(RaiseArmyDecision.should_raise_army_simple(10, 4, 2.0, 150, 200))
	# no, while ratio is not ideal, and distance is average, number of recruits and gold amount is very low
	assert_false(RaiseArmyDecision.should_raise_army_simple(10, 2, 5.0, 41, 56))

