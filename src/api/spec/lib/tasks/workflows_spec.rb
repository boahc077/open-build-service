require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'workflows' do
  # rubocop:enable RSpec/DescribeClass
  include_context 'rake'

  let!(:admin_user) { create(:admin_user, login: 'Admin') }
  let(:gitlab_request_headers) do
    <<~END_OF_HEADERS
      HTTP_X_GITLAB_EVENT: Merge Request Hook
    END_OF_HEADERS
  end
  let(:github_request_payload_opened) do
    <<~END_OF_REQUEST
      {
        "action": "opened",
        "pull_request": {
          "number": 1
        },
        "repository": {
          "full_name": "iggy/hello_world"
        }
      }
    END_OF_REQUEST
  end
  let(:github_request_payload_closed) do
    <<~END_OF_REQUEST
      {
        "action": "closed",
        "pull_request": {
          "number": 2
        },
        "repository": {
          "full_name": "iggy/hello_world"
        }
      }
    END_OF_REQUEST
  end
  let(:gitlab_request_payload_merge) do
    <<~END_OF_REQUEST
      {
        "object_kind": "merge_request",
        "event_type": "merge_request",
        "object_attributes": {
          "iid": 3,
          "action": "merge"
        },
        "repository": {
          "name": "iggy/test"
        }
      }
    END_OF_REQUEST
  end

  let!(:project_iggy_hello_world_pr1) { create(:project, name: 'home:Iggy:iggy:hello_world:PR-1') }
  let!(:project_iggy_hello_world_pr2) { create(:project, name: 'home:Iggy:iggy:hello_world:PR-2') }
  let!(:project_iggy_test_pr3) { create(:project, name: 'home:Iggy:iggy:test:PR-3') }

  let!(:workflow_run_running_pr_opened) { create(:running_workflow_run, request_payload: github_request_payload_opened) }
  let!(:workflow_run_succeeded_pr_opened) { create(:succeeded_workflow_run, request_payload: github_request_payload_opened) }
  let!(:workflow_run_failed_pr_opened) { create(:failed_workflow_run, request_payload: github_request_payload_opened) }
  let!(:workflow_run_running_pr_closed) { create(:running_workflow_run, request_payload: github_request_payload_closed) }
  let!(:another_workflow_run_running_pr_closed) { create(:running_workflow_run, request_payload: github_request_payload_closed) }
  let!(:workflow_run_running_pr_merge) { create(:running_workflow_run, request_headers: gitlab_request_headers, request_payload: gitlab_request_payload_merge) }

  describe 'cleanup_non_closed_projects' do
    let(:task) { 'workflows:cleanup_non_closed_projects' }

    it { expect { rake_task.invoke }.to change(WorkflowRun.where(status: 'running'), :count).from(4).to(1) }

    # The workflow runs defined above will create two target projects that should be deleted
    # because the corresponding PR or MR are closed/merged.
    it { expect { rake_task.invoke }.to change(Project, :count).from(3).to(1) }
  end
end
