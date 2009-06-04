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

class FileGroup

  attr_reader :name_pattern, :total_size

  def initialize(name_pattern)
    @name_pattern = name_pattern
    @empty_files = []

    @older_files = []
    @older_count = 20

    @total_size = 0
  end

  def add(file)
    return unless File.file?(file) and File.fnmatch?(name_pattern, File.basename(file))

    unless empty_file?(file)
      if @older_files.size < @older_count or File.mtime(@older_files.last) > File.mtime(file)
        @older_files = (@older_files + [file]).sort_by { |f| File.mtime(f) }.first(@older_count)
      end

      @total_size += File.size(file)
    else
      @empty_files << file
    end
  end
  
  def empty_file?(file)
    File.size(file) <= 44
  end

  def reduce(target_total_size)
    @empty_files.each do |file|
      delete(file)
    end

    PigeCron.logger.info "try to reduce '#{name_pattern}' from #{@total_size.in_gigabytes} gigabytes to #{target_total_size.in_gigabytes}"

    has_deleted_files = false
    while @total_size > target_total_size and not @older_files.empty?
      file = @older_files.shift
      @total_size -= File.size(file)
      has_deleted_files = true
      delete(file)
    end
    has_deleted_files
  end

  def delete(file)
    PigeCron.logger.info "delete #{file}"
    File.delete(file)
  end

end

class Cleaner

  attr_accessor :directory

  def initialize(directory)
    @directory = directory

    @wav_group = FileGroup.new('*.wav')
    @ogg_group = FileGroup.new('*.ogg')
  end

  def index
    unless File.exists?(@directory)
      PigeCron.logger.warn "Can't find the directory to clean: #{directory}"
      return
    end

    Find.find(directory) do |file|
      @wav_group.add file
      @ogg_group.add file
    end

    self
  end

  def clean
    unless File.exists?(@directory)
      PigeCron.logger.warn "Can't find the directory to clean: #{directory}"
      return
    end
      
    PigeCron.logger.info "free space: #{free_space.in_gigabytes} gigabytes"
    PigeCron.logger.debug { "minimum free space: #{minimum_free_space.in_gigabytes}" }

    if (missing_free_space = minimum_free_space - free_space) > 0
      maximum_used_space = (@ogg_group.total_size + @wav_group.total_size) - missing_free_space
      
      if @ogg_group.reduce(maximum_used_space * 0.9)
        @wav_group.reduce(maximum_used_space * 0.1)
      else
        @wav_group.reduce(maximum_used_space - @ogg_group.total_size)
      end

      PigeCron.logger.info "free space after: #{free_space.in_gigabytes} gigabytes (wav: #{@wav_group.total_size.in_gigabytes}, ogg: #{@ogg_group.total_size.in_gigabytes})"
    end
  end

  def free_space
    free_block, block_size = `stat --file-system --printf="%a %S" #{directory}`.split.collect(&:to_i)
    free_block*block_size
  end

  def total_space
    unless @total_space
      total_block, block_size = `stat --file-system --printf="%b %S" #{directory}`.split.collect(&:to_i)
      @total_space = total_block*block_size
    end
    @total_space
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
      encoding_command = "sox #{wav_file} -t ogg -C 6 #{tempfile.path} && mv #{tempfile.path} #{ogg_file}"
      PigeCron.logger.debug { "run '#{encoding_command}'" }

      sox_output = `#{encoding_command} 2>&1`
      tempfile.unlink

      if File.exists? ogg_file
        File.chmod 0644, ogg_file
      else
        PigeCron.logger.info "encoding failed: #{sox_output}" unless sox_output.empty?
      end
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
    Cleaner.new(pige_directory).index.clean
  end

  task :cron => [ :clean, :encode ]

end
