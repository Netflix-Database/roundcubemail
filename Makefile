#
# This file is used by developers to build release packages
#

GPGKEY=support@netdb.at
VERSION=1.7-git
SEDI=sed -i
PHP_VERSION=7.3

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    SEDI=sed -i ''
endif

all: clean complete dependent

complete: build
	cp -RH build roundcubemail-$(VERSION)
	(cd roundcubemail-$(VERSION); cp composer.json-dist composer.json)
	(cd roundcubemail-$(VERSION); php /tmp/composer.phar config platform.php $(PHP_VERSION))
	(cd roundcubemail-$(VERSION); php /tmp/composer.phar require "kolab/net_ldap3:~1.1.4" --no-update --no-install)
	(cd roundcubemail-$(VERSION); php /tmp/composer.phar config --unset suggest.kolab/net_ldap3)
	(cd roundcubemail-$(VERSION); php /tmp/composer.phar config --unset require-dev)
	(cd roundcubemail-$(VERSION); php /tmp/composer.phar update --prefer-dist --no-dev --no-interaction)
	(cd roundcubemail-$(VERSION); php /tmp/composer.phar config --unset platform)
	(cd roundcubemail-$(VERSION); bin/install-jsdeps.sh --force)
	(cd roundcubemail-$(VERSION); bin/jsshrink.sh program/js/publickey.js; bin/jsshrink.sh plugins/managesieve/codemirror/lib/codemirror.js)
	(cd roundcubemail-$(VERSION); rm -f jsdeps.json bin/install-jsdeps.sh *.orig; rm -rf temp/js_cache)
	(cd roundcubemail-$(VERSION); rm -rf vendor/pear/*/tests vendor/*/*/.git* vendor/*/*/.travis* vendor/*/*/phpunit.xml.dist vendor/pear/console_commandline/docs vendor/pear/net_ldap2/doc vendor/bacon/bacon-qr-code/test vendor/dasprid/enum/test)
	(cd roundcubemail-$(VERSION); echo "// generated by Roundcube install $(VERSION)" >> vendor/autoload.php)
	tar czf roundcubemail-$(VERSION)-complete.tar.gz roundcubemail-$(VERSION)
	rm -rf roundcubemail-$(VERSION)

dependent: build
	cp -RH build roundcubemail-$(VERSION)
	tar czf roundcubemail-$(VERSION).tar.gz roundcubemail-$(VERSION)
	rm -rf roundcubemail-$(VERSION)

sign:
	gpg -u $(GPGKEY) -a --detach-sig roundcubemail-$(VERSION).tar.gz
	gpg -u $(GPGKEY) -a --detach-sig roundcubemail-$(VERSION)-complete.tar.gz

verify:
	gpg -v --verify roundcubemail-$(VERSION).tar.gz.asc roundcubemail-$(VERSION).tar.gz
	gpg -v --verify roundcubemail-$(VERSION)-complete.tar.gz.asc roundcubemail-$(VERSION)-complete.tar.gz

shasum:
	shasum -a 256 roundcubemail-$(VERSION).tar.gz roundcubemail-$(VERSION)-complete.tar.gz

build: buildtools
	rsync -a ./ build --exclude build --exclude .github --exclude .git --exclude tests --exclude .gitignore --exclude .tx --exclude .editorconfig --exclude Makefile
	(cd build; rm -rf plugins/*/tests)
	(cd build; find . -type f -exec dos2unix {} \;)
	(cd build; bin/jsshrink.sh; bin/updatecss.sh; bin/cssshrink.sh)
	(cd build/skins/elastic; \
		lessc --clean-css="--s1 --advanced" styles/styles.less > styles/styles.min.css; \
		lessc --clean-css="--s1 --advanced" styles/print.less > styles/print.min.css; \
		lessc --clean-css="--s1 --advanced" styles/embed.less > styles/embed.min.css)
	(cd build; $(SEDI) 's/1.7-git/$(VERSION)/' index.php public_html/index.php installer/index.php program/include/iniset.php program/lib/Roundcube/bootstrap.php)
	(cd build; $(SEDI) 's/# Unreleased/# Release $(VERSION)'/ CHANGELOG.md)

buildtools: /tmp/composer.phar
	npm install -g uglify-js lessc less-plugin-clean-css csso-cli
	apt install -y dos2unix php8.1

/tmp/composer.phar:
	curl -sS https://getcomposer.org/installer | php -- --install-dir=/tmp/

/tmp/phpDocumentor.phar:
	curl -sSL https://phpdoc.org/phpDocumentor.phar -o /tmp/phpDocumentor.phar

clean:
	rm -rf build
	rm -rf roundcubemail-$(VERSION)*
