require 'drb'
require 'skynet/guid_generator'
require 'skynet/logger'
require 'skynet/config'
require 'timeout'    

Skynet::CONFIG[:SKYNET_PATH] ||= File.expand_path(File.dirname(__FILE__) +"/..")

require 'skynet/debugger'
require 'skynet/message'
require 'skynet/message_queue_adapters/message_queue_adapter'
require 'skynet/message_queue_adapters/tuple_space'
require "skynet/message_queue"
require 'skynet/partitioners'
require 'skynet/job'
require 'skynet/worker'
require 'skynet/task'
require 'skynet/manager'
require 'skynet/tuplespace_server'
require 'skynet/ruby_extensions'
require 'skynet/mapreduce_test'
require 'skynet/launcher'
require 'skynet/console'
require 'skynet/mapreduce_helper'
require 'skynet/object_extensions'

begin
  require 'fastthread'
rescue LoadError
  # puts 'fastthread not installed, using thread instead'
  require 'thread'
end

class << Skynet

  def master_tasks
    ::SkynetMessageQueue.find(:all, :select => "DISTINCT name, COUNT(*) total",:group => "name",:conditions => "payload_type='master'").
    map{|q|"#{q.name} => #{q.total}"}.sort
  end

  # kinda like system() but gives me back a pid
  def fork_and_exec(command)
    sleep 0.01  # remove contention on manager drb object
    log = Skynet::Logger.get
    debug "executing /bin/sh -c \"#{command}\""
    pid = safefork do
      close_files
      exec("/bin/sh -c \"#{command}\"")
      exit
    end
    Process.detach(pid)
    pid
  end

  def safefork (&block)
    @fork_tries ||= 0
    fork(&block)
  rescue Errno::EWOULDBLOCK
    raise if @fork_tries >= 20
    @fork_tries += 1
    sleep 5
    retry
  end

  # close open file descriptors starting with STDERR+1
  def close_files(from=3, to=50)
    close_console
    (from .. to).each do |fd|
      IO.for_fd(fd).close rescue nil
     end
  end

  def close_console
    STDIN.reopen "/dev/null"
    STDOUT.reopen "/dev/null", "a"
    STDERR.reopen STDOUT 
  end

  def process_alive?(worker_pid)
    Process.kill(0,worker_pid)
    return true
  rescue Errno::ESRCH => e
    return false
  end  

end
