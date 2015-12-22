#!/usr/bin/env ruby_executable_hooks
def get_old_env()
  print "What environment would you like to promote?: "
  gets.to_s.downcase.chomp
end

def get_updated_env()
  print "What environment would you like to promote too?: "
  gets.to_s.downcase.chomp
end

def get_dir()
  print "Type in git directory: "
  gets.to_s.downcase.chomp
end

def run_git(old_env,new_env,dir)
  cmd = `cd #{dir} && git checkout tags/#{old_env} && git pull origin #{old_env} && git tag -d #{new_env} && git push origin :refs/tags/#{new_env} && git tag           #{new_env} && git push origin #{new_env}`

  puts cmd
end

old_env = get_old_env()
new_env = get_updated_env()
dir = get_dir()

run_git(old_env,new_env,dir)
