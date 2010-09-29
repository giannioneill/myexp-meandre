# myExperiment: lib/file_processors/interface.rb
#
# Copyright (c) 2008 University of Manchester and the University of Southampton.
# See license.txt for details.

module FileProcessors
  class Interface
    
    #MIME-type handled by this class
    def self.mime_type
      ""
    end
    
    def self.can_infer_metadata?
      false
    end
    
    def self.is_valid_file?
      false
    end

    # Begin Object Initializer

    def initialize(file_data)
      @file_data = file_data
    end

    # End Object Initializer
    
    
    # Begin Instance Methods

    

    # End Instance Methods
    
  end
end
