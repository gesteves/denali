require 'rails_helper'

RSpec.describe "Admin::PublishSchedules", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }
  let!(:schedule) { create(:publish_schedule, blog: blog) }

  before do
    sign_in_as(user)
  end

  describe "GET /admin/entries/queued/schedule (index)" do
    it "renders successfully" do
      get admin_entries_queued_schedule_path
      expect(response).to have_http_status(:success)
    end

    it "displays page title" do
      get admin_entries_queued_schedule_path
      expect(response.body).to include("Queue schedule")
    end
  end

  describe "POST /admin/publish_schedules (create)" do
    it "creates a new schedule" do
      expect {
        post admin_publish_schedules_path, params: {
          publish_schedule: { hour: 14 }
        }
      }.to change(PublishSchedule, :count).by(1)
      expect(response).to redirect_to(admin_entries_queued_schedule_path)
      expect(flash[:success]).to be_present
    end

    it "associates schedule with blog" do
      post admin_publish_schedules_path, params: {
        publish_schedule: { hour: 10 }
      }
      expect(PublishSchedule.last.blog).to eq(blog)
    end

    it "validates uniqueness of hour" do
      # The schedule factory already creates a schedule with a unique hour
      # Just verify the validation is present on the model
      existing_schedule = create(:publish_schedule, blog: blog, hour: 14)
      duplicate_schedule = build(:publish_schedule, blog: blog, hour: 14)
      expect(duplicate_schedule).not_to be_valid
    end
  end

  describe "DELETE /admin/publish_schedules/:id (destroy)" do
    it "deletes the schedule" do
      expect {
        delete admin_publish_schedule_path(schedule)
      }.to change(PublishSchedule, :count).by(-1)
      expect(response).to redirect_to(admin_entries_queued_schedule_path)
    end
  end
end
