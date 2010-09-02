# myExperiment: app/models/runner.rb
#
# Copyright (c) 2008 University of Manchester and the University of Southampton.
# See license.txt for details.

class Runner < ActiveRecord::Base
  belongs_to :contributor, :polymorphic => true
  validates_presence_of :contributor
  before_save :save_details

  @details=nil

  @@runner_classes = [TavernaEnactor,MeandreInfrastructure]

  def self.runner_classes
    @@runner_classes
  end

  def self.get_class_by_name(name)
    @@runner_classes.each do |c|
      return c if c.name == name
    end
    logger.debug('No such runner class '+name.to_s)
  end


  def self.find_by_contributor(contributor_type, contributor_id)
    Runner.find(:all, :conditions => ["contributor_type = ? AND contributor_id = ?", contributor_type, contributor_id])
  end

  def self.find_by_groups(user)
    return nil unless user.is_a?(User)
    
    runners = []
    user.all_networks.each do |n|
      runners = runners + find_by_contributor('Network', n.id)
    end
    
    return runners
  end
  
  def self.for_user(user)
    return [ ] if user.nil? or !user.is_a?(User)
    
    # Return the runners that are owned by the user, and are owned by groups that the user is a part of.
    runners = Runner.find_by_contributor('User', user.id)
    return runners + find_by_groups(user)
  end

  def save_details
    self.details.save!
    self.details_type = details.class.to_s
    self.details_id = details.id
  end

  def details=(d)
    @details=d
  end

  def details
    if !@details
      @runner_class = self.class.get_class_by_name(self.details_type)
      @details = @runner_class.find(self.details_id)
    end
    @details
  end

end
