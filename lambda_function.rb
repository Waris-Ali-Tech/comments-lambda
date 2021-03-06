require "bundler/setup"

require "json"
require "active_support/core_ext/hash/indifferent_access"

require_relative "services/github"
require_relative "models/comment"
require_relative "presenters/comment_presenter"
require_relative "utils/config"

# Sample Request
# {
#   "post": "which-career-should-you-pursue-in-it"
#   "name": "Tester",
#   "email": "tester@test.com", (Optional)
#   "comment": "very nice",
#   "timestamp": "2020-07-27 22:25:00",
#   "branch": "staging" (Optional. master if missing)
#   "parent_id": "asdf" (Optional)
# }

def lambda_handler(event:, context:)
  environment = ''
  environment = event['path'].tr('/','')

  params = JSON.parse(event['body']).with_indifferent_access

  config = Config.load("config.yml")

  website_repo = Github.new(access_token: config.access_token,
                      ref: params["branch"],
                      repo: config.repo,
                      comments_file_path: config.comments_file_path)

  comment = Comment.new(**params)
  website_repo.comments << comment

  commit_message = CommentPresenter.commit_message_of comment
  website_repo.push_changes(commit_message: commit_message)

  {
    statusCode: 200,
    headers: {'Content-Type': 'application/json'},
    body: {
      message: commit_message,
      comment: comment.as_json,
    }.to_json
  }

rescue StandardError => e
  {
    statusCode: 400,
    headers: {'Content-Type': 'application/json'},
    body: {
      message: e.message,
      backtrace: (e.backtrace if environment == 'staging'),
      comment: comment.as_json,
    }.compact.to_json
  }
end
