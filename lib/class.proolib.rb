#
# This script converts the trace-References in a markdown file
# to hot references.
#
# usage prepareTracingInPandoc <infile> <format> <outfile>
#
# Traces are formatted according to [RS_DM_008].
#
# Trace itself becomes the target, uptraces are converted to references.
#
# Traces can also be referenced by
#
#
require 'rubygems'
require 'logger'
require 'yaml'
require 'tmpdir'
require 'nokogiri'


require 'ruby-debug' #if not RUBY_PLATFORM=="i386-mingw32"

# TODO: make these patterns part of the configuration

ANY_ANCHOR_PATTERN    = /<a\s+id=\"([^\"]+)\"\/>/
ANY_REF_PATTERN       = /<a\s+href=\"#([^\"]+)\"\>([^<]*)<\/a>/

TRACE_ANCHOR_PATTERN  = /\[(\w+_\w+_\w+)\](\s*\*\*)/
UPTRACE_REF_PATTERN   = /\}\( ((\w+_\w+_\w+) (,\s*\w+_\w+_\w+)*)\)/x
TRACE_REF_PATTERN     = /->\[(\w+_\w+_\w+)\]/




#
# This mixin convertes a file path to the os Path representation
# todo maybe replace this by a builtin ruby stuff such as "pathname"
#
class String
    # convert the string to a path notation of the current operating system
    def to_osPath
        gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
    end
    
    # convert the string to a path notation of ruby.
    def to_rubyPath
        gsub(File::ALT_SEPARATOR || File::SEPARATOR, File::SEPARATOR)
    end
    
    # adding quotes around the string. Main purpose is to escape blanks
    # in file paths.
    def esc
        "\"#{self}\""
    end
end



#
# This class provides methods to tweak the reference according to the
# target document format
#
#
class ReferenceTweaker
    
    #This attribute keeps the target format
    attr_accessor :target
    
    
    private
    
    # this prepares the reference in the target format
    #
    # :string: the Id of the referenced Traceable
    def prepareTraceReferences(string)
        string.gsub(/\s*/,"").split(",").map{|trace|
            
            itrace   = mkInternalTraceId(trace)
            texTrace = mkTexTraceDisplay(trace)
            if @target == "pdf" then
                "\\hyperlink{#{itrace}}{#{texTrace}}"
            else
                "[#{trace}](\##{itrace})"
            end
        }.join(", ")
    end

    
    # this tweaks the reference-Id to be comaptible as TeX label
    # private methd
    def mkInternalTraceId(string)
        string.gsub("_","-")
    end
    
    # this tweaks the reference-id to be displayed in TeX
    # private method
    def mkTexTraceDisplay(trace)
        trace.gsub("_", "\\_")
    end
    
    public
    
    # constructor
    # :target: the target format
    #          in which the referneces shall be represented
    def initialize(target)
        @target=target
    end
    
    # this does the postprocessing
    # of the file
    def prepareFile(infile, outfile)
        
        infileIo=File.new(infile)
        text = infileIo.readlines.join
        infileIo.close
        
        #substitute the anchors
        if @target == "pdf" then
            text.gsub!(TRACE_ANCHOR_PATTERN){|m| "[#{$1}]#{$2}\\hypertarget{#{mkInternalTraceId($1)}}{}"}
        else
            text.gsub!(TRACE_ANCHOR_PATTERN){|m| "<a id=\"#{mkInternalTraceId($1)}\">[#{$1}]</a>#{$2}"}
        end
        
        #substitute arbitrary anchors
        if @target == "pdf" then
            text.gsub!(ANY_ANCHOR_PATTERN){|m| "\\hypertarget{#{mkInternalTraceId($1)}}{}"}
            else
        end
        
        #substitute arbitrary document internal references
        if @target == "pdf" then
            text.gsub!(ANY_REF_PATTERN){|m| "\\hyperlink{#{$1}}{#{mkTexTraceDisplay($2)}}"}
        else
        end
        
        # substitute the uptrace references
        text.gsub!(UPTRACE_REF_PATTERN){|m| "}(#{prepareTraceReferences($1)})"}
        
        # substitute the informal trace references
        text.gsub!(TRACE_REF_PATTERN){|m| "[#{prepareTraceReferences($1)}]"}
        
        File.open(outfile, "w"){|f| f.puts(text)}
    end
