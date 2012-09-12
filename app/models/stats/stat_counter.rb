class StatCounter
	include Mongoid::Document

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

  def self.group_by(key_field, opts = {})
    h = {}

    group_h = {}
    group_h['_id'] = "$#{key_field.to_s}"
    agregation_methods = [:first, :last, :max, :mix, :avg, :sum, :push] #http://docs.mongodb.org/manual/reference/aggregation/group/#_S_group
    agregation_methods.each do |method|
      if opts[method]
        opts[method].each do |field|
          field = field.to_s
          group_h["#{field}_#{method}"] = {"$#{method}" => "$#{field}"}
        end
      end
    end
    h["$group"] = group_h

    if opts[:cond]
      h["$match"] = opts[:cond]
    end

    if opts[:sort_asc]
      h["$sort"] = {} unless h["$sort"]
      opts[:sort_asc].each do |field|
        field = field.to_s
        h["$sort"]["$#{field}"] = 1
      end
    end
    if opts[:sort_desc]
      h["$sort"] = {} unless h["$sort"]
      opts[:sort_desc].each do |field|
        field = field.to_s
        h["$sort"]["$#{field}"] = -1
      end
    end

    collection.aggregate(h)
  end

  def self.inst()
  end
end
