namespace :s3 do
  desc "Updates photos metadata in S3"
  task :update_metadata => :environment do
    bucket_name = ENV['s3_bucket']
    client = Aws::S3::Client.new(access_key_id: ENV['aws_access_key_id'], secret_access_key: ENV['aws_secret_access_key'], region: ENV['s3_region'])
    images = client.list_objects_v2(bucket: bucket_name).contents
    images.each do |image|
      object = Aws::S3::Object.new(bucket_name, image.key, client: client)
      object.copy_from(bucket: bucket_name, key: image.key, cache_control: 'public, max-age=31536000, immutable', metadata_directive: 'REPLACE')
      puts "Copied #{object.key}"
    end
  end
end
