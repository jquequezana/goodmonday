class StatClickCounter
	include Mongoid::Document

  belongs_to :ground, index: true
  belongs_to :offer, index: true
  belongs_to :advertiser, index: true
  belongs_to :webmaster, index: true

  field :date, type: Date
  field :sub_id, type: String

  field :clicks, type: Integer, default: 0

  index :date
  index :sub_id

  index({ webmaster_id: 1, date: 1 })
  index({ adversiter_id: 1, date: 1 })

  self.register_click(ground, offer, sub_id)
    StatClickCounter.find_or_create_by(ground_id: ground.id, offer_id: offer.id, advertiser_id: offer.advertiser.id, webmaster_id: ground.webmaster.id, date: Date.today, sub_id: sub_id).inc(:clicks, 1)
    StatClickCounter.find_or_create_by(ground_id: ground.id, offer_id: offer.id, advertiser_id: offer.advertiser.id, webmaster_id: ground.webmaster.id, date: Date.new(0), sub_id: sub_id).inc(:clicks, 1)
  end
end
