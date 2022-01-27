class WorkflowRunRowComponent < ApplicationComponent
  SOURCE_NAME_PAYLOAD_MAPPING = {
    'pull_request' => ['pull_request', 'number'],
    'Merge Request Hook' => ['object_attributes', 'id'],
    'push' => ['head_commit', 'id'],
    'Push Hook' => ['commits', 0, 'id']
  }.freeze

  SOURCE_URL_PAYLOAD_MAPPING = {
    'pull_request' => ['pull_request', 'url'],
    'Merge Request Hook' => ['object_attributes', 'url'],
    'push' => ['head_commit', 'url'],
    'Push Hook' => ['commits', 0, 'url']
  }.freeze

  attr_reader :workflow_run, :status

  def initialize(workflow_run:)
    super

    @workflow_run = workflow_run
    @status = workflow_run.status
  end

  def hook_action
    return payload['action'] if pull_request_with_allowed_action
    return payload.dig('object_attributes', 'action') if merge_request_with_allowed_action
  end

  def hook_event
    parsed_request_headers['HTTP_X_GITHUB_EVENT'] ||
      parsed_request_headers['HTTP_X_GITLAB_EVENT']
  end

  def repository_name
    payload.dig('repository', 'full_name') || # For GitHub
      payload.dig('repository', 'name') # For GitLab
  end

  def repository_url
    payload.dig('repository', 'html_url') || # For GitHub
      payload.dig('repository', 'git_http_url') || payload.dig('repository', 'url') # For GitLab
  end

  def event_source_name
    payload.dig(*SOURCE_NAME_PAYLOAD_MAPPING[hook_event])
  end

  def event_source_url
    payload.dig(*SOURCE_URL_PAYLOAD_MAPPING[hook_event])
  end

  def formatted_event_source_name
    case hook_event
    when 'pull_request', 'Merge Request Hook'
      "##{event_source_name}"
    else
      event_source_name
    end
  end

  def status_title
    case status
    when 'running'
      'Status: running'
    when 'success'
      'Status: success'
    else
      'Status: failed'
    end
  end

  def status_icon
    classes = case status
              when 'running'
                ['fas', 'fa-running']
              when 'success'
                ['fas', 'fa-check', 'text-primary']
              else
                ['fas', 'fa-exclamation-triangle', 'text-danger']
              end
    classes.join(' ')
  end

  private

  def parsed_request_headers
    workflow_run.request_headers.split("\n").each_with_object({}) do |h, headers|
      k, v = h.split(':')
      headers[k] = v.strip
    end
  end

  def payload
    @payload ||= JSON.parse(workflow_run.request_payload)
  rescue JSON::ParserError
    { payload: 'unparseable' }
  end

  def pull_request_with_allowed_action
    hook_event == 'pull_request' &&
      ScmWebhookEventValidator::ALLOWED_PULL_REQUEST_ACTIONS.include?(payload['action'])
  end

  def merge_request_with_allowed_action
    hook_event == 'Merge Request Hook' &&
      ScmWebhookEventValidator::ALLOWED_MERGE_REQUEST_ACTIONS.include?(payload.dig('object_attributes', 'action'))
  end
end