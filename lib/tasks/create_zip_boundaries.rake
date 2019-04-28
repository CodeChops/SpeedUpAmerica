require 'mechanize'
require 'json'
require 'rake'

task :populate_zip_boundaries => [:environment] do
  puts "Right now we're only including zip codes that overlap with Lane County, OR."

  # keep track of the number of zip codes added to ZipBoundary
  add_count = 0

  # read in the JSON line by line
  IO.foreach("/suyc/db/data/us_zip_codes.json") { |line|
    
    # parse the line
    data = JSON.parse(line)

    # if the zip code isn't in Oregon, ignore it
    next if data["state_code"] != "OR"

    # if the zip code doesn't include parts of Lane county, ignore it
    next if !(data["county"].include? "Lane County")

    # if it's already in ZipBoundary, ignore it
    next if ZipBoundary.where(name: data["zip_code"]).present?

    # clean up the lat long pairs
    bounds = remove_nulls(clean_bounds(data["zcta_geom"]))

    zip_type = "Polygon"
    if data["zcta_geom"].start_with?('MULTIPOLYGON')
      zip_type = "MultiPolygon"
    end

    # otherwise, create a new record
    ZipBoundary.create(name: data["zip_code"], zip_type: zip_type, bounds: bounds)

    # increment the count
    add_count += 1
  }

  puts "Added #{add_count} zip codes."
 
end

# clean up the JSON data into the proper format
def clean_bounds(b)
  if b.start_with?('MULTIPOLYGON')
    cords = b.gsub('MULTIPOLYGON(((', '').gsub(')))', '')
    cords = [cords.split(',').collect{|c| c.split(" ").map(&:to_f).reverse()}]
    
    return cords
  else
    cords = b.gsub('POLYGON((', '').gsub('))', '')
    cords = [cords.split(',').collect{|c| c.split(" ").map(&:to_f).reverse()}]

    return cords
  end
end

# handle null values. for now, we will just delete those points on the boundary
def remove_nulls(all_bounds)
  new_bounds = Array.new
  all_bounds.each do |zip_bounds|
    zip_bounds.each do |item|
      if ((item[0] === 0.0) || (item[1] === 0.0))
        puts "Found a null!"
      else
        new_bounds << item.map(&:to_f)
      end
    end
  end
  return new_bounds
end


