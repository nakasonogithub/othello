# othello

## なにこれ
オセロAI同士を戦わせるプラットフォームを目指して作成しています。


## 戦わせ方
1. プラットフォーム(othello_serv.rb)を起動
2. (モニター用Clientをプラットフォームに接続)
3. プレイヤー用Clientをプラットフォームに接続
4. 2プレイヤーが接続された時点で対戦開始となり、プラットフォームが先攻プレイヤーに石を配置するよう指示を出します。
5. 石を配置する指示を受け取ったAIは、石の配置場所をサーバに通知して下さい。
6. 以降、次の担当プレイヤーにプラットフォームが指示を出す。石を配置する場所を通知する。を繰り返します。
7. 終了条件は以下の2パターンです。
  * 盤上が全て埋まった。
  * プレイヤーが配置不可な場所(既に石がある場所等)に配置しようとした。(この時点で負け)


## IF
Client<=>Server間はWebSocketで通信を行います。メッセージ形式はJSONです。  
色々すっ飛ばして、パラメータサンプルを見てもらうとわかりやすいかもしれません。


#### server => client

###### パラメータ概要
|key|説明|valueとして取り得る値|
|---|---|---|
|action|AIへの指示|※別表: action一覧|
|board|盤面情報|空配列もしくは8*8の2次元配列。配列内の値として黒石"b", 白石"w", 空きマスnullが格納される|
|color|割り当てられた石色|nullもしくは"b", "w"|
|result|対戦結果|nullもしくは"win", "lose", "draw"|

###### action一覧
|action名|説明|
|---|---|
|role|役割送信指示|
|wait|次回指示待ち指示|
|attack|石配置指示|
|deffence|石配置待ち指示|
|finish|対戦終了通知|
|monitor|観戦者向け通知|

#### client => server

###### 役割通知(初回に1度だけ送信する)
|key|説明|valueとして取り得る値|
|---|---|---|
|role|役割|"player", "monitor"|
|name|名前|任意の文字列。roleが"monitor"の場合、不要|

###### 石配置場所通知
|key|説明|valueとして取り得る値|
|---|---|---|
|x|横方向の位置|0-7|
|y|縦方向の位置|0-7|

#### パラメータサンプル
###### 1. 接続後最初、Clientが受け取るメッセージ(役割送信指示)
```
{
    "action": "role",
    "board": [],
    "color": null,
    "result": null
}
```
###### 2. Clientが役割:プレイヤーを通知するメッセージ
```
{  
    "role": "player",
    "name": "HOGEHOGE"
}
```
###### 3. プレイヤー登録後、Clientが受け取るメッセージ(次回指示待ち指示)
```
{
    "action": "wait",
    "board": [],
    "color": null,
    "result": null
}
```
###### 4. 対戦成立後、Clientが受け取るメッセージ(先攻の場合)
```
{
    "action": "attack",
    "board": [
        [null,null,null,null,null,null,null,null],
        [null,null,null,null,null,null,null,null],
        [null,null,null,null,null,null,null,null],
        [null,null,null,"w","b",null,null,null],
        [null,null,null,"b","w",null,null,null],
        [null,null,null,null,null,null,null,null],
        [null,null,null,null,null,null,null,null],
        [null,null,null,null,null,null,null,null]
    ],
    "color": "b",
    "result": null
}
```
###### 5. Clientが石配置場所を通知するメッセージ
```
{
    "x": 3,
    "y": 2
}
```
###### 6. 次回のattack通知が来るまで待機指示をClientが受け取るメッセージ
```
{
    "action": "deffence",
    "board": [
        [null,null,null,null,null,null,null,null],
        [null,null,null,null,null,null,null,null],
        [null,null,null,null,null,null,null,null],
        [null,null,"b","b","b",null,null,null],
        [null,null,null,"b","w",null,null,null],
        [null,null,null,null,null,null,null,null],
        [null,null,null,null,null,null,null,null],
        [null,null,null,null,null,null,null,null]
    ],
    "color": "b",
    "result": null
}
```


## AI作り方の参考に
* client/ruby/sample.rb
* python, goあたりでもsample作ってみるつもりです。
* client/gui/client.htmlをローカルで開くとGUIでオセロができます。一人オセロやAIの動作確認に。


## その他
* goに移植したい
* サーバの動作がクソ遅い

