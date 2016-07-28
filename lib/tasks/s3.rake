namespace :s3 do
  desc "Updates entry meta data"
  task :update_metadata => :environment do
    bucket_name = ENV['s3_bucket']
    client = Aws::S3::Client.new(access_key_id: ENV['aws_access_key_id'], secret_access_key: ENV['aws_secret_access_key'], region: ENV['s3_region'])
    images = client.list_objects_v2(bucket: bucket_name).contents

    images.each do |image|
      object = Aws::S3::Object.new(bucket_name, image.key, client: client)
      object.copy_from(bucket: bucket_name, key: image.key, cache_control: 'max-age=31536000, public', content_type: object.content_type, acl: 'public-read', metadata_directive: 'REPLACE')
      puts "Copied #{object.key}"
    end
  end
end
