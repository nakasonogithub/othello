require 'json'

# ----------------------------------
# What's this
# ----------------------------------
# 指定した回数, Randomに対戦するクライアント同士を
# 対局させ、その棋譜をファイル出力する。
# # ファイル出力自体はCL_SCRIPT内で実施
#
# REPEAT     .. 対局数を指定
# LIMIT      .. 1ファイルあたりの棋譜数を指定
# DATA_DIR   .. 出力先ディレクトリ名を指定
# DATA_FILE  .. 出力先ファイル名を指定
# SRV_SCRIPT .. Serverスクリプトを指定(現在Ruby固定
# CL_SCRIPT  .. Clientスクリプトを指定(現在Ruby固定

# ----------------------------------
# conf
# ----------------------------------
REPEAT = 100
LIMIT = 10
DATA_DIR = "../raw_data"
DATA_FILE = "#{DATA_DIR}/raw_data.log"
SRV_SCRIPT = "../../ruby/src/server/server.rb"
CL_SCRIPT  = "./random_client.rb"


# ----------------------------------
# methods
# ----------------------------------
#
#
def collect_data
  REPEAT.times do |i|
    puts "# #{i} --------------------"
    may_rotate
    match
  end
end

#
# Dataファイル出力先Dirが存在しない場合, 作成する
def may_create_file
  unless File.exist? DATA_FILE
    open(DATA_FILE, 'w') do |file|
      JSON.dump({data: []}, file)
    end
  end
end

#
# Dataファイル出力先Dirが存在しない場合, 作成する
def may_mkdir
  unless Dir.exist? DATA_DIR
    puts "mkdir #{DATA_DIR}"
    Dir.mkdir DATA_DIR
  end
end

#
# DataFileのrecord数を確認。一定数を超えていた場合ローテート
def may_rotate
  record_size = JSON.load(open(DATA_FILE))['data'].size
  puts "record_size: #{record_size}"
  if record_size >= LIMIT
    `mv #{DATA_FILE} #{DATA_FILE}-#{Time.now.strftime("%Y%m%d%H%M%S")}`
    create_file
  end
end

#
# 
def match
  # Server起動
  srv_thread =  Thread.new { `ruby #{SRV_SCRIPT}`; puts 'server stopped' }
  # Client起動
  sleep 1
  cl_threads = []
  cl_threads.push(Thread.new { `ruby #{CL_SCRIPT} #{DATA_FILE}`; puts 'client1 stopped' })
  cl_threads.push(Thread.new { `ruby #{CL_SCRIPT} #{DATA_FILE}`; puts 'client2 stopped' })
  
  # Clentの終了待ち
  cl_threads.each{|t| t.join}
  
  # Server停止
  `ps -ef |grep server\.rb|awk '{print "kill -9",$2}'|sh`
  srv_thread.kill
  while srv_thread.alive?; end
end


# ----------------------------------
# main
# ----------------------------------
may_mkdir
may_create_file
collect_data
