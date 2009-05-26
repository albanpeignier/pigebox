require 'rake/tasklib'
require 'find'

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
      puts "Can't find the directory to clean: #{directory}"
      return
    end
      
    puts "Free space: #{free_space.in_gigabytes} gigabytes"
    puts "Minimum free space: #{minimum_free_space.in_gigabytes}"

    if free_space < minimum_free_space
      older_files('*.wav', 1).each do |file|
        puts "delete #{file}"
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
