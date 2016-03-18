# -------------------------------------------------
# library/module
# -------------------------------------------------
require 'em-websocket'
require 'optparse'
require 'json'
require_relative '../../lib/othello_lib.rb'

# -------------------------------------------------
# How to Use
# -------------------------------------------------
# execute:
#   ruby othello_serv.rb
#
# require:
#   gem install em-websocket


# -------------------------------------------------
# Structure
# -------------------------------------------------
# [Server]
#
# [Match]
#
# [Player]
#
# [Game]
#
# [Board]
#
# [Stone]
#


# -------------------------------------------------
# Const
# -------------------------------------------------
DEFAULT_HOST = '0.0.0.0'
DEFAULT_PORT = 8088
TIMEOUT = 1
# action type
#   role:     role送信指示[:player/:monitor]
#   wait:     次回指示待ち指示
#   attack:   石配置指示
#   deffence: 石配置待ち指示
#   finish:   対戦終了通知
#   monitor:  観戦者向け通信
PLAYER_ACTION = [:role, :wait, :attack, :deffence, :finish, :monitor]


# -------------------------------------------------
# Server
# -------------------------------------------------
class Server
  def initialize(host, port)
    $log.info "started on ws://#{host}:#{port}"
    Match.new

    EM::WebSocket.start({:host => host, :port => port}) do |session|

      # session確立時
      session.onopen do
        Player.new(session)
      end

      # session切断時
      session.onclose do
        # TODO: そのうち対応
      end
    
      # error検知時
      session.onerror do
        # TODO: そのうち対応
      end
    
      # message受信時
      session.onmessage do |msg|
        $log.info "===================================="
        $log.info "<<<< #{Player.who(session).id}: #{msg}"
        begin
          msg = JSON.load(msg)
        rescue
          $log.error("message is not JSON")
          raise ArgumentError
        end

        if match = Match.which(Player.who(session))
          match.recv(Player.who(session), msg)
        else
          Match.matching(Player.who(session), msg)
        end
      end
      
    end
  end
end


# -------------------------------------------------
# MatchClass
# -------------------------------------------------
class Match
  @@list = []
  attr_accessor :p1, :p2, :monitor, :game, :timer

  #
  #
  def initialize
    @@list << self
  end

  #
  #
  def self.matching(plyr, msg)
    case msg['role']
    when 'player'
      if @@list[-1].p1 == nil
        @@list[-1].p1 = plyr
        @@list[-1].p1.name = msg['name']
        plyr.operation :wait
      else
        @@list[-1].p2 = plyr
        @@list[-1].p2.name = msg['name']
        @@list[-1].start
        self.new()
      end

    when 'monitor'
      @@list[-1].monitor = plyr
      plyr.operation :wait

    else
      $log.error("role:#{msg['role']} is not acceptable")
      raise ArgumentError

    end
  end

  #
  # 所属matchの検索
  def self.which(plyr)
    return @@list.find{|m| m.p1 == plyr or m.p2 == plyr}
  end

  #
  # 対戦開始
  def start
    $log.info "GameMatching: #{@p1.id} vs #{@p2.id}"
    # 先行をRandomで決定
    pre = [*1..2].sample
    post = pre == 1 ? 2 : 1
    # Gameの生成, 関連付け
    @game = Game.new
    # Player情報の更新
    eval("@p#{pre}.is_attacker = true")
    eval("@p#{pre}.clr = :b")
    eval("@p#{post}.is_attacker = false")
    eval("@p#{post}.clr = :w")
    # Timerの生成, 関連付け
    unless $option[:debug]
      @timer = Timer.new
      @timer.watch attacker
    end
    # actionの通知
    deffender.operation(:deffence, @game.board.to_a)
    attacker.operation(:attack, @game.board.to_a)
    if @monitor
      @monitor.clr  = "#{@p1.name}'s color: #{@p1.clr}"
      @monitor.clr += " / #{@p2.name}'s color: #{@p2.clr}"
      @monitor.operation(:monitor, @game.board.to_a)
    end
  end

  #
  # コマを置かれた場合に起動
  #   - attackerからの信号でなければ無視
  #   - コマ配置
  #   - 次のアクション指示[:change, :pass, :finish]
  def recv(plyr, msg)
    #
    unless plyr.is_attacker
      plyr.operation :deffence, @game.board
      return
    end
    #
    unless @game.put(plyr.clr, msg['x'], msg['y'])
      finish(plyr)
      return
    end
    #
    eval "#{@game.next_action(Stone.new(plyr.clr).other)}"
  end

  #
  #
  def change
    if @p1.is_attacker
      @p1.is_attacker = false
      @p2.is_attacker = true
    else
      @p1.is_attacker = true
      @p2.is_attacker = false
    end
    @timer.watch attacker unless $option[:debug]
    deffender.operation(:deffence, @game.board.to_a)
    attacker.operation(:attack, @game.board.to_a)
    @monitor.operation(:monitor, @game.board.to_a) if @monitor
  end

  #
  #
  def pass
    @timer.watch attacker unless $option[:debug]
    deffender.operation(:deffence, @game.board.to_a)
    attacker.operation(:attack, @game.board.to_a)
    @monitor.operation(:monitor, @game.board.to_a) if @monitor
  end

  #
  # 対戦終了
  #   - 反則による終了(=カウント不要)
  #     - 攻撃時間を超過した場合
  #     - 配置不可な場所に配置しようとした場合
  #   - 配置可能場所が無くなって終了(=カウント要)
  #     - 盤上が全て埋まっている場合
  #     - 両者ともパスになる場合
  #     - 盤面が片方の色になる場合
  def finish(loser=nil)

    @timer.cancel
    brd = @game.board.to_a

    if loser
      $log.info("finish winer=#{other_plyr(loser).name}, loser=#{loser.name}")
      # 反則終了
      loser.operation(:finish, brd, :lose)
      other_plyr(loser).operation(:finish, brd, :win)

    else
      # 配置可能場所枯渇
      attacker_count = @game.board.count(attacker.clr)
      deffender_count = @game.board.count(deffender.clr)
      $log.info("#{attacker.name} has #{attacker_count}, #{deffender.name} has #{deffender_count}")
      if attacker_count > deffender_count
        attacker.operation(:finish, brd, :win)
        deffender.operation(:finish, brd, :lose)
        @monitor.operation(:finish, brd, "winner is #{attacker.name}") if @monitor
        
      elsif attacker_count < deffender_count
        attacker.operation(:finish, brd, :lose)
        deffender.operation(:finish, brd, :win)
        @monitor.operation(:finish, brd, "winner is #{deffender.name}") if @monitor

      else
        attacker.operation(:finish, brd, :draw)
        deffender.operation(:finish, brd, :draw)
        @monitor.operation(:finish, brd, :draw) if @monitor

      end
      $log.info("finish loser=#{loser.name}")
    end

    # TODO: Match.@@listから削除: oncloseからも呼べるようなめそっどにする

  end

  #
  #
  def attacker
    return attacker = @p1.is_attacker ? @p1 : @p2
  end

  #
  #
  def deffender
    return deffender = @p1.is_attacker ? @p2 : @p1
  end

  #
  #
  def other_plyr(plyr)
    return other = plyr == @p1 ? @p2 : @p1
  end

