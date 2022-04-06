require "yast/rake"

Yast::Tasks.submit_to :sle15sp4

# do nothing in osc:build as it can be builds exclusivelly on s390
Rake::Task["osc:build"].clear_actions if `uname --machine` !~ /s390/

Yast::Tasks.configuration do |conf|
  # lets ignore license check for now
  conf.skip_license_check << /.*/
end
