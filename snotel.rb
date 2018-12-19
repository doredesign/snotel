Bundler.require(:default)
require "csv"

# g = Gruff::Line.new
# g.title = 'Wow!  Look at this!'
# g.labels = { 0 => '5/6', 1 => '5/15', 2 => '5/24', 3 => '5/30', 4 => '6/4',
#              5 => '6/12', 6 => '6/21', 7 => '6/28' }
# g.data :Jimmy, [25, 36, 86, 39, 25, 31, 79, 88]
# g.data :Charles, [80, 54, 67, 54, 68, 70, 90, 95]
# g.data :Julie, [22, 29, 35, 38, 36, 40, 46, 57]
# g.data :Jane, [95, 95, 95, 90, 85, 80, 88, 100]
# g.data :Philip, [90, 34, 23, 12, 78, 89, 98, 88]
# g.data :Arthur, [5, 10, 13, 11, 6, 16, 22, 32]
# folder = "/tmp/charts"
# filename = "#{folder}/exciting.png"

LOCATIONS = [
  {
    title: "June Lake snotel (3440 ft)",
    url: "https://wcc.sc.egov.usda.gov/reportGenerator/view_csv/customSingleStationReport/hourly/553:WA:SNTL|id=%22%22|name/-167,0/WTEQ::value,SNWD::value,PREC::value,TOBS::value",
  },
  {
    title: "Spirit Lake snotel (3520 ft)",
    url: "https://wcc.sc.egov.usda.gov/reportGenerator/view_csv/customSingleStationReport/hourly/777:WA:SNTL|id=%22%22|name/-167,0/WTEQ::value,SNWD::value,PREC::value,TOBS::value",
  },
  {
    title: "Swift Creek snotel (4440 ft)",
    url: "https://wcc.sc.egov.usda.gov/reportGenerator/view_csv/customSingleStationReport/hourly/1012:WA:SNTL|id=%22%22|name/-167,0/WTEQ::value,SNWD::value,PREC::value,TOBS::value",
  },
  {
    title: "Sheep Canyon snotel (3990 ft)",
    url: "https://wcc.sc.egov.usda.gov/reportGenerator/view_csv/customSingleStationReport/hourly/748:WA:SNTL|id=%22%22|name/-167,0/WTEQ::value,SNWD::value,PREC::value,TOBS::value",
  },
]

@location_id = ARGV[0] || 0
@location = LOCATIONS[@location_id.to_i]

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

date_str = DateTime.now.strftime("%F_%H")
folder = "/tmp/charts"
execute "mkdir -p #{folder}" unless Dir.exist?(folder)
filename = "#{folder}/#{@location_id}_snow_depth_#{date_str}.png"
unless File.exists?(filename)
  url         = @location[:url]
  encoded_url = URI.encode(url)
  data        = Faraday.get encoded_url
  csv_string  = data.body.gsub(/^#.*\n/,"")
  generate_graph(csv_string, filename)
end

include Iterm::Imgcat
get_and_print_image(url: filename)
