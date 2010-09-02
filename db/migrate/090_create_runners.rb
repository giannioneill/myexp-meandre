class CreateRunners < ActiveRecord::Migration
  def self.up
    create_table :runners do |t|
      t.column :title, :string
      t.column :description, :text
      t.column :contributor_id, :integer
      t.column :contributor_type, :string
      
      t.column :created_at, :datetime
      t.column :updated_at, :datetime

      t.column :details_type, :string
      t.column :details_id, :integer

    end
  end

  def self.down
    drop_table :runners
  end
end
