require 'how_is'
require 'yaml'
require 'contracts'

C = Contracts

class HowIs::CLI
  include Contracts::Core

  DEFAULT_CONFIG_FILE = 'how_is.yml'

  # Generates YAML frontmatter, as is used in Jekyll and other blog engines.
  #
  # E.g.,
  #     generate_frontmatter({'foo' => "bar %{baz}"}, {'baz' => "asdf"})
  # =>  "---\nfoo: bar asdf\n"
  Contract C::HashOf[C::Or[String, Symbol] => String],
           C::HashOf[C::Or[String, Symbol] => String] => String
  def generate_frontmatter(frontmatter, report_data)
    frontmatter = convert_keys(frontmatter, :to_s)
    report_data = convert_keys(report_data, :to_sym)

    frontmatter = frontmatter.map { |k, v|
      v = v % report_data

      [k, v]
    }.to_h

    YAML.dump(frontmatter)
  end

  def from_config_file(config_file = nil, **kwargs)
    config_file ||= DEFAULT_CONFIG_FILE

    from_config(YAML.load_file(config_file), **kwargs)
  end

  def from_config(config,
        github: nil,
        report_class: nil)
    report_class ||= HowIs::Report

    date = Date.strptime(Time.now.to_i.to_s, '%s')
    date_string = date.strftime('%Y-%m-%d')
    friendly_date = date.strftime('%B %d, %y')

    analysis = HowIs.generate_analysis(repository: config['repository'], github: github)

    report_data = {
      repository: config['repository'],
      date: date,
      friendly_date: friendly_date,
    }

    config['reports'].each do |format, report_config|
      filename = report_config['filename'] % report_data
      file = File.join(report_config['directory'], filename)

      report = report_class.export(analysis, format)

      File.open(file, 'w') do |f|
        if report_config['frontmatter']
          f.puts generate_frontmatter(report_config['frontmatter'], report_data)
          f.puts "---"
          f.puts
        end

        f.puts report
      end
    end
  end

private
  # convert_keys({'foo' => 'bar'}, :to_sym)
  # => {:foo => 'bar'}
  def convert_keys(data, method_name)
    data.map {|k, v| [k.send(method_name), v]}.to_h
  end
end
