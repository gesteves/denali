class PhotoTerritory < ApplicationRecord
  belongs_to :photo
  belongs_to :territory
end
