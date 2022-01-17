.PHONY: build-bicep

build: build-bicep

build-bicep:
	bicep build main.bicep

tag-latest:
	# create a git lightweight tag for lastest release
	git tag --delete latest
	git push origin --delete latest
	git tag latest
	git push origin latest
	git --no-pager log --pretty=oneline --max-count=3