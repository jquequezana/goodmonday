# coding: utf-8

class StatCounter
	include Mongoid::Document
  include Extensions::Aggregations

  belongs_to :ground, index: true
  belongs_to :offer, index: true
  belongs_to :advertiser, index: true
  belongs_to :webmaster, index: true

  field :date, type: Date
  field :sub_id, type: String
  field :target_id, type: Moped::BSON::ObjectId

  field :clicks, type: Integer, default: 0
  field :targets, type: Integer, default: 0
  field :income, type: Integer, default: 0 #доход вебмастера, в копейках (cents), ибо проще считать
  field :expenditure, type: Integer, default: 0 #расход рекламодателя, в копейках (cents), ибо проще считать

  index({date: -1 }, { background: true })
  index({sub_id: 1 }, { background: true })
  index({ webmaster_id: 1, date: 1 }, { background: true })
  index({ adversiter_id: 1, date: 1 }, { background: true })

  def self.register_click(ground, offer, sub_id)
    StatCounter.find_or_create_by(ground_id: ground.id, offer_id: offer.id, advertiser_id: offer.advertiser.id, webmaster_id: ground.webmaster.id, date: Date.today, sub_id: sub_id).inc(:clicks, 1)
    StatCounter.find_or_create_by(ground_id: ground.id, offer_id: offer.id, advertiser_id: offer.advertiser.id, webmaster_id: ground.webmaster.id, date: Date.new(0), sub_id: sub_id).inc(:clicks, 1)
  end
end
