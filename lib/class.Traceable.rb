#
# This class represents the management of Traceable object
#

require 'rubygems'
require 'nokogiri'

class Traceable
    include Comparable
    
    # the slot
    @@slot = :default
    @@slots = []
    @@slots << @@slot
    
    # the traces
    @@traces={}
    @@traces[@@slot]= {}
    
    # the list of supporters
    # supporters for foo 0 @@supported_by["foo"]
    @@supported_by={}
    @@supported_by[@@slot] = {}
    
    
    # define the sort order policy
    # it is the same for all slots
    @@sortOrder=[]
    
    # String: The trace-Id
    attr_accessor :id
    # string: the alternative Id, used e.g. for the constraint number
    attr_accessor :alternative_id
    # String: The header in plain text
    attr_accessor :header_plain
    # String: The header in original format
    attr_accessor :header_orig
    # String: The body in plain text
    attr_accessor :body_plain
    # String: he body in original format
    attr_accessor :body_orig
    # Array of Strings: The uplink as an array of Trace-ids
    attr_accessor :contributes_to
    # String: the Traceable in its original format
    attr_accessor :trace_orig
    # String: origin of the entry
    attr_accessor :orgin
    # String: category of the entry
    attr_accessor :category
    # String: info on the entry
    attr_accessor :info



    public
    # set the active slot. Traceable supports multiple systems of traces.
    # each system is denoted by a slot.
    # @param [symbol] slot denotes the newly active slot
    def self.slot= (slot)
        @@slot=slot
        if @@traces[@@slot].nil?
            @@slots << slot
            @@traces[@@slot]= {}
            @@supported_by[@@slot] = {}
        end
    end
    
    # get the active slot. Traceable supports multiple systems of traces.
    # each system is denoted by a slot.
    # @return [symbol]  denotes the currently active slot
    def self.slot
        @@slot
    end

    # return the list of active slots
    # @return [Array of Symbol] the list of currenly active slots
    def self.slots
        @@slots.sort
    end
    
    # this adjusts the sortOrder
    # @param [Array of String ] sortOrder is an array of strings
    # if a traceId starts with such a string
    # it is placed according to the sequence
    # in the array. Otherwise it is sorted at the end
    def self.sortOrder= (sortOrder)
       @@sortOrder=sortOrder
    end




    # this determines the sort order index of a trace
    # it depends on the class variable @@sortOrder which
    # needs to be set in advance by the method sortOrder=
    # @param [String] trace the id of a Traceable for which
    # the sort order index shall be coumputed.‚
    def self.traceOrderIndex(trace)
       global=@@sortOrder.index{|x| trace.start_with? x} ||
          (@@sortOrder.length+1)

    # add the {index} of the trace to  
       orderId = [global.to_s.rjust(5,"0"),trace].join("_")
       orderId
    end
    
    
    # this sets the trace id. It also registers the Traceable
    # also flags dupliacate definitions
    # @param [String] name the name under which the given Traceable shall be registred. The traceable is also registered
    def id=(name)
        @id=name
        # TODO: use logger here.

        if not @@traces[@@slot][name].nil?
            puts "\nduplicate requirement id #{name}"
            puts @@traces[@@slot][name].info
            puts @@traces[@@slot][name].header_orig

            puts self.info
            puts self.header_orig
            
        end
        @@traces[@@slot][name]=self
    end
    
    # the constructor
    def initialize
        if self.class.slot.nil?
            self.class.slot=(:default)
        end
        @contributes_to={}
    end
    
    # delivers an array of Traceables
    # @return [Array of Traceable] an array of Traceable which are supported
    #                              by the current instance (the downlinks)
    def contributes_to_asTrace
        @contributes_to.map{|x| @@traces[@@slot][x]}.compact
    end
     
    # @return [Array of Traceable] an array of Traceable which provide support
    #                              to the current instance (the uplink)
    def supported_by_asTrace
        [nil, @@supported_by[@@slot][self.id]].flatten.compact.sort
    end
    
    # this delivers an array of all
    # Traceables
    # @param [Symbol] selectedCategory the category of the deisred Traceables
    #                 if nil is given, then all Traceables are returned
    # @return [Array of Traceable] an array of the registered Traceables
    #                              of the selectedCategory
    def self.allTraces(selectedCategory= nil)
        @@traces[@@slot].values.select{|x| selectedCategory==nil or x.category == selectedCategory}.sort
    end

    # build the inverse constributes
    # @param [Array of String] uptraces list of id which contribute to the
    #                                   current Traceable. Note that this
    #                                   cannot be a Traceable to support
    #                                   forward references   
    def contributes_to=(uptraces)
        @contributes_to=uptraces
        uptraces.each{|u| addContribute(u)}
    end

    # define the comparison to makeit really comaprable
    # @param [Traceable] other the other traceable for comparison.
    def <=> (other)
       @id <=> other.id
    end


    # this lists unresolvable traces
    # @return [Array of String] the list of the id of undefined Traces
    #         traces which are marked as uptraces but do not exist.
    def self.undefinedTraces
        @@supported_by[@@slot].keys.select{|t| not @@traces[@@slot].has_key?(t)}
    end


    private
    # handle the uptraces
    def addContribute(traceId)
        # check if it is the first supporter
        @@supported_by[@@slot][traceId] = [] if @@supported_by[@@slot][traceId].nil?
        @@supported_by[@@slot][traceId] << self
    end
    
    public
    # export the trace as graphml for yed
    # @return - the requirements tree in graphml
    def self.to_graphml
      f = File.open("#{File.dirname(__FILE__)}/../templates/requirementsSynopsis.graphml")
      doc = Nokogiri::XML(f)
      f.close
      
      graph=doc.xpath("//xmlns:graph").first

      # generate all nodes
      self.allTraces(nil).each{|theTrace|
        n_node = Nokogiri::XML::Node.new "node", doc
        n_node["id"] = theTrace.id
        n_data = Nokogiri::XML::Node.new "data", doc
        n_data["key"]= "d6"
        n_ShapeNode = Nokogiri::XML::Node.new "y:ShapeNode", doc
        n_NodeLabel = Nokogiri::XML::Node.new "y:NodeLabel", doc
        n_NodeLabel.content = "[#{theTrace.id}] #{theTrace.header_orig}"
        n_ShapeNode << n_NodeLabel
        n_data << n_ShapeNode
        n_node << n_data
        graph << n_node
        
       theTrace.contributes_to_asTrace.each{|up|
         n_edge=Nokogiri::XML::Node.new "edge", doc
         n_edge["source" ] = theTrace.id
         n_edge["target" ] = up.id
         n_edge["id"     ] = "#{up.id}_#{theTrace.id}"
         graph << n_edge
         }    
      }
      xp(doc).to_xml
    end

    def to_marshal
        Marshal.dump([@@traces, @@supported_by])
    end
    
    def self.to_compareEntries
        @@traces[@@slot].values.sort.map{|t| "\n\n[#{t.id}]\n#{t.trace_asOneline}" }.join("\n")
    end
    
    def trace_asOneline
        trace_orig.gsub(/\s+/, " ")
    end
    
    private
    #
    # this is used to beautify an nokigiri document
    # @param [Nokogiri::XML::Document] doc - the document
    # @return [Nokogiri::XML::Document] the beautified document
    def self.xp(doc)
      xsl =<<XSL
    <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
      <xsl:output method="xml" encoding="UTF-8" indent="yes"/>
      <xsl:strip-space elements="*"/>
      <xsl:template match="/">
        <xsl:copy-of select="."/>
      </xsl:template>
    </xsl:stylesheet>
XSL


      xslt = Nokogiri::XSLT(xsl)
      out  = xslt.transform(doc)

      out
    end

end