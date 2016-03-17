# -*- encoding: utf-8 -*-
# -------------------------------------------------
# library/module
# -------------------------------------------------
import json
from ws4py.client.threadedclient import WebSocketClient


# -------------------------------------------------
# How to Use
# -------------------------------------------------
# require:
#   pip install ws4py


# -------------------------------------------------
# const
# -------------------------------------------------
SERV = 'ws://127.0.0.1:8088'
NAME = 'PECO'
ROLE = 'player'
WIDTH = 8
HEIGHT = 8

# -------------------------------------------------
# global
# -------------------------------------------------
board = None
color = None
can_place_list = [] #[x,y,取れる石数,手の強さ]のリスト
max_strength = 0

# -------------------------------------------------
# ClientClass
# -------------------------------------------------
class Client(WebSocketClient):
    def opened(self):
        """
        session確立時に呼ばれる関数
        """


    def closed(self, code, reason=None):
        """
        session切断時に呼ばれる関数
        """


    def received_message(self, msg):
        """
        message受信時に呼ばれる関数
        """
        msg = json.loads(str(msg))
        action = msg['action']
        
        global can_place_list
        global max_strength
        can_place_list = []
        max_strength = 0
        
        

        if action   == 'role':
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
            global board
            global color
            board = msg['board']
            color = msg['color']
            #
            # 上記情報を元に、次の配置先を決定する
            x, y = where_should_i_place()
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
            self.close


def where_should_i_place():
    where_can_i_place()
    
    if len(can_place_list) > 0:
        for place in can_place_list:
            if place[3] == max_strength:
                return place[0], place[1]
        place = can_place_list.pop()
        return place[0], place[1]
    else:
        return 0,0

def where_can_i_place():

    # １マスずつ、取れる石の数を数える
    for y in range(0,HEIGHT):
        for x in range(0,WIDTH):

            count = 0
            
            # 石が置いてある場所は飛ばす
            if board[y][x] is None:
                # １方向ずつ、取れる石の数を数える
                for h in range(-1,2):
                    for v in range(-1,2):
                        count += get_reverse_count(x,y,h,v)
                if count > 0:
                    #ここに石を置く手の強さを決める
                    strength = count
                    if (x == 0 or x == WIDTH - 1 ) and (y == 0 or y == HEIGHT - 1):
                        strength = 100

                    can_place_list.append([x,y,count,strength])

                    #強さの最大値を更新
                    global max_strength
                    if strength > max_strength:
                        max_strength = strength

def get_reverse_count(x,y,h,v):
    if h == 0 and v == 0:
        return 0
    
    x += h
    y += v
    count = 0
    find_opposite_color_flag = False
    
    # 隣接する敵の石があるか調べる
    # 隣接する石の方向に、敵の色->自分の色となっているかを調べる
    while 0 <= x < WIDTH and 0 <= y < HEIGHT:
        stone = board[y][x]

        # 空き
        if stone == None:
            return 0
        # 自分の色
        elif stone == color:
            if find_opposite_color_flag:
                return count
            else:
                return 0
        # 相手の色
        else:
            count += 1
            find_opposite_color_flag = True

        x += h
        y += v

    return 0


# -------------------------------------------------
# main
# -------------------------------------------------


ws = Client(SERV, protocols=['http-only', 'chat'])
ws.connect()
ws.run_forever()
