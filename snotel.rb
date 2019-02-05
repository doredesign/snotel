Bundler.require(:default)
require "csv"
argv = Rationalist.parse(ARGV, boolean: %w[f d])
# args:
# snotel index, default 0
#
# flags:
#   -d daily graph
#   -f force graph generation

class Location
  LOCATIONS = [
    {
      title: "June Lake snotel (3440 ft)",
      snotel_id: "553",
    },
    {
      title: "Spirit Lake snotel (3520 ft)",
      snotel_id: "777",
    },
    {
      title: "Swift Creek snotel (4440 ft)",
      snotel_id: "1012",
    },
    {
      title: "Sheep Canyon snotel (3990 ft)",
      snotel_id: "748",
    },
  ]

  TEMPLATES = {
    url: "https://wcc.sc.egov.usda.gov/reportGenerator/view_csv/customSingleStationReport/hourly/%{id}:WA:SNTL|id=%22%22|name/-167,0/WTEQ::value,SNWD::value,PREC::value,TOBS::value",
    daily_url: "https://wcc.sc.egov.usda.gov/reportGenerator/view_csv/customSingleStationReport/daily/%{id}:wa:SNTL/CurrentWY,0/WTEQ::value,SNWD::value,PREC::value,TOBS::value,TMAX::value,TMIN::value,TAVG::value",
  }

  def self.hash_from_index(index)
    hash = LOCATIONS[index.to_i]
    # hash[:url] = TEMPLATES[:url] % {id: hash[:snotel_id]}
    hash[:url] = format_str(TEMPLATES[:url], id: hash[:snotel_id])
    hash[:daily_url] = format_str(TEMPLATES[:daily_url], id: hash[:snotel_id])
    hash
  end

  private

  def self.format_str(str, values)
    new_str = str.dup
    values.each do |key, value|
      new_str = new_str.sub(/%{#{key}}/, value)
    end
    new_str
  end
end

@location_id = argv[:_][0] || 0
@location = Location.hash_from_index @location_id
DAILY_START_DATE = Date.parse("2018-11-20").freeze
LABEL_COUNT = 11.freeze

def execute(command_str)
  puts command_str
  `#{command_str}`
end

def generate_graph(csv_string, filename)
  g = Gruff::Line.new
  g.title = @location[:title]
  index = 0
  labels = {}
  snow_depth = []
  dates = []
  CSV.parse(csv_string, headers: true) do |row|
    data_point = row["Snow Depth (in)"]
    next unless data_point

    datetime = DateTime.parse row["Date"]
    date_str = datetime.to_date.to_s
    snow_depth << data_point.to_i

    unless dates.include?(date_str)
      labels[index] = datetime.strftime("%-m/%-d")
      dates << date_str
    end
    index += 1
  end
  g.labels = labels
  g.data "Snow depth (in)", snow_depth

  g.write(filename)
end

def generate_daily_graph(csv_string, filename)
  g = Gruff::Line.new
  g.title = @location[:title]
  index = 0
  labels = {}
  snow_depth = []
  dates_count = 0
  CSV.parse(csv_string, headers: true) do |row|
    datetime = DateTime.parse row["Date"]
    next if datetime < DAILY_START_DATE

    dates_count += 1
  end

  label_every = dates_count / (LABEL_COUNT - 2)
  CSV.parse(csv_string, headers: true) do |row|
    data_point = row["Snow Depth (in) Start of Day Values"]
    next unless data_point

    datetime = DateTime.parse row["Date"]
    next if datetime < DAILY_START_DATE
    snow_depth << data_point.to_i

    # first, last, and periodic
    if index == 0 || index == (dates_count - 2) || index % label_every == 0
      labels[index] = datetime.strftime("%-m/%-d")
    end
    index += 1
  end
  g.labels = labels
  g.data "Snow depth (in)", snow_depth

  g.write(filename)
end

folder = "/tmp/charts"
execute "mkdir -p #{folder}" unless Dir.exist?(folder)

# Do daily graph
if argv[:d]
  date_str = Date.today.to_s
  url      = @location[:daily_url]
  meth     = method(:generate_daily_graph)
else # hourly
  date_str = DateTime.now.strftime("%F_%H")
  url      = @location[:url]
  meth     = method(:generate_graph)
end
filename = "#{folder}/#{@location_id}_snow_depth_#{date_str}.png"
if argv[:f] || !File.exists?(filename)
  encoded_url = URI.encode(url)
  data        = Faraday.get encoded_url
  csv_string  = data.body.gsub(/^#.*\n/,"")
  meth.call(csv_string, filename)
end

include Iterm::Imgcat
get_and_print_image(url: filename)
