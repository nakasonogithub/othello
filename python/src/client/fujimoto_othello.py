# -*- encoding: utf-8 -*-
import sys
sys.path.append(
    '/Users/f-satoshi/.pyenv/versions/2.7.10/lib/python2.7/site-packages/')

# -------------------------------------------------
# library/module
# -------------------------------------------------
import json
from ws4py.client.threadedclient import WebSocketClient

import random
import copy

# -------------------------------------------------
# How to Use
# -------------------------------------------------
# require:
#   pip install ws4py


# -------------------------------------------------
# const
# -------------------------------------------------
SERV = 'ws://0.0.0.0:8088'
NAME = 'FUJIMOTO'
ROLE = 'player'


# -------------------------------------------------
# ClientClass
# -------------------------------------------------
class Client(WebSocketClient):
    def opened(self):
        """
        session確立時に呼ばれる関数
        """
        print 'opened'

    def closed(self, code, reason=None):
        """
        session切断時に呼ばれる関数
        """
        print 'closed'

    def received_message(self, msg):
        """
        message受信時に呼ばれる関数
        """
        # print 'received_message: %s' % msg
        msg = json.loads(str(msg))
        action = msg['action']
        if action == 'role':
            #
            # 最初に参加形態[player/monitor]を聞かれるの
            # AIの場合は"role":"player"とリクエストを送る
            # TODO: 同時に名前も送信するため、定数の値を変更すること。
            self.send(json.dumps({'role': ROLE, 'name': NAME}))

        elif action == 'wait':
            #
            # 対戦者の接続を待つ
            # do nothing
            pass

        elif action == 'attack':
            #
            # msg['board']で現在の盤上の状態がJSON2次元配列で与えられる
            # msg['color']であなたが配置する石の色が与えられる
            board = msg['board']
            color = msg['color']
            #
            # 上記情報を元に、次の配置先を決定する
            x, y = self.where_should_i_place(board, color)
            #
            # 決定した配置先をサーバに通知する
            self.send(json.dumps({'x': x, 'y': y}))

        elif action == 'deffence':
            #
            # 対戦相手が石を配置するのを待つ
            # do nothing
            pass

        elif action == 'finish':
            #
            # 勝敗が送信されてくる
            print "Match result is %s" % msg['result']
            self.close

    # 考えどころ
    def where_should_i_place(self, board, color):
        board = convert_board(board, color)
        print_board(board)
        place_list = check_placeable_point(board)
        print place_list

        return adhock_choice(place_list, board)


# 盤面をわかりやすく変換
def convert_board(board, color):
    for i, column in enumerate(board):
        for j, stone in enumerate(column):
            if stone is None:
                board[i][j] = '-'
            elif stone == color:
                board[i][j] = 'o'
            else:
                board[i][j] = 'x'
    return board


# 盤面を出力
def print_board(board):
    friend = 0
    enemy = 0
    for column in board:
        for stone in column:
            print stone,
            if stone == 'o':
                friend += 1
            elif stone == 'x':
                enemy += 1
        print ''
    print str(friend) + ' - ' + str(enemy)


# 石を配置できる座標を列挙する
def check_placeable_point(board):
    ans = set()
    dir_list = [
        (-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]

    for i, column in enumerate(board):
        for j, stone in enumerate(column):
            # 石が置かれているところには置けない
            if board[i][j] is not '-':
                continue

            # 8方向 一歩一歩進んで確かめる
            for tate, yoko in dir_list:
                hasami = False
                x = j
                y = i
                while True:
                    x = x + tate
                    y = y + yoko
                    # はみ出したら置けない
                    if x < 0 or y < 0 or x > 7 or y > 7:
                        hasami = False
                        break
                    # 石がなかったら置けない
                    if board[y][x] == '-':
                        hasami = False
                        break
                    # 自分の石だったら見るの終わり
                    if board[y][x] == 'o':
                        break
                    # 相手の石だったら置けるかも
                    if board[y][x] == 'x':
                        hasami = True
                if hasami:
                    ans.update([(j, i)])
                    break

    return ans


# 置ける場所を全てチェックし、
# 相手が置ける場所が最も少なくなる場所を選択
# 隅におけるなら隅に置く
def adhock_choice(place_list, board):
    sumi = set([(0, 0), (0, 7), (7, 0), (7, 7)])
    sumi_set = place_list & sumi
    if sumi_set:
        return random.choice(list(sumi_set))
    min_place = ()
    min_okeru = 99

    for place in list(place_list):
        img_board = copy.deepcopy(board)
        img_board = reverse_stone(img_board, place)
        # print '~~~~~~~~~~~~~~~~~~~~~~'
        # print_board(img_board)
        # print '~~~~~~~~~~~~~~~~~~~~~~'
        teki_okeru = len(check_placeable_point(reverse_board(img_board)))
        jibun_okeru = len(check_placeable_point(img_board))
        okeru_point = jibun_okeru - teki_okeru
        if okeru_point < min_okeru:
            min_okeru = okeru_point
            min_place = place

    return min_place


# 石を全てひっくり返す(相手の目線に立って考える)
def reverse_board(board):
    reversed_board = copy.deepcopy(board)
    for i, column in enumerate(board):
        for j, stone in enumerate(column):
            if board[i][j] == 'o':
                reversed_board[i][j] = 'x'
            elif board[i][j] == 'x':
                reversed_board[i][j] = 'o'
    return reversed_board


# 指定された場所に石を置いてひっくり返す
def reverse_stone(board, place):
    tx = place[1]
    ty = place[0]
    dir_list = [
        (-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]

    board[ty][tx] = 'o'
    for tate, yoko in dir_list:
        x = tx
        y = ty
        target = []
        hasami = False
        while True:
            x += yoko
            y += tate
            # はみ出したら置けない
            if x < 0 or y < 0 or x > 7 or y > 7:
                hasami = False
                break
            # 石がなかったら置けない
            if board[y][x] == '-':
                hasami = False
                break
            # 自分の石だったら見るの終わり
            if board[y][x] == 'o':
                break
            # 相手の石だったら置けるかも
            if board[y][x] == 'x':
                target.append((y, x))
                hasami = True
        if hasami:
            for i, j in target:
                board[i][j] = 'o'
            break

    return board


# -------------------------------------------------
# main
# -------------------------------------------------
print('connect to %s' % SERV)
ws = Client(SERV, protocols=['http-only', 'chat'])
ws.connect()
ws.run_forever()