end


# -------------------------------------------------
# PlayerClass
# -------------------------------------------------
class Player
  @@entry = {}
  attr_accessor :session, :name, :clr, :is_attacker

  #
  #
  def initialize(session)
    @session = session
    @@entry[session] = self

    operation(:role)
  end

  #
  def operation(act, brd=nil, rslt=nil)
    $log.info ">>>> #{Player.who(@session).id}: #{act}"
    raise NameError unless PLAYER_ACTION.include? act
    @session.send({action: act, board: brd.to_a, result: rslt, color: @clr}.to_json)
  end

  #
  # sessionからPlayerインスタンスを引いて返却
  def self.who(session); @@entry[session]; end

  #
  #
  def is_attacker?; @is_attacker; end

  #
  # PlayerID
  #   object_idそのままだと長いので下6桁に
  def id; self.object_id.to_s[-6..-1]; end

end


# -------------------------------------------------
# TimerClass
# -------------------------------------------------
class Timer
  attr_accessor :thread, :should_fire

  #
  #
  def initialize
    @should_fire = true
  end

  #
  #
  def watch(target)
    if @thread
      kill
    end

    @thread = Thread.fork do
      sleep TIMEOUT
      fire(target) if @should_fire
    end
  end

  #
  #
  def cancel
    @should_fire = false
  end

  #
  #
  def kill
    if @thread
      @thread.kill
      while @thread.alive?; end
      @thread = nil
    end
  end

  #
  #
  def fire(target)
    $log.info("#{TIMEOUT}sec timeout: loser is #{target.name}")
    Match.which(target).finish(target)
  end

end


# -------------------------------------------------
# main
# -------------------------------------------------
# option
$option = {debug: false}
OptionParser.new do |opt|
  opt.on('--host=[VALUE]', "[str] host name (default: #{DEFAULT_HOST})"){|v| $option[:host] = v}
  opt.on('--port=[VALUE]', "[int] port number (default: #{DEFAULT_PORT})"){|v| $option[:port] = v}
  opt.on('--debug',        '[ - ] logging debug log'){|v| $option[:debug] = v}
  opt.parse!(ARGV)
end

# logger
$log = Object.new
def $log.info(msg);  puts "[INFO ] #{msg}"; end
def $log.error(msg); puts "[ERROR] #{msg}"; end
if $option[:debug]
  def $log.debug(msg); puts "[DEBUG] #{msg}"; end
else
  def $log.debug(msg); end
end
$log.debug "MODE DEBUG"

# start up server
host = $option[:host] ? $option[:host] : DEFAULT_HOST
port = $option[:port] ? $option[:port] : DEFAULT_PORT
Server.new(host, port)
