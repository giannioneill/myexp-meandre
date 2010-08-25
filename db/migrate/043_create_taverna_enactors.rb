class CreateTavernaEnactors < ActiveRecord::Migration
  def self.up
    create_table :taverna_enactors do |t|
      t.column :url, :string
      t.column :username, :string
      t.column :crypted_password, :string
    end
  end

  def self.down
    drop_table :taverna_enactors
  end
end
