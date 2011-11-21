%w{
  radio/*.rb
  radio/psk31/*.rb
}.each do |glob|
  Dir.glob(File.expand_path(glob, File.dirname(__FILE__))).each do |filename|
    require filename
  end
end

class Radio

  PI = Math::PI.freeze
  PI2 = (8.0 * Math.atan(1.0)).freeze
  
end
