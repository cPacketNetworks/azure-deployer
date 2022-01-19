.PHONY: build-bicep

build: build-bicep

build-bicep:
	bicep build main.bicep
	# inject deployer.py into cclear userdata 
	echo '#!/bin/bash' > userdata-cclear.bash
	echo 'mkdir -p /opt/cloud/' >> userdata-cclear.bash
	echo 'cat <<EOF_DEPLOYER >/opt/cloud/deployer.py' >> userdata-cclear.bash
	cat deployer.py >> userdata-cclear.bash
	echo '' >> userdata-cclear.bash
	echo 'EOF_DEPLOYER' >> userdata-cclear.bash
	echo 'chmod +x /opt/cloud/deployer.py' >> userdata-cclear.bash

tag-latest:
	# create a git lightweight tag for lastest release
	git tag --delete latest
	git push origin --delete latest
	git tag latest
	git push origin latest
	git --no-pager log --pretty=oneline --max-count=3