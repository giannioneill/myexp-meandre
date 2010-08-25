class CreateMeandreInfrastructures < ActiveRecord::Migration
  def self.up
    create_table :meandre_infrastructures do |t|
      t.column :url, :string
      t.column :username, :string
      t.column :crypted_password, :string
     end
  end

  def self.down
    drop_table :meandre_infrastructures
  end
end
