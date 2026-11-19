class_name SudokuLogic
## Sudoku rules: generate puzzles with exactly one solution, and count solutions.
## A grid is an Array of 81 ints in row order, 0 for an empty square.

const CLUES := {Easy = 40, Medium = 32, Hard = 26}

## For each square, the 20 squares that share its row, column or box.
static var PEERS := _make_peers()


## Returns {puzzle, solution}. Hard may keep a few extra clues when no more can go without losing uniqueness.
static func generate(clues: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var solution := []
	solution.resize(81)
	solution.fill(0)
	_fill(solution, rng)
	var puzzle := solution.duplicate()
	var filled := 81
	for i in _shuffled(range(81), rng):
		if filled <= clues:
			break
		var keep: int = puzzle[i]
		puzzle[i] = 0
		if count_solutions(puzzle) == 1:
			filled -= 1
		else:
			puzzle[i] = keep
	return {puzzle = puzzle, solution = solution}


## Counts solutions up to limit. Leaves g unchanged.
static func count_solutions(g: Array, limit := 2) -> int:
	var c := _best_cell(g)
	if c[0] == -1:
		return 1
	var n := 0
	for d in range(1, 10):
		if c[1] & (1 << d):
			g[c[0]] = d
			n += count_solutions(g, limit - n)
			if n >= limit:
				break
	g[c[0]] = 0
	return n


## Bit d is set when digit d (1-9) can go in square i.
static func candidates(g: Array, i: int) -> int:
	var used := 0
	for p in PEERS[i]:
		used |= 1 << g[p]
	return ~used & 0x3FE


static func _fill(g: Array, rng: RandomNumberGenerator) -> bool:
	var c := _best_cell(g)
	if c[0] == -1:
		return true
	for d in _shuffled(range(1, 10), rng):
		if c[1] & (1 << d):
			g[c[0]] = d
			if _fill(g, rng):
				return true
	g[c[0]] = 0
	return false


## The empty square with the fewest candidates, as [index, mask]; [-1, 0] when the grid is full.
## Trying the tightest square first keeps the search fast enough for GDScript.
static func _best_cell(g: Array) -> Array:
	var best := [-1, 0]
	var best_n := 10
	for i in 81:
		if g[i] != 0:
			continue
		var mask := candidates(g, i)
		var n := 0
		for d in range(1, 10):
			n += (mask >> d) & 1
		if n < best_n:
			best = [i, mask]
			best_n = n
			if n <= 1:
				break
	return best


static func _shuffled(a: Array, rng: RandomNumberGenerator) -> Array:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a


@warning_ignore("integer_division")
static func _make_peers() -> Array:
	var all := []
	for i in 81:
		var p := []
		for j in 81:
			var same_box := i / 27 == j / 27 and i % 9 / 3 == j % 9 / 3
			if j != i and (i / 9 == j / 9 or i % 9 == j % 9 or same_box):
				p.append(j)
		all.append(p)
	return all
