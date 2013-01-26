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
    "[#{severity}] compileDocuments: #{datetime.strftime($logger.datetime_format)}: #{msg}\n"
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

    downstream_tracefile = config.downstream_tracefile # String to save downstram filenames
    reqtracefile_base = config.reqtracefile_base       # string to determine the requirements tracing results

    traceable_set = TraceableSet.new

    # collect all traceables
    files.each{|f| 
        x=TraceableSet.processTracesInMdFile(f)
        traceable_set.merge(x)
    }

    undefineds=traceable_set.undefined_ids
    $logger.warn "undefined traces: #{undefineds.join(' ')}" unless undefineds.empty?


    # check duplicates
    duplicates=traceable_set.duplicate_traces
    if duplicates.count > 0
      $logger.warn "duplicated trace ids found:"
      duplicates.each{|d| d.each{|t| $logger.warn "#{t.id} in #{t.info}"}}
    end  

    # write traceables to the intermediate Tracing file
    outname="#{rootdir}/#{reqtracefile_base}.md"

    # poke ths sort order for the traceables
    traceable_set.sort_order=config.traceSortOrder if config.traceSortOrder
    # generate synopsis of traceableruby 1.8.7 garbage at end of file


    tracelist=""
    File.open(outname, "w"){|fx|
        fx.puts ""
        fx.puts "\\clearpage"
        fx.puts ""
        fx.puts "# Requirements Tracing"
        fx.puts ""
        tracelist=traceable_set.reqtraceSynopsis(:SPECIFICATION_ITEM)
        fx.puts tracelist
    }

    # output the graphxml
    # write traceables to the intermediate Tracing file
    outname="#{rootdir}/#{reqtracefile_base}.graphml"
    File.open(outname, "w") {|fx| fx.puts traceable_set.to_graphml}
    
    outname="#{rootdir}/#{reqtracefile_base}Compare.txt"
    File.open(outname, "w") {|fx| fx.puts traceable_set.to_compareEntries}

    # write the downstream_trace file - to be included in downstream - speciifcations
    outname="#{rootdir}/#{downstream_tracefile}"
    File.open(outname, "w") {|fx|
                              fx.puts ""
                              fx.puts "\\clearpage"
                              fx.puts ""
                              fx.puts "# Upstream Requirements"
                              fx.puts ""
                              fx.puts traceable_set.to_downstream_tracefile(:SPECIFICATION_ITEM)
                            } unless downstream_tracefile.nil?


    
end

# now cleanup the sources

cleaner = PandocBeautifier.new
config.input.each{|f| cleaner.beautify(f)}

# now compile the doucment
PandocBeautifier.new.generateDocument(config.input, config.outdir, config.outname, config.format, config.vars, config.editions, config.snippets)



    
