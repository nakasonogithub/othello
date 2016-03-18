require 'json'
require 'optparse'

# ----------------------------------
# What's this
# ----------------------------------
# data_collector.rb及びrandom_clientで収集した棋譜の
# 整理を行う。
# - DATA_DIR配下のファイルを処理対象とする
# - 以下のルールで整理を行う
#   - ファイル名: 手数.json
#   - ファイル内容: 
#     {"records":[
#       {
#         result: true,                      # 最終的な勝敗
#         "board": [null, "w", "b", ..],     # 盤面=配列長64の１次元配列
#         "move": {"c": "w", "x": 4, "y": 3} # 指手=色, 座標
#       }
#     ]}
# - 以下に示す対称な盤面は同一盤面と見なす
#   - LineSymmetry
#   - RotateSymmetry
#   ↑これは計算しない方がいい? TensorFlowにData渡す&&演算する時どうなる?
#

# ----------------------------------
# conf
# ----------------------------------
RAW_DATA_DIR = "../raw_data"
TRAIN_DATA_DIR = "../train_data"


# ----------------------------------
# methods
# ----------------------------------
$opt={}
def init
end
#
#
def format_data
  #
  may_mkdir
  #
  files = get_raw_files
  #
  files.each do | file |
    JSON.load(open("#{RAW_DATA_DIR}/#{file}"))['data'].each do |match|
      format match
    end
  end
end

#
#
def may_mkdir
  unless Dir.exist? TRAIN_DATA_DIR
    Dir.mkdir TRAIN_DATA_DIR
  end
end

#
#
def may_create_file(no)
  file_name = "#{TRAIN_DATA_DIR}/#{no}.json"
  unless File.exist? file_name
    open(file_name, 'w') do | f |
      JSON.dump({records: []}, f)
    end
  end
end

#
#
def get_raw_files; `ls #{RAW_DATA_DIR}`.split(/\n/); end

#
#
def get_train_files; `ls #{TRAIN_DATA_DIR}`.split(/\n/); end

#
#
def format(match)
  recs = match['record']
  ans  = match['result'] == recs[0]['move']['c'] ? true : false
  added = {result: ans}

  recs.each do | rec |
    #
    #added = {board: rec['board'], move: rec['move']}
    #if ans == rec['move']['c']
    #  added[:result] = true
    #else
    #  added[:result] = false
    #end
    #
    added[:board] = rec['board']
    added['move'] = rec['move']
    may_create_file(rec['no'])
    train = JSON.load(open("#{TRAIN_DATA_DIR}/#{rec['no']}.json"))
    train['records'] << added
    open("#{TRAIN_DATA_DIR}/#{rec['no']}.json", 'w') do | f |
      JSON.dump(train, f)
    end
  end
end

#
#
def count
  files = get_train_files
  files.each do | f |
    puts "#{f}: #{JSON.load(open("#{TRAIN_DATA_DIR}/#{f}"))['records'].size}"
  end
end

# ----------------------------------
# main
# ----------------------------------
OptionParser.new do | opt |
  opt.on('--init',        '[ - ] logging debug log'){|v| $opt[:init] = v}
  opt.parse!(ARGV)
end

if $opt[:init]
  if Dir.exist? TRAIN_DATA_DIR
    `rm -f #{TRAIN_DATA_DIR}/*.json`
  end
end
format_data
count
