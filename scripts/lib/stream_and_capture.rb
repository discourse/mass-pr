# frozen_string_literal: true

require "open3"

def stream_and_capture(*cmd)
  status = nil
  stdout_str = +""
  stderr_str = +""

  Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
    Thread.new do
      while char = stdout.getc
        $stdout.write char
        stdout_str << char
        $stdout.flush
      end
    end

    # For stderr
    Thread.new do
      while char = stderr.getc
        $stderr.write char
        stderr_str << char
        $stderr.flush
      end
    end

    status = wait_thr.value
  end

  [status, stdout_str, stderr_str]
end
