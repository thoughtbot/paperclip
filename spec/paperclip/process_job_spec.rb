require "spec_helper"
require "paperclip/process_job"

RSpec.describe Paperclip::ProcessJob do
  before do
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.logger = nil

    @thumb_path = "tmp/public/system/dummies/avatars/000/000/001/thumb/5k.png"
    File.delete(@thumb_path) if File.exist?(@thumb_path)
  end

  after do
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end

  it "processes styles marked for background processing" do
    file = File.new(fixture_file("5k.png"), "rb")
    FileUtils.cp(file, "tmp/public/system/dummies/avatars/000/000/001/original/5k.png")
    rebuild_model styles: { thumb: "100x100" },
                  only_process: [:none],
                  process_in_background: [:thumb]

    dummy = Dummy.create!
    dummy.update_columns(avatar_file_name: "5k.png")

    assert_file_not_exists(@thumb_path)
    Paperclip::ProcessJob.perform_now(dummy, "avatar")
    assert_file_exists(@thumb_path)
  end
end
