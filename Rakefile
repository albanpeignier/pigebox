module ShellUtils
  def sudo(*arguments)
    sh "sudo -H #{arguments.join(' ')}"
  end
end

class Numeric

  def megabytes
    self * 1024 * 1024
  end
  alias_method :megabyte, :megabytes

  def in_megabytes
    self.to_f / 1.megabyte
  end

end

module Pigebox
  VERSION = "0.0.4"
end

include ShellUtils
require 'rake/tasklib'
require 'erb'
require 'tempfile'

class ImageBuilder < Rake::TaskLib
  include ShellUtils

  @@default_debian_mirror= "http://ftp.fr.debian.org/debian"
  @@ssh_pubkey = Dir["#{ENV['HOME']}/.ssh/id_*pub"].first

  def self.default_debian_mirror=(default_debian_mirror)
    @@default_debian_mirror=default_debian_mirror
  end

  def self.ssh_pubkey=(ssh_pubkey)
    @@ssh_pubkey=ssh_pubkey
  end

  attr_accessor :name, :image_dir, :cache_dir, :debian_mirror, :additional_packages, :ssh_pubkey

  def initialize(name = :pigebox)
    @name = name

    work_dir="/var/tmp/#{name}"
    @image_dir= "#{work_dir}/image"
    @cache_dir= work_dir

    @additional_packages =
      %w{cron rsyslog} + # base system
      %w{netbase ifupdown net-tools dhcp3-client ifplugd} + # base network
      %w{ssh ntp ntpdate avahi-autoipd avahi-daemon} + # network services
      %w{alsa-utils sox libsox-fmt-all} + # base sound
      %w{mdadm} + # manage SW RAID storage
      %w{nano} + # so handy for config files...
      %w{ruby} # live origin :)

    yield self if block_given?
    define
  end

  def debian_mirror
    @debian_mirror || @@default_debian_mirror
  end

  def ssh_pubkey
    @@ssh_pubkey
  end  

  def image_tar
    "#{cache_dir}/image.tar"
  end

  def image_file(name)
    File.join(image_dir, name)
  end

  def image_files(*globs)
    Dir[*globs.flatten.collect { |g| image_file(g) }]
  end

  def install(target, *sources)
    file_sources = sources.flatten.collect { |s| s.start_with?('/') ? s : File.join("files", s) }
    sudo "cp --preserve=mode,timestamps #{file_sources.join(' ')} #{image_file(target)}"
  end

  def link(source, target)
    chroot "ln -fs #{source} #{target}"
  end

  def mkdir(directory)
    directory = image_file(directory)
    sudo "mkdir -p #{directory}" unless File.exists?(directory)
  end

  class Chroot
    def initialize(image)
      @image = image
    end

    def apt_install(*packages)
      sudo "apt-get install --yes --force-yes #{packages.join(' ')}"
    end

    def sh(*arguments)
      @image.sudo "chroot #{@image.image_dir} sh -c \"LC_ALL=C #{arguments.join(' ')}\""
    end
    alias_method :sudo, :sh

    def gem_install(*packages)
      packages = packages.flatten
      options = Hash === packages.last ? packages.pop : {}
      install_arguments = options.collect { |key, value| "--#{key}=#{value}" }.join(' ')

      # TODO use 'gem list -i #{package}' but it didn't work this evening
      sh "gem install --no-rdoc --no-ri #{install_arguments} #{packages.join(' ')}"
    end
  end

  def chroot(*arguments, &block)
    @chroot ||= Chroot.new(self)

    unless block_given?
      @chroot.sh *arguments
    else
      begin
        prepare_run
        yield @chroot
      ensure
        unprepare_run
      end
    end
  end

  def prepare_run
    sudo "mount proc #{image_file('proc')} -t proc"
  end

  def unprepare_run
    sudo "umount #{image_file('proc')}"
  end

  def iso_file
    "#{cache_dir}/#{name}.iso"
  end

  def disk_file
    "#{cache_dir}/#{name}.disk"
  end

  def disk_size
    400.megabytes
  end

  def mount_dir
    "#{cache_dir}/mount"
  end

  def install_grub(options = {})
    mkdir "boot/grub"

    stage_files = Array(options[:stage_files]).flatten

    install_grub_menu options
    install "boot/grub", stage_files.collect { |f| '/usr/lib/grub/**/' + f }
  end

  def install_grub_menu(options = {})
    options = { :root => "LABEL=#{root_label}" }.update(options)
    root = options[:root]
    version = Pigebox::VERSION

    Tempfile.open("menu_lst") do |f|
      f.write ERB.new(IO.read("files/grub/menu.lst")).result(binding)
      f.close
      File.chmod 0644, f.path
      install "boot/grub/menu.lst", f.path
    end
  end

  def root_label
    "pigebox_root"
  end

  def define
    namespace name do
      desc "Clean image temporary directory"
      task :clean do
        sudo "rm -rf #{image_dir}"
      end

      desc "Boostrap debian system in image directory"
      task :bootstrap do
        mkdir_p cache_dir
        sudo "debootstrap --variant=minbase --arch=i386 --include=#{additional_packages.join(',')} lenny #{image_dir} #{debian_mirror}"
      end

      desc "Save the current image directory in tar archive"
      task :backup do
        sudo "tar -cf #{image_tar} -C #{image_dir} ."
      end

      desc "Restore the image directory with existing tar archive"
      task :restore => :clean do
        mkdir_p image_dir
        sudo "tar -xf #{image_tar} -C #{image_dir} ."
      end

      desc "Create local link to image directory"
      task :link do
        sh "ln -fs #{image_dir} #{name}"
      end

      namespace :dist do

        task :clean do
          chroot do |chroot|
            chroot.sudo "apt-get remove --yes ruby-dev build-essential"
            chroot.sudo "apt-get autoremove --yes"
            chroot.sudo "apt-get clean"
          end
        end

        desc "Create an iso file from pigebox image"
        task :iso => :clean do
          install_grub :root => "/dev/hda", :stage_files => "stage2_eltorito"
          sudo "mkisofs -quiet -R -b boot/grub/stage2_eltorito -no-emul-boot -boot-load-size 4 -boot-info-table -A 'Pibebox_#{Pigebox::VERSION}' -V '#{root_label}' -o #{iso_file} #{image_dir}"
        end

        desc "Create a compressed iso file"
        task :iso_bz => :iso do
          sh "bzip2 -c #{iso_file} > #{iso_file}.bz"
        end

        namespace :disk do

          task :clean do
            rm disk_file
          end

          task :file do
            sh "dd if=/dev/zero of=#{disk_file} count=#{disk_size.in_megabytes.to_i} bs=1M"
            sh "echo '63,' | /sbin/sfdisk --no-reread -uS -H16 -S63 #{disk_file}"
          end
          
          def fs_offset
            32256
          end
            
          task :fs do
            begin
              sudo "losetup -o #{fs_offset} /dev/loop0 #{disk_file}"

              linux_partition_info = `/sbin/sfdisk -l #{disk_file}`.scan(%r{#{disk_file}.*Linux}).first
              fs_block_size = linux_partition_info.split[4].to_i
            
              sudo "/sbin/mke2fs -L #{root_label} -jqF /dev/loop0 #{fs_block_size}"
            ensure
              sudo "losetup -d /dev/loop0"
            end
          end

          task :grub_files do
            install_grub :stage_files => %w{e2fs_stage1_5 stage?}
          end

          task :copy => "dist:clean" do
            mkdir_p mount_dir
            begin
              sudo "mount -o loop,offset=#{fs_offset} #{disk_file} #{mount_dir}"
              sudo "rsync -av #{image_dir}/ #{mount_dir}"
              sh "df -h #{mount_dir}"
            ensure
              sudo "umount #{mount_dir}"
            end
          end


          task :grub do
            IO.popen("sudo grub --device-map=/dev/null","w") { |grub| 
              grub.puts "device (hd0) #{disk_file}"
              grub.puts "root (hd0,0)"
              grub.puts "setup (hd0)"
              grub.puts "quit"
            }
          end

        end

        desc "Create a disk image"
        task :disk => %w{file fs grub_files copy grub}.collect { |t| "disk:#{t}" }

      end

      desc "Configure the pigebox image"
      task :configure
      # Dependencies with configure helper below

      task :rebuild => [ :clean, :bootstrap, :configure ]
      
      namespace :rebuild do

        desc "Fully rebuild an iso image"
        task :iso => [:rebuild, "dist:iso"]

        desc "Fully rebuild a disk image"
        task :disk => [:rebuild, "dist:disk"]

      end

    end

    configure :network do
      install "etc", "hosts", "hostname"
      install "etc/network", "network/interfaces"
      
      if ssh_pubkey
        mkdir "root/.ssh"
        install "root/.ssh/authorized_keys", ssh_pubkey
      end

      mkdir "/var/etc"
      install "/var/etc", "/etc/resolv.conf"
      link "/var/etc/resolv.conf", "/etc/resolv.conf"

      # dhclient-script is customized to modify /var/etc/resolv.conf
      install "etc/dhcp3", "dhcp3/dhclient.conf", "dhcp3/dhclient-script"

      # Use same timezone than build machine
      install "/etc/", "/etc/timezone", "/etc/localtime"
    end

    configure :fstab do
      mkdir "/srv/pige"
      install "etc", "fstab"
      link "/proc/mounts", "/etc/mtab"

      # to create subdirectories lost by reboot
      install "etc/init.d/preparetmpfs", "init.d/preparetmpfs"
      chroot do |chroot|
        chroot.sudo "update-rc.d preparetmpfs defaults 15"
      end
    end

    configure :packages do
      install "etc/apt/sources.list.d", "apt/tryphon.list"

      chroot do |chroot|
        chroot.sudo "apt-get update"
      end
    end

    configure :kernel do
      install "etc", "kernel-img.conf"

      packages = %w{linux-image-2.6-686 grub}
      chroot do |chroot|
        chroot.apt_install packages
      end
    end

    configure :alsa_backup do
      mkdir "etc/pige"
      install "etc/pige", "pige/alsa.backup.config"
      install "etc/init.d/alsa.backup", "pige/alsa.backup.init.d"
      install "etc/default/alsa.backup", "pige/alsa.backup.default"

      # TODO use a debian package
      chroot do |chroot|
        chroot.apt_install %w{rubygems ruby-dev build-essential rake libasound2 libsndfile1 libdaemons-ruby1.8 libffi-dev}
        chroot.sudo "ln -fs /usr/bin/rake1.8 /usr/bin/rake"
        
        chroot.gem_install %w{ffi bones newgem cucumber SyslogLogger daemons}
        chroot.gem_install "albanpeignier-alsa-backup", :source => "http://gems.github.com"
        
        chroot.sudo "ln -fs /var/lib/gems/1.8/bin/alsa.backup /usr/bin/alsa.backup"
        chroot.sudo "ln -fs /usr/lib/libasound.so.2.0.0 /usr/lib/libasound.so"
        chroot.sudo "ln -fs /usr/lib/libsndfile.so.1.0.17 /usr/lib/libsndfile.so"
        chroot.sudo "update-rc.d alsa.backup defaults"

        chroot.sudo "adduser --system --no-create-home --disabled-password --disabled-login pige"
        chroot.sudo "adduser pige audio"
      end
    end

    configure :pige_cron do
      # TODO create a debian package 'pige'
      mkdir "/usr/share/pige/tasks"
      install "/usr/share/pige/tasks", "pige/pige.rake"
      
      mkdir "/usr/share/pige/bin"
      install "/usr/share/pige/bin/", "pige/pige-cron"
      install "/etc/cron.d/pige", "pige/pige.cron.d"
    end
    
    configure :http do
      chroot do |chroot|
        chroot.apt_install %w{nginx}
      end
      install "etc/nginx/sites-available/default", "nginx/default-site"
      link "/srv/pige", "/var/www/pige"
    end
    
    configure :munin do
      chroot do |chroot|
        chroot.apt_install %w{munin munin-node}
      end
      install "etc/munin", "munin/munin-node.conf", "munin/munin.conf"
      link "/usr/share/munin/plugins/df", "/etc/munin/plugins/df"
    end
  end

  def configure(task_name, &block)
    namespace name do
      namespace :configure do
        task task_name, &block
      end
      task :configure => "configure:#{task_name}"
    end
  end

end

load 'config' if File.exists?('config')

ImageBuilder.new(:pigebox)

desc "Install some of required tools to create pigebox images"
task :setup do
  required_packages = %w{debootstrap mkisofs}
  sudo "apt-get install #{required_packages.join(' ')}"
end
