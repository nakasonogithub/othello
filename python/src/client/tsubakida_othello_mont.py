# -*- encoding: utf-8 -*-
# -------------------------------------------------
# library/module
# -------------------------------------------------
import json
import copy
import random
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
CHILD_NUM=0
pN_CHILD={"x":[],"y":[],"where":[]}
node=[]
node_num=0      #登録ノード数
NODE_EMPTY = -1 #次のノードが存在ない場合
ILLEGAL = -1  #検証済みの手
B_SIZE = 7      #マスの数(0始まり)
uct_loop = 1000 #uctでplayoutを行う回数
BOARD_EVAL=[[30,-12,0,-1,-1,0,-12,30],
            [-12,-15,-3,-3,-3,-3,-15,-12],
            [0,-3,0,-1,-1,0,-3,0],
            [-1,-3,-1,-1,-1,-1,-3,-1],
            [-1,-3,-1,-1,-1,-1,-3,-1],
            [0,-3,0,-1,-1,0,-3,0],
            [-12,-15,-3,-3,-3,-3,-15,-12],
            [30,-12,0,-1,-1,0,-12,30]]


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
   

def where_should_i_place(board_init, my_clr):
        """
  
        ここを考えてオセロAIを作りましょう！
        """
        #初期化
        x_list=[]
        y_list=[]
        game_count=0
        
        game_count=game_cheak(board_init)        
        
        #相手の色を判断
        if my_clr=="w":
            enemy_clr="b"
        else:
            enemy_clr="w"
        
        #自分が置ける場所を探す
        x_list_init,y_list_init,where_list_init = where_reversible(board_init,my_clr)
        
        #評価値格納用配列の初期化
        eval_list=[0]*len(x_list_init)
        
        #場所の評価値よるAI
        if game_count<54:
          #ゲームの中盤で処理を変える
          for i in range(0,len(x_list_init)):
            board=copy.deepcopy(board_init)
            board=reverse(x_list_init[i],y_list_init[i],where_list_init[i],board_init,my_clr)
            eval_list[i] = eval_calc(board,my_clr)
          print "eval_list="
          print eval_list
          #raw_input('>>>')
          return x_list_init[eval_list.index(max(eval_list))], y_list_init[eval_list.index(max(eval_list))]
        
        #原始的モンテカルロAI
        else:
          win=[0]*len(x_list_init)
          for i in range(0,len(x_list_init)):
            board_enemy=reverse(x_list_init[i],y_list_init[i],where_list_init[i],board_init,my_clr)
            for j in range(0,5):
                board=copy.deepcopy(board_enemy)
                turn=1 #1が相手のターン、0が自分のターン
                pass_count=0
                #終局までシミュレーション
                while board_cheak(board) and pass_count <  2:
                  if turn==1:
                    clr=enemy_clr
                  else:
                    clr=my_clr

                  #置ける場所を探す
                  x_list,y_list,where_list = where_reversible(board,clr) 
                  #どこにも置けない場合はパスする
                  if len(x_list) == 0:
                      pass_count+=1
                      continue
                  #ランダムで置く場所を決める
                  put=random.randint(0,len(x_list)-1)
                  board=reverse(x_list[put],y_list[put],where_list[put],board,clr)
                  
                  #攻守を入れ替える
                  if turn==1:
                      turn=0
                  else:
                      turn=1
                  pass_count=0
                #ランダムで石を置いた結果の勝ち負けを記録する
                win[i]+=counter(board,my_clr,enemy_clr)
          
          print 'win'
          print win
          #raw_input('>>>')
          return x_list_init[win.index(max(win))], y_list_init[win.index(max(win))] 

#勝敗の判定
def counter(board,my_clr,enemy_clr):
    my_count=0
    enemy_count=0
    for i in range(0,len(board)):
        my_count+=board[i].count(my_clr)
        enemy_count+=board[i].count(enemy_clr)
    if my_count>=enemy_count:
        return 1
    else:
        return 0

#終局判定
def board_cheak(board):
    items=[]
    for row in board:
        for item in row:
           items.append(item)
    if "w" in items and "b" in items and None in items:
        return True
    else:
        return False

#試合の進み具合を計算
def game_cheak(board):
    items=[]
    game_count=0
    for row in board:
        for item in row:
           items.append(item)
    game_count+=items.count("w")
    game_count+=items.count("b")
    print items
    print game_count
    return game_count


#評価値を計算
def eval_calc(board,clr):
    evaluate=0
    items=[]
    x=0
    for row in board:
        y=0
        for item in row:
            if item == clr:
                evaluate+=BOARD_EVAL[x][y]
            y+=1
        x+=1
    return evaluate

#石を置ける場所を探す 
def where_reversible(board, clr):
    
    print 'where_reversible()============'
    x_list=[]
    y_list=[]
    where_list=[]
    for x in range(0,8):
        for y in range(0,8):
            where = []
            if board[x][y] is None:
                print "#{x},#{y} is empty"
                if reversible_confirm(x,y,board,clr,-1, 1): where.append([-1,1])
                if reversible_confirm(x,y,board,clr,-1, 0): where.append([-1,0])
                if reversible_confirm(x,y,board,clr,-1,-1): where.append([-1,-1])
                if reversible_confirm(x,y,board,clr, 0, 1): where.append([0,1])
                if reversible_confirm(x,y,board,clr, 0,-1): where.append([0,-1])
                if reversible_confirm(x,y,board,clr, 1, 1): where.append([1,1])
                if reversible_confirm(x,y,board,clr, 1, 0): where.append([1,0])
                if reversible_confirm(x,y,board,clr, 1,-1): where.append([1,-1])
            if len(where) is not 0:
                x_list.append(x)
                y_list.append(y)
                where_list.append(where)
                
    return x_list, y_list, where_list

       
# 指定された方向でひっくり返すことができるか確認
# 指定方向に石を確認し、異色が出てその先に同色が出たらOK
#   h .. 水平方向
#   v .. 垂直方向
def reversible_confirm(x, y, board, clr, h, v):
          print "reversible_confirm=================="
          print "x:"+str(x)+",y:"+str(y)+",clr:"+clr+",h:"+str(h)+",v:"+str(v)
          target = set()
          x+=h; y+=v
          while x>=0 and x<=7 and y>=0 and y<=7: # 盤外に出たら終了
            print ("  looping x:#{x}, y:#{y}")
            if board[x][y]==None: return False
            if len(target)==0 and board[x][y]==clr: return False
            target.add(board[x][y])
            print "target="
            print target
            if len(target) == 2: return True # 近い2色分押さえとけばOK
            x+=h; y+=v # 対象の移動
          return False


def reverse(x_init, y_init, where, board_init, clr):
        print "reverse======================"
        #初期化
        x=x_init
        y=y_init
        board=copy.deepcopy(board_init)

        #状態確認
        print "x=" + str(x_init)
        print "y=" + str(y_init)
        print "where="
        print where

        #ボードの初期化
        board=copy.deepcopy(board_init)
        #石を置く
        board[x][y]=clr
        print board
   
        for w in where:
          x=x_init+w[0]
          y=y_init+w[1]
          #ひっくり返す
          while  board[x][y] != clr and board[x][y] is not None:
            board[x][y]=clr
            x += w[0]
            y += w[1]
            print board

        return board

# -------------------------------------------------
print('connect to %s' % SERV)
ws = Client(SERV, protocols=['http-only', 'chat'])
ws.connect()
ws.run_forever()
