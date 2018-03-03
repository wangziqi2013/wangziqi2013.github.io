
JEKYLL=jekyll

all: site

site: 
	jekyll build

test:
	jekyll serve

clean:
	rm -rf ./_site
