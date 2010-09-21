# myExperiment: lib/file_processors/application_rdf_xml.rb
#
# Copyright (c) 2008 University of Manchester and the University of Southampton.
# See license.txt for details.

module FileProcessors
  class ApplicationRdfXml < Interface
    
    #MIME-type handled by this class
    def self.mime_type
      "application/rdf+xml"
    end
    
    def self.can_infer_metadata?
      false
    end
    

    # Begin Object Initializer

    def initialize(file_data)
      super(file_data)
    end

    # End Object Initializer
    
    
    # Begin Instance Methods
    def get_audio_files
      'audiofile1.mp3'
    end
    

    # End Instance Methods
    
  end
end
