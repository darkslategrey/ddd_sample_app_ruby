require 'spec_helper'
require 'rspec'
require 'date'

# TODO Improve the way model requires are working
require "#{File.dirname(__FILE__)}/../../model/cargo/cargo"
require "#{File.dirname(__FILE__)}/../../model/cargo/delivery"
require "#{File.dirname(__FILE__)}/../../model/cargo/leg"
require "#{File.dirname(__FILE__)}/../../model/cargo/itinerary"
require "#{File.dirname(__FILE__)}/../../model/cargo/tracking_id"
require "#{File.dirname(__FILE__)}/../../model/cargo/route_specification"
require "#{File.dirname(__FILE__)}/../../model/location/location"
require "#{File.dirname(__FILE__)}/../../model/location/unlocode"
require "#{File.dirname(__FILE__)}/../../model/handling/handling_event"
require "#{File.dirname(__FILE__)}/../../model/handling/handling_event_type"

def handling_event_fake(location, handling_event_type)
    registration_date = Date.new(2013, 6, 21)
    completion_date = Date.new(2013, 6, 21)

    # TODO How to set the enum to be UNLOADED?
    unloaded = HandlingEventType.new()
    # TODO How is it possible to have a HandlingEvent with a nil Cargo?
    #unload_handling_event = HandlingEvent.new(unloaded, @port, registration_date, completion_date, nil)
    HandlingEvent.new(handling_event_type, location, registration_date, completion_date, nil)
end

describe "Delivery" do
    before(:each) do
      origin = Location.new(UnLocode.new('HKG'), 'Hong Kong')
      @destination = Location.new(UnLocode.new('DAL'), 'Dallas')
      arrival_deadline = Date.new(2013, 7, 1)
      @route_spec = RouteSpecification.new(origin, @destination, arrival_deadline)

      @port = Location.new(UnLocode.new('LGB'), 'Long Beach')
      legs = Array.new
      legs << Leg.new('Voyage ABC', origin, Date.new(2013, 6, 14), @port, Date.new(2013, 6, 19))
      legs << Leg.new('Voyage DEF', @port, Date.new(2013, 6, 21), @destination, Date.new(2013, 6, 24))
      @itinerary = Itinerary.new(legs)
    end

  it "Cargo is not considered unloaded at destination when there are no recorded handling events" do
    last_event = nil

    # TODO Implement derived_from once I work out static method, and calling constructor from 
    # this static method (then delete the direct call to the constructor)
    delivery = Delivery.new(@route_spec, @itinerary, nil)
    # @delivery = @old_delivery.derived_from(@route_spec, itinerary, last_event);
    delivery.is_unloaded_at_destination.should == false
  end

  it "Cargo is not considered unloaded at destination after handling unload event but not at destination" do
    delivery = Delivery.new(@route_spec, @itinerary, handling_event_fake(@port, "Unload"))
    delivery.is_unloaded_at_destination.should == false
  end

  it "Cargo is not considered unloaded at destination after handling other event at destination" do
    delivery = Delivery.new(@route_spec, @itinerary, handling_event_fake(@destination, "Customs"))
    delivery.is_unloaded_at_destination.should == false
  end

  it "Cargo is considered unloaded at destination after handling unload event at destination" do
    delivery = Delivery.new(@route_spec, @itinerary, handling_event_fake(@destination, "Unload"))
    delivery.is_unloaded_at_destination.should == true
  end

  # TODO I really don't like the presence of nil here! Should have something like
  # an 'Unknown' location object rather than nil
  it "Cargo has unknown location when there are no recorded handling events" do
    delivery = Delivery.new(@route_spec, @itinerary, nil)
    delivery.last_known_location.should == nil
  end

  it "Cargo has correct last known location based on most recent handling event" do
    delivery = Delivery.new(@route_spec, @itinerary, handling_event_fake(@destination, "Unload"))
    delivery.last_known_location.should == @destination
  end

  # TODO I really don't like the presence of nil here! Should have something like
  # an 'Unknown' location object rather than nil
  it "Cargo is not misdirected when there are no recorded handling events" do
    delivery = Delivery.new(@route_spec, @itinerary, nil)
    delivery.is_misdirected.should == false
  end

  # TODO I really don't like the presence of nil here! Should have something like
  # an 'Unknown' itinerary object rather than nil
  it "Cargo is not misdirected when it has no itinerary" do
    delivery = Delivery.new(@route_spec, nil, handling_event_fake(@destination, "Unload"))
    delivery.is_misdirected.should == false
  end

  it "Cargo is not misdirected when the last recorded handling event matches the itinerary" do
    delivery = Delivery.new(@route_spec, @itinerary, handling_event_fake(@destination, "Unload"))
    delivery.is_misdirected.should == false
  end

  it "Cargo is misdirected when the last recorded handling event does not match the itinerary" do
    delivery = Delivery.new(@route_spec, @itinerary, handling_event_fake(@destination, "Load"))
    delivery.is_misdirected.should == true
  end

  it "Cargo is not routed when it doesn't have an itinerary" do
    delivery = Delivery.new(@route_spec, nil, handling_event_fake(@destination, "Load"))
    delivery.routing_status.should == nil
  end

  it "Cargo is on track when the cargo has been routed and the last recorded handling event matches the itinerary" do
    delivery = Delivery.new(@route_spec, @itinerary, handling_event_fake(@destination, "Unload"))
    delivery.on_track?.should == true
  end
end