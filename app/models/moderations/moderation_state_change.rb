# coding: utf-8

class ModerationStateChange
	include Mongoid::Document
	include Mongoid::Symbolize

	embedded_in :moderation

	field :state, type: Symbol
	field :message, type: String
	field :created_at, type: DateTime, default: -> { DateTime.now }
	symbolize :reason, :in => [:created, :updated, :checked]
	field :edit_fields, type: Hash

	belongs_to :user
end
