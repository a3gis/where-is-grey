require 'sinatra'
require "sinatra/activerecord"
require_relative 'models/application_record'
require_relative 'models/check_in'

require 'prius'
require 'spot'
require 'dotenv' if development?

Dotenv.load if development?
Prius.load(:google_public_api_key)

class WhereIsGrey < Sinatra::Base
  register Sinatra::ActiveRecordExtension

  set :public_folder, Proc.new { File.join(root, "static") }
  set :static, true
  set :static_cache_control, [:public, max_age: 300]
  set :database_file, File.expand_path("../../config/database.yml", __FILE__)

  get '/' do
    erb :index,
        locals: {
          api_key: google_public_api_key,
          latest_check_in: latest_check_in,
          path_so_far: path_so_far
        }
  end

  private

  def google_public_api_key
    Prius.get(:google_public_api_key)
  end

  def latest_check_in
    CheckIn.order(sent_at: :asc).last
  end

  def path_so_far
    paths = []
    path = []
    CheckIn.order(sent_at: :asc).each do |check_in|
      coord = {
        lat: check_in.latitude.to_f,
        lng: check_in.longitude.to_f
      }
      path << coord

      if check_in.last_before_discontinuity?
        paths << path
        path = []
      end
    end

    unless CheckIn.order(sent_at: :asc).last.last_before_discontinuity?
      paths << path
    end

    paths
  end
end
