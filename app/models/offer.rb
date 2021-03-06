# coding: utf-8

class Offer
	include Mongoid::Document
  include Mongoid::MoneyField

	belongs_to :advertiser
	#field :advertiser_id, type: Fields::Serializable::ForeignKeys::Object, default: lambda{current_user.id}
	embeds_many :targets
	embeds_many :adverts #TODO: подумать над автообъявлениями (к примеру на основе яндекс.маркета)
	field :adverts_sizes, type: Array, default: []
	#has_and_belongs_to_many :grounds
	has_many :ground_offers, dependent: :delete
	has_many :achievements
	belongs_to :category

	field :title, type: String
  field :url, type: String, default: ''
  field :landing_url, type: String, default: ''
	field :description, type: String, default: ''

	field :cookie_time, type: Integer, default: 90

	field :clicks, type: Integer, default: 0
  money_field :payments
	money_field :epc

	field :is_adult, type: Boolean, default: false
	field :is_doubtful, type: Boolean, default: false

  field :redirect_options, type: String
  field :accept_custom_urls, type: Boolean, default: true

  field :achievement_task_marker, type: String
  index({ achievement_task_marker: 1 }, { unique: true })

	field :auto_accept_grounds, type: Boolean, default: true
  field :excepted_categories_ids, type: Array, default: []
  field :excepted_ground_types, type: Array, default: []

  field :hash_key, type: String, default: ->{ rand(36**20).to_s(36) }

  field :active, type: Boolean, default: true
  index({active: 1 }, { background: true })
  scope :active, where(active: true)
  def active?
    self.active
  end

  scope :active_n_accepted, where(active: true).where(:moderated_state => :accepted)

  mount_uploader :logo, OfferLogoUploader

	def excepted_categories
		self.excepted_categories_ids
	end

	def excepted_categories= (ids)
		self.excepted_categories_ids = ids.reject(&:blank?)
	end

  scope :for_advert_size, ->(size) { any_in(:adverts_sizes => [size]).desc(:epc) }

	def update_adverts_sizes
		self.adverts_sizes = self.adverts.where(moderated_state: :accepted).collect{|a| a.sizes}.flatten.compact
		self.save
	end

	def change_advertiser!(new_advertiser)
		old_advertiser_id = self.advertiser_id
		self.advertiser = new_advertiser
		self.save!
		StatCounter.where(:offer_id => self.id, :advertiser_id => old_advertiser_id).update(advertiser_id: new_advertiser.id)
    self.achievements.update(advertiser_id: new_advertiser.id)
  end

  def self.find_by_mark(marker)
    return self.where(:achievement_task_marker => marker).first
  end

  def find_marked_target(marker)
    return targets.where(:achievement_task_marker => marker).first
  end

	MODERATED_ATTRS = %w[title url landing_url category_id logo]
  MODERATED_ATTRS_INFO = {'logo' => {:type => :carrierwave_image} }
	MODERATED_EDIT_FIELDS = [:is_adult, :is_doubtful]
	include IsModerated
end
