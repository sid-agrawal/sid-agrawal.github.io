.PHONY: serve install

# Install dependencies (requires Ruby + Bundler)
install:
	gem install bundler jekyll
	bundle install

# Serve the site locally at http://localhost:4000
serve:
	bundle exec jekyll serve --livereload
