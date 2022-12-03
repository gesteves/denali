json.set! 'version', '2.0'
json.set! 'software' do
  json.set! 'name', 'Denali'
  json.set! 'version', @release_version
end
json.set! 'protocols', ['activitypub']
json.set! 'services' do
  json.set! 'outbound', []
  json.set! 'inbound', []
end
json.set! 'usage' do
  json.set! 'users' do
    json.set! 'total', @users
    json.set! 'activeMonth', @users
    json.set! 'activeHalfyeah', @users
  end
  json.set! 'localPosts', @entries
end
json.set! 'openRegistrations', false
json.set! 'metadata', {}
