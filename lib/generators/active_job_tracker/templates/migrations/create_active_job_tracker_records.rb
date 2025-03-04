class CreateActiveJobTrackerRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :active_job_tracker_records do |t|
      t.belongs_to :active_job_trackable, polymorphic: true, index: { name: "index_active_job_tracker_records_on_active_job_trackable", unique: true }

      t.string :job_id, null: false, index: true
      t.integer :status, default: 0, null: false
      t.integer :current, default: 0, null: false
      t.integer :target, default: 100, null: false

      t.text :error
      t.text :backtrace

      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
