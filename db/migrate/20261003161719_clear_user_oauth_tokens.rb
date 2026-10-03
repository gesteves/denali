# Sign-in stored each user's Google OAuth token in plain text, and nothing ever
# read it. The code no longer writes it; this clears the copies already there.
# The columns themselves go in a later migration, once no running process
# still knows about them.
class ClearUserOauthTokens < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE users SET oauth_token = NULL, oauth_expires_at = NULL"
  end

  def down
    # The tokens are gone, and were never used.
  end
end
