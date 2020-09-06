json.set! '@context', 'http://schema.org'
json.set! '@type', 'WebSite'
json.set! 'url', root_url
json.potentialAction do
  json.set! '@type', 'SearchAction'
  json.set! 'target', "#{search_url}?q={search_term_string}"
  json.set! 'query-input', 'required name=search_term_string'
end
