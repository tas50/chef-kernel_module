#
# Cookbook Name:: kernel_module
# Resource:: default
#
# Copyright 2016-2018, Shopify Inc.
# Copyright 2018, Chef Software, Inc.

property :modname, String, name_property: true, identity: true
property :load_dir, String, default: '/etc/modules-load.d'
property :unload_dir, String, default: '/etc/modprobe.d'

# Load kernel module, and ensure it loads on reboot
action :install do
  directory new_resource.load_dir do
    recursive true
  end

  file "#{new_resource.load_dir}/#{new_resource.modname}.conf" do
    content "#{new_resource.modname}\n"
    notifies :run, 'execute[update initramfs]'
  end

  execute 'update initramfs' do
    command initramfs_command
    action :nothing
  end

  new_resource.run_action(:load)
end

# Unload module and remove module config, so it doesn't load on reboot.
action :uninstall do
  file "#{new_resource.load_dir}/#{new_resource.modname}.conf" do
    action :delete
    notifies :run, 'execute[update initramfs]'
  end

  file "#{new_resource.unload_dir}/blacklist_#{new_resource.modname}.conf" do
    action :delete
    notifies :run, 'execute[update initramfs]'
  end

  execute 'update initramfs' do
    command initramfs_command
    action :nothing
  end

  new_resource.run_action(:unload)
end

# Blacklist kernel module
action :blacklist do
  file "#{new_resource.unload_dir}/blacklist_#{new_resource.modname}.conf" do
    content "blacklist #{new_resource.modname}"
    notifies :run, 'execute[update initramfs]'
  end

  execute 'update initramfs' do
    command initramfs_command
    action :nothing
  end

  new_resource.run_action(:unload)
end

# Load kernel module
action :load do
  unless module_loaded?
    converge_by("load kernel module #{new_resource.modname}") do
      shell_out!("modprobe #{new_resource.modname}")
    end
  end
end

# Unload kernel module
action :unload do
  if module_loaded?
    converge_by("unload kernel module #{new_resource.modname}") do
      shell_out!("modprobe -r #{new_resource.modname}")
    end
  end
end

action_class do
  # determine the correct command to regen the initramfs based on platform
  # @return [String]
  def initramfs_command
    if platform_family?('debian')
      'update-initramfs -u'
    else
      'dracut -f'
    end
  end

  # see if the module is listed in /proc/modules or not
  # @return [Boolean]
  def module_loaded?
    /^#{new_resource.modname}/.match?(::File.read('/proc/modules'))
  end
end
