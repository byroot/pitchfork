# -*- encoding: binary -*-
# frozen_string_literal: true
require 'mkmf'

module MakeMakefile
  module Logging
    @log = nil
    @logfile = 'mkmf.log'
    @orgerr = $stderr.dup
    @orgout = $stdout.dup
    @postpone = 0
    @quiet = $extmk

    def self::log_open
      @log ||= @orgerr
      @log.sync = true
    end

    def self::log_opened?
      @log and not @log.closed?
    end

    def self::open
      log_open
      $stderr.reopen(@log)
      $stdout.reopen(@log)
      yield
    ensure
      $stderr.reopen(@orgerr)
      $stdout.reopen(@orgout)
    end

    def self::message(*s)
      log_open
      @log.printf(*s)
    end

    def self::logfile file
      @logfile = file
      log_close
    end

    def self::log_close
      # if @log and not @log.closed?
      #   @log.flush
      #   @log.close
      #   @log = nil
      # end
    end

    def self::postpone
      tmplog = "mkmftmp#{@postpone += 1}.log"
      open do
        log, *save = @log, @logfile, @orgout, @orgerr
        @log, @logfile, @orgout, @orgerr = nil, tmplog, log, log
        begin
          log.print(open {yield @log})
        ensure
          # @log.close if @log and not @log.closed?
          File::open(tmplog) {|t| FileUtils.copy_stream(t, log)} if File.exist?(tmplog)
          @log, @logfile, @orgout, @orgerr = log, *save
          @postpone -= 1
          MakeMakefile.rm_f tmplog
        end
      end
    end

    class << self
      attr_accessor :quiet
    end
  end
end

append_cflags("-fvisibility=hidden")
append_cflags("-std=c99")

have_const("PR_SET_CHILD_SUBREAPER", "sys/prctl.h")
have_func("rb_enc_interned_str", "ruby.h") # Ruby 3.0+
have_func("rb_io_descriptor", "ruby.h") # Ruby 3.1+
have_func("rb_hash_new_capa", "ruby.h") # Ruby 3.2+
have_func("getpagesize", "unistd.h")

if RUBY_VERSION.start_with?('3.0.')
  # https://bugs.ruby-lang.org/issues/18772
  $CFLAGS << ' -DRB_ENC_INTERNED_STR_NULL_CHECK=1 '
else
  $CFLAGS << ' -DRB_ENC_INTERNED_STR_NULL_CHECK=0 '
end

have_func('epoll_create1', %w(sys/epoll.h))
create_makefile("pitchfork/pitchfork_http")
