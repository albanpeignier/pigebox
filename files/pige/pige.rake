require 'rake/tasklib'
require 'find'

require 'rubygems'
require 'syslog_logger'

module PigeCron
  @logger = SyslogLogger.new('pige.cron').tap do |logger|
    logger.level = Logger::INFO
  end

  def self.logger
    @logger
  end
end

class Numeric

  def gigabytes
    self * 1024 * 1024 * 1024
  end
  alias_method :gigabyte, :gigabytes

  def in_gigabytes
    self.to_f / 1.gigabyte
  end

end

class Cleaner

  attr_accessor :directory

  def initialize(directory)
    @directory = directory
  end

  def clean(dry_run = true)
    unless File.exists?(@directory)
      PigeCron.logger.warn "Can't find the directory to clean: #{directory}"
      return
    end
      
    PigeCron.logger.info "Free space: #{free_space.in_gigabytes} gigabytes"
    PigeCron.logger.debug { "Minimum free space: #{minimum_free_space.in_gigabytes}" }

    if free_space < minimum_free_space
      older_files('*.wav', 1).each do |file|
        PigeCron.logger.info "delete #{file}"
        File.delete(file) unless dry_run
      end
    end
  end

  def older_files(name_pattern, count = 10)
    older_files = []

    Find.find(directory) do |file|
      next unless File.file?(file) and File.fnmatch?(name_pattern, File.basename(file))
      
      if older_files.size < count or File.mtime(older_files.last) > File.mtime(file)
        older_files = (older_files + [file]).sort_by { |f| File.mtime(f) }.first(count)
      end
    end

    older_files
  end

  def free_space
    free_block, block_size = `stat --file-system --printf="%a %S" #{directory}`.split.collect(&:to_i)
    free_block*block_size
  end

  def total_space
    total_block, block_size = `stat --file-system --printf="%b %S" #{directory}`.split.collect(&:to_i)
    total_block*block_size
  end

  def minimum_free_space
    [1.gigabytes, total_space * 0.1].min
  end

end

namespace :pige do

  task :encode do

  end

  task :clean do
    Cleaner.new('/srv/pige').clean
  end

end