end



#
# This class handles the configuration of WortSammler framework
#

class ProoConfig
    attr_reader :input,   # An array with the input filenames
    :outdir,              # directory where to place the output files
    :outname,             # basis to determine the output files
    :format,              # array of output formats
    :traceSortOrder,      # Array of strings to determine the sort ord
    :vars                 # hash of variables for pandoc
    
    
    # constructor
    # @param [String] configFileName  name of the configfile (without .yaml)
    # @param [Symbol] configSelect Default configuration. If not specified
    #                 the very first entry in the config file
    #                 will apply.
    #                 TODO: not yet implemented.
    # @return [ProoConfig] instance
    def initialize(configFileName, configSelect=nil)
        
        configFile = File.expand_path(configFileName + ".yaml")
        basePath   = File.dirname(configFile)
        config     = YAML.load(File.new(configFile))
        
        #activeConfigs=config.select{|x| [x[:name]] & ConfigSelet}

        selectedConfig=config.first
        #TODO: check the config file
        @input          = selectedConfig[:input].map{|file| File.expand_path("#{basePath}/#{file}")}
        @outdir         = File.expand_path("#{basePath}/#{selectedConfig[:outdir]}")
        @outname        = selectedConfig[:outname]
        @format         = selectedConfig[:format]
        @traceSortOrder = selectedConfig[:traceSortOrder]
        @vars           = selectedConfig[:vars] || {}
    end
    
end


#
# This class provides the major functionalites
# Note that it is called PandocBeautifier for historical reasons
# provides methods to Process a pandoc file
#

