# instiki importer
#
# WHAT IT IS
#
# this script can import an instiki wiki into fwiki.
#
# HOW TO USE IT
#
# 1. export your instiki wiki
#   a. click Export at the top of instiki page
#   b. click the Markup link to download a zip file containing all your pages
#   c. unzip the zip file to get a directory containing your pages
#
# 2. run this script on the directory created in 1c like this:
#
#   ruby import_instiki.rb my_instiki_dir/
#
# BEFORE RUNNING
#
# start fwiki at least once before running this so the database is initialized

require 'fwiki'
require 'cgi'

instiki_export_dir = ARGV.shift
unless instiki_export_dir
  puts 'usage: %s instiki_export_dir/' % File.basename($0)
  exit 1
end

markdown_filenames = Dir.entries(instiki_export_dir) - %w(. ..)
puts 'found %d instiki markdown files' % markdown_filenames.length

markdown_filenames.each do |markdown_filename|
  puts 'importing ' + markdown_filename
  contents = File.read(instiki_export_dir + '/' + markdown_filename)
  name = CGI.unescape(markdown_filename.sub(%r(\.markdown), ''))
  Page.new(:name => name, :contents => contents).save
end

puts 'done'
