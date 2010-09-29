# myExperiment: lib/file_processors/application_rdf_xml.rb
#
# Copyright (c) 2008 University of Manchester and the University of Southampton.
# See license.txt for details.
require 'rdf/redland'

module FileProcessors
  class FileCollection < Interface
    
    #MIME-type handled by this class
    def self.mime_type
      "application/rdf+xml"
    end
    
    def self.can_infer_metadata?
      false
    end

    def self.recognises_file?(file_data)
      return true #TODO: implement this
    end
    

    # Begin Object Initializer

    def initialize(file_data)
      super(file_data)
      @world = Redland::librdf_new_world
      Redland::librdf_world_open @world
      @storage = Redland::librdf_new_storage @world, "memory", "store", ""
      raise "failed to create storage" if !@storage
      
      @model = Redland::librdf_new_model @world, @storage, ""
      raise "failed to create model" if !@model
      
      parser = Redland::librdf_new_parser @world, "rdfxml", "", nil
      raise "failed to create parser" if !parser
      
      base_uri = Redland::librdf_new_uri @world, 'dontsegfault' #this string must not be null or librdf segfaults????
      Redland::librdf_parser_parse_string_into_model parser, file_data, base_uri, @model
    end

    # End Object Initializer
    
    
    # Begin Instance Methods
    def audio_files
      audiofiles = []
      predicate = Redland::librdf_new_node_from_uri_string @world, 'http://www.openarchives.org/ore/terms/aggregates'
      search = Redland::librdf_new_statement_from_nodes @world, nil, predicate, nil
      stream = Redland::librdf_model_find_statements @model, search
      
      while Redland::librdf_stream_end(stream) == 0
        statement = Redland::librdf_stream_get_object stream
        object = Redland::librdf_statement_get_object statement
        uri = Redland::librdf_node_get_uri object
        audiofiles << Redland::librdf_uri_to_string(uri)

        Redland::librdf_stream_next stream
      end

      return audiofiles
    end

    def valid_workflows
      workflows = []
      #Workflow.find(:all).each do |w|
        #workflows << w if w.processor_class == WorkflowProcessors::Meandre
      #end
      workflows
    end
    

    # End Instance Methods
    
  end
end