class PandocBeautifier
    
    # the constructor
    # @param [Logger]  logger logger object to be applied.
    #                  if none is specified, a default logger
    #                  will be implemented.
    def initialize(logger=nil)
      if logger == nil
          @log = Logger.new(STDOUT)
          @log.level = Logger::WARN
          @log.datetime_format = "%Y-%m-%d %H:%M:%S"          
      else
         @log = logger
      end
    end

    # perform the beautify
    # * process the file with pandoc
    # * revoke some quotes introduced by pandoc
    # @param [String] file the name of the file to be bautified
    def beautify(file)
                
        @log.formatter = proc do |severity, datetime, progname, msg|
            "#{datetime}: #{msg}\n"
        end
        
        @log.info(" Cleaning: \"#{file}\"")

        docfile  = File.new(file)
        olddoc   = docfile.readlines.join
        docfile.close
        
        # process the file in pandoc
        cmd="pandoc -s #{file.esc} -f markdown -t markdown --atx-headers --reference-links "
        newdoc=`#{cmd}`
        
        # tweak the quoting
        if $?.success? then        
            # do this twice since the replacement
            # does not work on e.g. 2\_3\_4\_5.
            #
            newdoc.gsub!(/(\w)\\_(\w)/, '\1_\2')
            newdoc.gsub!(/(\w)\\_(\w)/, '\1_\2')
            
            # fix more quoting
            newdoc.gsub!(/\-\\>\[/, '->[')
            
            # (RS_Mdc)
            # TODO: fix Table width toggles sometimes
            if (not olddoc == newdoc) then  ##only touch the file if it is really changed
                File.open(file, "w"){|f| f.puts(newdoc)}
                File.open(file+".bak", "w"){|f| f.puts(olddoc)} # (RS_Mdc_) # remove this if needed
                @log.warn("  cleaned: \"#{file}\"")
                else
                @log.warn("was clean: \"#{file}\"")
            end
            #TODO: error handling here
            else
            @log.error("error calling pandoc - please watch the screen output")
        end
    end
    
    
    #
    # This generates the final document
    # @param [Array of String] input the input files to be processed in the given sequence
    # @param [String] outdir the output directory
    # @param [String] outname the base name of the output file. It is a basename in case the
    #                 output format requires multiple files
    # @param [Array of String] format list of formats which shall be generated.
    #                                 supported formats: "pdf", "latex", "html", "docx", "rtf"
    # @param [String] language. It is passed 
    
    def generateDocument(input, outdir, outname, format, vars)
        
        #TODO: Clarify the following
        # on Windows, Tempdir contains a drive letter. But drive letter
        # seems not to work in pandoc -> pdf if the path separator ist forward
        # slash. There are two options to overcome this
        #
        # 1. set tempdir such that it does not contain a drive letter
        # 2. use Dir.mktempdir but ensure that all provided file names
        #    use the platform specific SEPARATOR
        #
        # for whatever Reason, I decided for 2.
        
        inputs=input.map{|xx| xx.esc.to_osPath }.join(" ")  # qoute cond combine the inputs
        tempdir = Dir.mktmpdir
        
        tempfile     = "#{tempdir}/x.md".to_osPath
        tempfilePdf  = "#{tempdir}/x.TeX.md".to_osPath
        tempfileHtml = "#{tempdir}/x.html.md".to_osPath
        outfilePdf   = "#{outdir}/#{outname}.pdf".to_osPath
        outfileDocx  = "#{outdir}/#{outname}.docx".to_osPath
        outfileHtml  = "#{outdir}/#{outname}.html".to_osPath
        outfileRtf   = "#{outdir}/#{outname}.rtf".to_osPath
        outfileLatex = "#{outdir}/#{outname}.latex".to_osPath
        
        
        #todo: handle latexStyleFile by configuration
        latexStyleFile = File.dirname(File.expand_path(__FILE__))+"/../../ZSUPP_Styles/default.latex"
        latexStyleFile = File.expand_path(latexStyleFile).to_osPath
        
        #now combine the input files
        cmd="pandoc -s -S -o #{tempfile} --ascii #{inputs}" # note that inputs is already quoted
        system(cmd)
        
        vars_string=vars.map.map{|key, value| "-V #{key}=#{value}"}.join(" ")
        
        if $?.success? then
            PandocBeautifier.new().beautify(tempfile)
            
            if format.include?("pdf") then
                ReferenceTweaker.new("pdf").prepareFile(tempfile, tempfilePdf)
                
                cmd="pandoc -S #{tempfilePdf.esc} --toc --standalone --number #{vars_string}" +
                " --template #{latexStyleFile.esc} --ascii -o  #{outfilePdf.esc}"
                `#{cmd}`
            end
            
            if format.include?("latex") then
                
                ReferenceTweaker.new("pdf").prepareFile(tempfile, tempfilePdf)
                
                cmd="pandoc -S #{tempfilePdf.esc} --toc --standalone --number  #{vars_string}" +
                " --template #{latexStyleFile.esc} --ascii -o  #{outfileLatex.esc}"
                `#{cmd}`
            end
            
            if format.include?("html") then
                
                ReferenceTweaker.new("html").prepareFile(tempfile, tempfileHtml)
                
                cmd="pandoc -S #{tempfileHtml.esc} --toc --standalone --self-contained --ascii --number  #{vars_string}" +
                " -o #{outfileHtml.esc}"
                
                `#{cmd}`
            end
            
            if format.include?("docx") then
                
                ReferenceTweaker.new("html").prepareFile(tempfile, tempfileHtml)
                
                cmd="pandoc -S #{tempfileHtml.esc} --toc --standalone --self-contained --ascii --number  #{vars_string}" +
                " -o  #{outfileDocx.esc}"
                `#{cmd}`
            end
            
            if format.include?("rtf") then
                
                ReferenceTweaker.new("html").prepareFile(tempfile, tempfileHtml)
                
                cmd="pandoc -S #{tempfileHtml.esc} --toc --standalone --self-contained --ascii --number  #{vars_string}" +
                " -o  #{outfileRtf.esc}"
                `#{cmd}`
            end
            else
            
            #TODO make a try catch block kere
            
        end
        
    end

    
end


