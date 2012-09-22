#
# this mixin represents the TeX specific methods of Traceable
#
require 'rubygems'
require 'ruby-debug' if not RUBY_PLATFORM=="i386-mingw32"
require 'treetop'
require File.dirname(__FILE__) + "/class.treetophelper"
require File.dirname(__FILE__) + "/class.Traceable"
require File.dirname(__FILE__) + "/class.Traceable.md"

Treetop.load File.dirname(__FILE__) + "/mdTraceParser.treetop"


class Traceable
    


    # this generates a synopsis of traces in markdown Format
    # @param [Symbol] selectedCategory the the category of the Traceables
    #                 which shall be reported.
    def self.reqtraceSynopsis(selectedCategory)
        allTraces(selectedCategory).
            sort_by{|x| traceOrderIndex(x.id) }.
            map{|t|
                 tidm=t.id.gsub("_","-")
    
                 lContributes=t.contributes_to.
    #                  map{|c| cm=c.gsub("_","-"); "[\[#{c}\]](#RT-#{cm})"}
                       map{|c| cm=c.gsub("_","-"); "<a href=\"#RT-#{cm}\">\[#{c}\]</a>"}
    
                 ["- ->[#{t.id}] <!-- --> <a id=\"RT-#{tidm}\"/>**#{t.header_orig}**" +
    #                     "  (#{t.contributes_to.join(', ')})", "",
                          "  (#{lContributes.join(', ')})", "",
                    uptraces = t.supported_by_asTrace.
                        sort_by{|x| traceOrderIndex(x.id)}.            
                        map{|u|
                        um = u.id.gsub("_","-")
                        "    - <a href=\"#RT-#{um}\">[#{u.id}]</a> #{u.header_orig}"
                        }
                ].flatten.join("\n")
            }.join("\n\n")
    end

# this generates the todo - list

# TODO: add this method

# this method processes all traces in a particular file
# @param [String] mdFile name of the Markdown file which shall
#                 be scanned.
    def self.processTracesInMdFile(mdFile)
        
        parser=TraceInMarkdownParser.new
        parser.consume_all_input = true
        
        raw_md_code_file=File.open(mdFile)
		   raw_md_code = raw_md_code_file.readlines.join
		raw_md_code_file.close
#        print mdFile
        result = parser.parse(raw_md_code)
#        print " ... parsed"
        
        if result
            result.descendant.select{|x| x.getLabel==="trace"}.each{|c|
                id       = c.traceId.payload.text_value
                uptraces = c.uptraces.payload.text_value
                header   = c.traceHead.payload.text_value
                bodytext = c.traceBody.payload.text_value
                uptraces = c.uptraces.payload.text_value
                # Populate the Traceable entry
                theTrace = Traceable.new
                theTrace.info           = mdFile
                theTrace.id             = id
                theTrace.header_orig    = header
                theTrace.body_orig      = bodytext
                theTrace.trace_orig     = c.text_value
                theTrace.contributes_to = uptraces.gsub!(/\s*/, "").split(",")
                theTrace.category       = :SPECIFICATION_ITEM
            }
#            puts " .... finished"
            else
            puts ["","-----------", texFile, parser.failure_reason].join("\n")
        end
    end

    
end