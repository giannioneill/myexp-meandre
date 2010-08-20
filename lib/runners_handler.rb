# myExperiment: lib/runner_handler.rb
#
# Copyright (c) 2008 University of Manchester and the University of Southampton.
# See license.txt for details.

#This class alows runners to register themselves (whenever they call acts_as_runner)
#so they can be used later
class RunnersHandler
  @@runner_classes = [TavernaEnactor,MeandreInfrastructure]
  
  def self.runner_classes
    @@runner_classes
  end

  def self.get_by_name(name)
    @@runner_classes.each do |c|
      return c if c.name == name
    end
    nil
  end
end
