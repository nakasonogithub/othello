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
SERV = 'ws://127.0.0.1:8088' # localhost不可
NAME = 'PECO'
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
        print 'received_message: %s' % msg
        msg = json.loads(str(msg))
        action = msg['action']
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
            board = msg['board']
            color = msg['color']
            #
            # 上記情報を元に、次の配置先を決定する
            x, y = where_should_i_place(board, color)
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


    def where_should_i_place(board, color):
        """
  
        ここを考えてオセロAIを作りましょう！
  
        """
        x = 3
        y = 2
        return x, y


# -------------------------------------------------
# main
# -------------------------------------------------
print('connect to %s' % SERV)
ws = Client(SERV, protocols=['http-only', 'chat'])
ws.connect()
ws.run_forever()
