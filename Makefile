default:
	docker run -p 4000:4000 --volume="$$PWD:/srv/jekyll" -it -e VERBOSE="" -e JEKYLL_DEBUG="" jekyll/jekyll:4.2.2 jekyll serve -V --watch --force_polling
