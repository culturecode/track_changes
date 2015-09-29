require 'track_changes/model'
require 'track_changes/controller'
require 'track_changes/attribution'

module TrackChanges
  class Engine < ::Rails::Engine
    config.to_prepare do
      ActiveRecord::Base.send :extend, TrackChanges::Model::Base
      ApplicationController.send :extend, TrackChanges::Controller::Base
    end
  end
end
