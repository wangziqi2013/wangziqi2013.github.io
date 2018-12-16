
JEKYLL=jekyll
 
all: site

site: 
	jekyll build

test:
	jekyll serve

synctime:
	./util/synctime

clean:
	rm -rf ./_site
