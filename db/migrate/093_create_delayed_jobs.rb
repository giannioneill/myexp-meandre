class CreateDelayedJobs < ActiveRecord::Migration
  def self.up
    create_table :delayed_jobs, :force => true do |t|
      t.column :priority, :integer, :default => 0      # Allows some jobs to jump to the front of the queue
      t.column :attempts, :integer, :default => 0      # Provides for retries, but still fail eventually.
      t.column :handler, :text                      # YAML-encoded string of the object that will do work
      t.column :last_error, :string                   # reason for last failure (See Note below)
      t.column :run_at, :datetime                       # When to run. Could be Time.now for immediately, or sometime in the future.
      t.column :locked_at, :datetime                    # Set when a client is working on this object
      t.column :failed_at, :datetime                    # Set when all retries have failed (actually, by default, the record is deleted instead)
      t.column :locked_by, :string                    # Who is working on this object (if locked)
    end

    add_index :delayed_jobs, :locked_by
  end

  def self.down
    drop_table :delayed_jobs
  end
end
