require 'rubygems'

require 'system_builder'
require 'system_builder/task'

load './local.rb' if File.exists?("./local.rb")

SystemBuilder::Task.new(:pigebox) do
  SystemBuilder::DiskImage.new("dist/disk").tap do |image|
    image.boot = SystemBuilder::DebianBoot.new("build/root")
    image.boot.configurators << SystemBuilder::PuppetConfigurator.new
  end
end

desc "Setup your environment to build a playbox image"
task :setup => "pigebox:setup" do
  if ENV['WORKING_DIR']
    %w{build dist}.each do |subdir|
      working_subdir = File.join ENV['WORKING_DIR'], subdir
      unless File.exists?(working_subdir)
        puts "* create and link #{working_subdir}"
        mkdir_p working_subdir
      end
      ln_sf working_subdir, subdir unless File.exists?(subdir)
    end
  end
end
