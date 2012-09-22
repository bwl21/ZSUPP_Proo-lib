
require "lib/class.proolib.rb"
require "ruby-debug"


foo = Freemind.new
doc = foo.openFile("../SP_WebStructure/SP_WebStructure.mm")

File.open("../ZGEN_RequirementsTracing/SP_WebStructure.md", "w"){|f|
    f.puts ""
    f.puts doc.xpath("//node").map{|x|x.to_markdown}.join("\n\n")
}
