class CreateTavernaJobs < ActiveRecord::Migration
  def self.up
    create_table :taverna_jobs do |t|
      t.column :inputs_uri, :string
      t.column :inputs_data, :binary, :limit => 104857600 # in bytes; = 100MB
      t.column :outputs_uri, :string
    end
  end

  def self.down
    drop_table :taverna_jobs
  end
end
