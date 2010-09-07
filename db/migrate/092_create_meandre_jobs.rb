class CreateMeandreJobs < ActiveRecord::Migration
  def self.up
    create_table :meandre_jobs do |t|
      t.column :inputs_data, :binary, :limit => 104857600 # in bytes; = 100MB
    end
  end

  def self.down
    drop_table :meandre_jobs
  end
end
