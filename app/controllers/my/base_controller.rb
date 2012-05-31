# coding: utf-8

class My::BaseController < ApplicationController
	respond_to :html
	before_filter :authenticate_user!
	before_filter :get_user_status
	layout 'my'

	add_crumb 'Кабинет', '/'

	def index
    if current_user.class==Operator
      redirect_to moderations_url(:subdomain => :admin)
    end
	end

	protected

	def forbid
		render :status => :forbidden, :text => "Forbidden access"
	end

	def get_user_status
		@is_operator = (current_user.class==Operator)
	end
end
