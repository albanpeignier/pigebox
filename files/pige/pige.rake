require 'rake/tasklib'
require 'find'
require 'tempfile'

require 'rubygems'
require 'syslog_logger'

module PigeCron
  @logger = 
    unless ENV['DEBUG']
      SyslogLogger.new('pige-cron').tap do |logger|
        logger.level = Logger::INFO
      end
    else
      Logger.new(STDOUT)
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
      
    PigeCron.logger.info "free space: #{free_space.in_gigabytes} gigabytes"
    PigeCron.logger.debug { "minimum free space: #{minimum_free_space.in_gigabytes}" }

    while free_space < minimum_free_space
      older_files('*.wav', 4).each do |file|
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
    @minimum_free_space ||= [1.gigabytes, total_space * 0.1].min
  end

end

class DirectoryEncoder

  attr_accessor :directory

  def initialize(directory)
    @directory = directory
  end

  def with_lock
    lock_file = "/tmp/pige:encode.lock"
    unless File.exists?(lock_file)
      touch lock_file

      begin
        yield
      ensure
        rm lock_file
      end
    else
      PigeCron.logger.info "skip encode (lock file found)"
    end
  end
      
  def encode
    with_lock do 
      now = Time.now
      
      FileList["#{directory}/**/*.wav"].each do |wav_file|
        next if File.mtime(wav_file) > now - 30
        
        ogg_file = wav_file.gsub(/\.wav$/,".ogg")
        unless uptodate?(ogg_file, wav_file) 
          encode_file(wav_file, ogg_file)
        end
      end
    end
  end

  def encode_file(wav_file, ogg_file)
    PigeCron.logger.info "encode #{wav_file}"
    # Use temporary file to avoid problem with interrupted encoding
    Tempfile.open('pige:encode') do |tempfile|
      encoding_command = "sox #{wav_file} -C 6 -t ogg #{tempfile.path} && mv #{tempfile.path} #{ogg_file}"
      PigeCron.logger.debug { "run '#{encoding_command}'" }

      sox_output = `#{encoding_command} 2>&1`
      PigeCron.logger.info "encoding failed: #{sox_output}" unless sox_output.empty?
      tempfile.unlink
    end
  end

end

namespace :pige do

  def pige_directory
    ENV['PIGE_DIR'] || '/srv/pige'
  end

  task :encode do
    DirectoryEncoder.new(pige_directory).encode
  end

  task :clean do
    Cleaner.new(pige_directory).clean(false)
  end

end
