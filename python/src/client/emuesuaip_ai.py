#!/usr/bin/env python
# encoding: utf-8

import json
import sys
import ws4py.client.threadedclient

W = 8  #  must be even number
H = 8  #  must be even number

test_array = []
array_pos = 0


#
# 
#
class Candidate:

	#
	#
	#
	def __init__(self, board, pos, mycolor, step):
		print "x=" + str(pos%W) + " y=" + str(pos/W) + " (" + mycolor + ")"
		self.board = board
		self.pos = pos
		self.mycolor = mycolor
		self.step = step

	#
	# N手後に一番置ける場所が多そうなところを選択 
	#
	def get_strength(self):
		print "つよさを調べる"
		show(self.board)
		mycolor = self.mycolor
		enemycolor = swap(mycolor)
		if self.step > 0:
			self.step -= 1
			ary = list(self.board)
			for i in range(H * W):
				buf = proc(ary, i, mycolor, enemycolor, True)
				if buf != None:
					print p2s(i) + "に置いたら以下のようになりますよ"
					show(buf)
					
			enemycolor = mycolor
			mycolor = swap(mycolor)
			
		return 0

# ----------------------------------------------------------------------
def init_board():
	board = []
	for i in range(W*H):
		board.append("-")
	board[(H/2)*W+W/2-1] = "w"
	board[(H/2)*W+W/2] = "b"
	board[(H/2-1)*W+W/2-1] = "b"
	board[(H/2-1)*W+W/2] = "w"
	return "".join(board)

# ------------------------------------------------------------------------
def p2s(pos):
	return "x=" + str(pos%W) + " y=" + str(pos/W)

# ------------------------------------------------------------------------
def proc(board, pos, mycolor, enemycolor, flip):
	if board[pos] != "-":
		return None
	res = board[:]
	found = False
	for dir in [-1-W, -W, 1-W, -1, 1, W-1, W, W+1]:
		enemy_found = False
		ptr = pos
		while True:
			ptr += dir
			x = ptr % W
			y = ptr / W
			if x<0 or W<=x or y<0 or H<=y:
				break
			if enemy_found:
				if board[ptr] == mycolor:
					found = True
					ptr = pos
					if flip:
						while board[ptr] != mycolor:
							res[ptr] = mycolor
							ptr += dir
					else:
						return True
					break
				elif board[ptr] != enemycolor:
					break
			else:
				if board[ptr] == enemycolor:
					enemy_found = True
				else:
					break
	if flip:
		if found:
			res[pos] = mycolor
			return "".join(res)
		return None
	return False

# ------------------------------------------------------------------------
def flip_all(board, mycolor, step):
	enemycolor = swap(mycolor)
	ary = list(board)
	for pos in range(len(ary)):
		res = proc(ary, pos, mycolor, enemycolor)
		if res != None:
			register(board, pos, res, step)

# ------------------------------------------------------------------------
def register(before, pos, after, step):
	test_array.append({"before": before,
                           "pos": pos,
                           "after": after,
                           "step": step})

# ------------------------------------------------------------------------
def swap(c):
	if c == "w":
		return "b"
	return "w"

# ------------------------------------------------------------------------
def show(b):
	s = "  0 1 2 3 4 5 6 7\n"
	l = list(b)
	for y in range(H):
		s += str(y)
		for x in range(W):
			s += " " + b[y*W+x]
		s += "\n"
	print s + "\n"

# ------------------------------------------------------------------------
def select(board, mycolor):
	step = 3
	print "次の候補リストを取得"
	cans = []
	enemycolor = swap(mycolor)
	for pos in range(len(board)):
		ary = list(board)
		res = proc(ary, pos, mycolor, enemycolor, True)
		if res != None:
			c = Candidate(res, pos, swap(mycolor), step)
			cans.append(c)
	print "それぞれの候補を評価  ちなみに候補は" + str(len(cans)) + "つある"
	tmp = []
	for can in cans:
		s = can.get_strength()
		print "つよさは" + str(s) + "でした"
		tmp.append({"pos": can.pos, "strength": s})
	print "一番つよさ値が大きいものを選ぶ"
	pos = tmp[0]["pos"]
	strength = tmp[0]["strength"]
	for t in tmp:
		if t["strength"] > strength:
			pos = t["pos"]
	return pos

# ------------------------------------------------------------------------
class Client(ws4py.client.threadedclient.WebSocketClient):
	def opened(self):
		print 'opened'
	def closed(self, code, reason = None):
		print 'closed'
		sys.exit()
	def received_message(self, msg):
		msg = json.loads(str(msg))
		action = msg['action']
		if action == 'role':
			self.send(json.dumps({'role': 'player', 'name': 'XXX'}))
		elif action == 'attack':
			tmpboard = msg['board']
			mycolor = msg['color']
			board = ""
			for y in range(H):
				for x in range(W):
					if tmpboard[y][x] == None:
						board += "-"
					else:
						board += tmpboard[y][x]
			pos = select(board, mycolor)
			self.send(json.dumps({'x': pos%W, 'y': pos/W}))
		elif action == 'finish':
			print msg['result']
			self.close
			sys.exit()

# ------------------------------------------------------------------------
if __name__ == '__main__':
	#mycolor = "b"
	#board = init_board()
	#show(board)
 	# websocketで得られたものを使うように修正する予定
	#pos = select(board, mycolor)
	#print "次の一手はx=" + str(pos%W) + " y=" + str(pos/H) + "だ！"

	ws = Client('ws://127.0.0.1:8088/', protocols=['http-only', 'chat'])
	ws.connect()
	ws.run_forever()

