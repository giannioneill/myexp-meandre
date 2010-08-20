# myExperiment: lib/acts_as_runner.rb
#
# Copyright (c) 2007 University of Manchester and the University of Southampton.
# See license.txt for details.

module Jits
  module Acts #:nodoc:
    module Runner #:nodoc:
      def self.included(mod)
        mod.extend(ClassMethods)
      end

      module ClassMethods
        def acts_as_runner
          has_many :jobs,
                   :as => :runner,
                   :order => "updated_at DESC"

          class_eval do
            extend Jits::Acts::Runner::SingletonMethods
          end
          include Jits::Acts::Runner::InstanceMethods
        end

        def find_by_contributor(contributor_type, contributor_id)
          find(:all, :conditions => ["contributor_type = ? AND contributor_id = ?", contributor_type, contributor_id])
        end
  
        def find_by_groups(user)
          return nil unless user.is_a?(User)
          
          runners = []
          user.all_networks.each do |n|
            runners = runners + find_by_contributor('Network', n.id)
          end
          
          return runners
        end
        
        def for_user(user)
          return [ ] if user.nil? or !user.is_a?(User)
          
          # Return the runners that are owned by the user, and are owned by groups that the user is a part of.
          runners = find_by_contributor('User', user.id)
          return runners + find_by_groups(user)
        end
     
      end

      module SingletonMethods
      end

      module InstanceMethods
        # TODO: abstract out the set of methods that define a contract for a runner and declare them here.
        # To be overridden in the specialised model object.
        # e.g: submit_job
      end
    end
  end
end

ActiveRecord::Base.class_eval do
  include Jits::Acts::Runner
end
