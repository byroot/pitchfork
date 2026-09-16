# frozen_string_literal: true
require 'integration_test_helper'

class RestartTest < Pitchfork::IntegrationTest
  def test_restart
    addr, port = unused_port

    File.write("Gemfile", <<~RUBY)
      source "https://rubygems.org"

      gem "pitchfork", path: #{ROOT.inspect}
    RUBY
    assert system("bundle", "install", out: File::NULL, err: File::NULL)
    pid = spawn_server(app: File.join(ROOT, "test/integration/env.ru"), config: <<~CONFIG)
      listen "#{addr}:#{port}"
      worker_processes 2

      restart_command_prefix ["bundle", "exec"]

      before_worker_exit do |server, worker|
        server.logger.info("clean_exit worker=\#{worker.nr}")
      end
    CONFIG

    assert_healthy("http://#{addr}:#{port}")
    assert_stderr(/worker=0 gen=0 pid=\d+ ready/)
    assert_stderr(/worker=1 gen=0 pid=\d+ ready/)

    4.times do
      assert_equal true, healthy?("http://#{addr}:#{port}")
    end

    write_config(<<~CONFIG)
      listen "#{addr}:#{port}"
      worker_processes 4

      restart_command_prefix ["bundle", "exec"]

      before_worker_exit do |server, worker|
        server.logger.info("clean_exit worker=\#{worker.nr}")
      end
    CONFIG

    File.truncate("stderr.log", 0)
    Process.kill(:USR1, pid)

    assert_stderr(/monitor reexecuting/)
    assert_stderr(/monitor initializing with inherited state/)

    10.times do
      assert_equal true, healthy?("http://#{addr}:#{port}")
    end

    assert_stderr(/worker=2 gen=0 pid=\d+ ready/, timeout: 3)
    assert_stderr(/worker=3 gen=0 pid=\d+ ready/)

    assert_clean_shutdown(pid)
  end
end
