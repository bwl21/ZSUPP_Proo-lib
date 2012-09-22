#
#
# cleanupPandoc.rb
#
# This program performs a cleanup of pandoc sources.
# Pandoc provides this by the markdown output.
# But it has some drawbacks:
#
# * even if it it does not handle embedded "_" as markup
#   the output to pandoc quotes them.
#
#
# Author::    Bernhard Weichel (g
# Copyright:: Copyright (c) 2012 Bernhard Weichel
# License::   Distributes under the same terms as Ruby
#


require 'rubygems'
require 'ruby-debug' if not RUBY_PLATFORM=="i386-mingw32"
require 'lib/class.proolib.rb'



cleaner = PandocBeautifier.new()



file=ARGV.first.to_rubyPath

if File.file?(file)  #(RS_Mdc)
    cleaner.beautify(file)
elsif File.exists?(file)
    files=Dir[file+"/**/*.md", file+"/**/*.markdown"]
    files.each{|f| cleaner.beautify(f)}
else
   nil
end

nil  # to support debugger
