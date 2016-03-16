require 'json'

REPEAT = 100
FILE = "./training/training.log"
LIMIT = 10

REPEAT.times do
  # logFileの数を確認
  # 一定数を超えていた場合ローテート
  if JSON.load(open(FILE))['data'].size >= LIMIT
    `mv #{FILE} #{FILE}-#{Time.now.strftime("%Y%m%d%H%M%S")}`
    open(FILE, 'w') do |file|
      JSON.dump({data: []}, file)
    end
  end
  

  # Script起動
  srv_thread =  Thread.new { `ruby ../server/server.rb`; p 'end server' }
  sleep 1
  cl_threads = []
  cl_threads.push(Thread.new { `ruby ./random.rb`; p 'end random1' })
  cl_threads.push(Thread.new { `ruby ./random.rb`; p 'end random2' })
  
  # Clentの終了待ち
  cl_threads.each{|t| t.join}
  
  # 一度Serverを殺す
  srv_thread.kill
  while srv_thread.alive?; end
end
