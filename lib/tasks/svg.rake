desc "Process SVG icons into Rails partials"
task svg: :environment do
  source_dir = Rails.root.join("app/assets/images/svg")
  output_dir = Rails.root.join("app/views/partials/svg")

  FileUtils.mkdir_p(output_dir)
  Dir.glob(output_dir.join("*.html.erb")).each { |f| File.delete(f) }

  svg_files = Dir.glob(source_dir.join("*.svg")).sort
  if svg_files.empty?
    puts "No SVG files found in #{source_dir}"
    next
  end

  svg_files.each do |svg_file|
    doc = Nokogiri::XML(File.read(svg_file))
    doc.remove_namespaces!
    svg = doc.at_css("svg")
    next unless svg

    # Remove style, fill, and stroke attributes from all elements
    doc.css("[style]").each { |el| el.remove_attribute("style") }
    doc.css("[fill]").each { |el| el.remove_attribute("fill") }
    doc.css("[stroke]").each { |el| el.remove_attribute("stroke") }

    # Remove unnecessary attributes from <svg>
    svg.remove_attribute("version")

    # Add ERB template variables using placeholders to avoid XML escaping
    svg["class"] = "ERB_OPEN%= class_name %ERB_CLOSE"
    svg["aria-hidden"] = "ERB_OPEN%= aria_hidden %ERB_CLOSE"

    # Serialize and minify
    output = svg.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)
    output.gsub!(/\n\s*/, "")
    output.strip!

    # Replace placeholders with actual ERB tags
    output.gsub!("ERB_OPEN", "<")
    output.gsub!("ERB_CLOSE", ">")

    # Write partial
    basename = File.basename(svg_file, ".svg")
    partial_name = "_#{basename.gsub("-", "_")}.html.erb"
    File.write(output_dir.join(partial_name), output)
    puts "  #{basename}.svg → #{partial_name}"
  end

  puts "Processed #{svg_files.size} SVG files"
end
