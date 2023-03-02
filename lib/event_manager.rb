require 'csv'
require 'google/apis/civicinfo_v2'
require 'time'
require 'date'
require 'erb'

puts 'event manager initialized!'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)
template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

contents.each do |row|
  id = row[0]

  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

def filter_phone_number(person)
  filtered_phone = person[:homephone].scan(/\d/).join('')
  if filtered_phone.length == 10 || filtered_phone.length == 11 && filtered_phone.start_with?('1')
    true
  else
    false
  end
end

registration_times = []

contents.each do |row|
  puts row[:first_name] if filter_phone_number(row)
  registration_times << Time.strptime(row[:regdate], '%m/%d/%y %k:%M')
end

hours_hash = Hash.new(0)
weekday_hash = Hash.new(0)
registration_times.each do |time|
  hours_hash[time.hour] += 1
  weekday_hash[time.wday] += 1
end

max_reg_in_hour = hours_hash.values.max
max_reg_in_weekday = weekday_hash.values.max
most_reg_weekday = (weekday_hash.select { |k, v| v == max_reg_in_weekday }).keys
most_reg_weekday_name = []
most_reg_weekday.each do |weekday|
  most_reg_weekday_name << Date::DAYNAMES[weekday]
end
puts "The main registration hours are: #{(hours_hash.select { |k, v| v == max_reg_in_hour }).keys}"

puts "The main registration weekdays are: #{most_reg_weekday_name}"
