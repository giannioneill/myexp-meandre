# myExperiment: lib/file_types_handler.rb
#
# Copyright (c) 2008 University of Manchester and the University of Southampton.
# See license.txt for details.

# Helper class to deal with File types and processors.
# Based on the WorkflowTypesHandler

class FileTypesHandler
  
  # Gets all the workflow processor classes that have been defined in the \lib\file_processors directory.
  # Note: for performance reasons this is a "load once" method and thus requires a server restart if new processor classes are added.
  def self.processor_classes
    if @@processor_classes.nil?
      @@processor_classes = [ ]
      
      ObjectSpace.each_object(Class) do |c|
        if c < FileProcessors::Interface
          @@processor_classes << c
        end
      end
    end
    
    return @@processor_classes
  end

  def self.for_mime_type(type)
    if @@mime_type_map.nil?
      @@mime_type_map = {}
      processor_classes.each do |c|
        @@mime_type_map[c.mime_type] = c
      end
    end
    @@mime_type_map[type]
  end

protected

  # List of all the processor classes available.
  @@processor_classes = nil
  
  @@mime_type_map = nil
end

# We need to first retrieve all classes in the workflow_processors directory
# so that they are then accessible via the ObjectSpace.
# We assume (and this is a rails convention for anything in the /lib/ directory), 
# that filenames for example "my_class.rb" correspond to class names for example MyClass.
Dir.chdir(File.join(RAILS_ROOT, "lib/file_processors")) do
  Dir.glob("*.rb").each do |f|
    ("file_processors/" + f.gsub(/.rb/, '')).camelize.constantize
  end
end
