
require "lib/class.proolib.rb"
require 'ruby-debug' if not RUBY_PLATFORM=="i386-mingw32"


foo = Freemind.new
doc = foo.openFile("../SP_WebStructure/SP_WebStructure.mm")

File.open("../ZGEN_RequirementsTracing/SP_WebStructure.md", "w"){|f|
    f.puts ""
    f.puts doc.xpath("//node").map{|x|x.to_markdown}.join("\n\n")
}
