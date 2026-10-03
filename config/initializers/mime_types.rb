# Be sure to restart your server when you modify this file.

# Add new mime types for use in respond_to blocks:
# Mime::Type.register "text/richtext", :rtf

Mime::Type.register 'text/plain', :txt

# A page of entries without the layout, for infinite scroll to append. HTML, so
# it needs none of the cross-origin JavaScript checks a .js response does, but
# with its own extension so its URL (and Cloudflare cache key) differs from the
# full page's.
Mime::Type.register_alias 'text/html', :fragment
