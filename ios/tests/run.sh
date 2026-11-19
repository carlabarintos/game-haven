#!/bin/zsh
# Builds the phone-free logic for the Mac and runs the self-checks.
cd "$(dirname "$0")/.."
out=$(mktemp -d)
swiftc -O -parse-as-library GameHaven/Sudoku/SudokuLogic.swift GameHaven/WordSearch/WordSearchLogic.swift GameHaven/Solitaire/SolitaireLogic.swift GameHaven/Mahjong/MahjongLogic.swift GameHaven/Jigsaw/JigsawLogic.swift GameHaven/Dominoes/DominoLogic.swift GameHaven/Nonogram/NonogramLogic.swift GameHaven/Save.swift GameHaven/AdRules.swift GameHaven/Village/Village.swift tests/checks.swift -o "$out/checks" && "$out/checks"
