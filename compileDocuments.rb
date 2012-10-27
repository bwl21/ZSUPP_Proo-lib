#
# this compiles all documents in the project


require 'rubygems'
require File.dirname(__FILE__) + '/lib/class.proolib.rb'
require File.dirname(__FILE__) + '/lib/class.Traceable.md.rb'
require 'ruby-debug' if not RUBY_PLATFORM=="i386-mingw32"


# install a global logger

$logger = Logger.new(STDOUT)
if ARGV[1] == "debug"
  $logger.level==Logger::DEBUG
else
  $logger.level = Logger::INFO
end
$logger.datetime_format = "%Y-%m-%d %H:%M:%S" 
$logger.formatter = proc do |severity, datetime, progname, msg|
    "#{datetime}: #{msg}\n"
end



# load the configuration
configFile = ARGV.first 
config     = ProoConfig.new(configFile)
rootdir    = File.dirname(configFile)

logLevel   = ARGV[1]

# find all markdown files in the project
# todo: improvle root dir by information from the config file
#files=Dir["#{rootdir}/../**/*.md"]
files = config.input

if not config.traceSortOrder.nil?

    # collect all traceables
    files.each{|f| Traceable.processTracesInMdFile(f)}

    #TODO: use Logger here
    puts "\n\undefined traces: #{Traceable.undefinedTraces.join(' ')}\n\n"

    # write traceables to the intermediate Tracing file
    outname="#{rootdir}/../ZGEN_RequirementsTracing/ZGEN_Reqtrace.md"

    # poke ths sort order for the traciables
    Traceable.sortOrder=config.traceSortOrder if config.traceSortOrder
    # generate synopsis of traceableruby 1.8.7 garbage at end of file


    tracelist=""
    File.open(outname, "w"){|fx|
        fx.puts ""
        fx.puts "\\clearpage"
        fx.puts ""
        fx.puts "# Requirements Tracing"
        fx.puts ""
        tracelist=Traceable.reqtraceSynopsis(:SPECIFICATION_ITEM)
        fx.puts tracelist
    }
	
    # outgput the graphxml
    # write traceables to the intermediate Tracing file
    outname="#{rootdir}/../ZGEN_RequirementsTracing/ZGEN_Reqtrace.graphml"
    File.open(outname, "w") {|fx| fx.puts Traceable.to_graphml}
    
    outname="#{rootdir}/../ZGEN_RequirementsTracing/ZGEN_ReqtraceToCompare.txt"
    File.open(outname, "w") {|fx| fx.puts Traceable.to_compareEntries}


end

# now cleanup the sources

cleaner = PandocBeautifier.new
config.input.each{|f| cleaner.beautify(f)}

# now compile the doucment
PandocBeautifier.new.generateDocument(config.input, config.outdir, config.outname, config.format, config.vars, config.editions, config.snippets)



    
