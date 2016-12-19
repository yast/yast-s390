require "yast/rake"

# do nothing in osc:build as it can be builds exclusivelly on s390
if `uname --machine` !~ /s390/
  Rake::Task["osc:build"].clear_actions
end

Yast::Tasks.configuration do |conf|
  #lets ignore license check for now
  conf.skip_license_check << /.*/
end
