package main

import (
	//	"fmt"
	"log"
	"regexp"
)

const BOARD_WIDTH = 8
const BOARD_HEIGHT = 8

const (
	EMPTY = iota
	WHITE
	BLACK
	OKERU
)

type Board struct {
	cells [BOARD_HEIGHT][BOARD_WIDTH]int
}

func NewBoard() *Board {
	b := new(Board)
	b.cells[3][3] = WHITE
	b.cells[3][4] = BLACK
	b.cells[4][3] = BLACK
	b.cells[4][4] = WHITE
	return b
}

func (b *Board) Get(x int, y int) int {
	return b.cells[y][x]
}

func (b *Board) updateCandidates(selfcolor int) {
	log.Printf("Board.updateCandidates(%d)", selfcolor)
	var tmp Board
	for y := 0; y < BOARD_HEIGHT; y++ {
		for x := 0; x < BOARD_WIDTH; x++ {
			tmp = *b
			tmp.Put(x, y, selfcolor)
		}
	}
}

func (b *Board) Put(x int, y int, color int) bool {
	log.Printf("Board.Put(%d, %d, %d)", x, y, color)
	var othercolor int
	if color == WHITE {
		othercolor = BLACK
	} else if color == BLACK {
		othercolor = WHITE
	}
	type Direction struct {
		x int
		y int
	}
	dirs := [...]Direction{{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}}
	re := regexp.MustCompile(`^1+2`)
	found := false
	for _, d := range dirs {
		var buf string
		px, py := x, y
		for {
			px += d.x
			py += d.y
			if px < 0 || BOARD_WIDTH <= px ||
				py < 0 || BOARD_HEIGHT <= py {
				break
			}
			if b.cells[py][px] == EMPTY {
				break
			}
			if b.cells[py][px] == OKERU {
				break
			}
			if b.cells[py][px] == color {
				buf += "2"
				break
			} else {
				buf += "1"
			}
		}
		if re.MatchString(buf) {
			found = true
			px, py := x, y
			b.cells[py][px] = color
			for {
				px += d.x
				py += d.y
				if px < 0 || BOARD_WIDTH <= px ||
					py < 0 || BOARD_HEIGHT <= py {
					break
				}
				if b.cells[py][px] == othercolor {
					b.cells[py][px] = color
				} else {
					break
				}
			}
		}
	}
	return found
}

/*
func (b *Board) flip(x int, y int, color int) {
	for _, d := range b.dir {
		b.flipDir(x, y, d.x, d.y, color)
	}
}

func (b *Board) flipDir(x int, y int, dx int, dy int, color int) {
	for {
	}
}
*/

func (b *Board) ToText() string {
	s := ""
	for y := 0; y < BOARD_HEIGHT; y++ {
		for x := 0; x < BOARD_WIDTH; x++ {
			switch b.cells[y][x] {
			case WHITE:
				s += "O "
			case BLACK:
				s += "X "
			case EMPTY:
				s += "  "
			default:
				s += "v "
			}
		}
		s += "\n"
	}
	return s
}

func (b *Board) ToJSON() string {
	s := "    \"board\": [\n"
	for y := 0; y < BOARD_HEIGHT; y++ {
		s += "        ["
		for x := 0; x < BOARD_WIDTH; x++ {
			switch b.cells[y][x] {
			case WHITE:
				s += "w"
			case BLACK:
				s += "b"
			default:
				s += "null"
			}
			if x != BOARD_WIDTH-1 {
				s += ","
			}
		}
		s += "]"
		if y != BOARD_HEIGHT-1 {
			s += ","
		}
		s += "\n"
	}
	s += "    ]"
	return s
}

/*
func main() {
	brd := NewBoard()
	brd.updateCandidates(WHITE)
	brd.Put(4, 2, WHITE)
	brd.Put(5, 2, BLACK)
	brd.Put(5, 3, WHITE)
	brd.Put(5, 4, BLACK)
	brd.Put(6, 2, WHITE)
	brd.Put(3, 2, BLACK)
	fmt.Println(brd.ToText())
	fmt.Println(brd.ToJSON())
}
*/
