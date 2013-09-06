#
# TODO: Set REPO as an environment variable and port all of this to commonplace.
# P.S. Basta, don't be mad.
#

REPO = "rocketfuel"
UUID = "8af8c763-da9b-444d-a911-206f9e225b55"
VERSION = `date "+%Y.%m.%d_%H.%M.%S"`
VERSION_INT = $(shell date "+%Y%m%d%H%M%S")
TMP = _tmp
TEMPLATES = $(wildcard \
	src/templates/*.html \
	public/templates/**/*.html \
)
STYL_FILES = $(wildcard \
	src/media/css/*.styl \
	public/media/css/**/*.styl \
)
CSS_FILES = $(STYL_FILES:.styl=.styl.css)
COMPILED_TEMPLATES = src/templates.js

compile: $(COMPILED_TEMPLATES) $(CSS_FILES)

fastcompile:
	node damper.js --compile

$(COMPILED_TEMPLATES): $(TEMPLATES)
	node damper.js --compile nunjucks

%.styl.css: %.styl
	node damper.js --compile stylus --path $<

l10n: clean fastcompile
	./locale/omg_new_l10n.sh

langpacks:
	mkdir -p src/locales
	for po in `find locale -name "*.po"` ; do \
		lang=`basename \`dirname \\\`dirname $$po\\\`\` | tr "_" "-"`; \
		node scripts/generate_langpacks.js $$po $$lang; \
		mv $$po.js src/locales/$$lang.js ; \
	done

package: compile
	cd src/ && zip -r ../$(VERSION).zip * && cd ../

# This is what the iframe src points to.
DOMAIN?=marketplace.firefox.com

# This is what the app will be named on the device.
NAME?=Rocketfuel

log: clean
	@mkdir -p TMP && cp -pR yulelog/* TMP/.
	@# We have to have a temp file to work around a bug in Mac's version of sed :(
	@sed -i'.bak' -e 's/marketplace\.firefox\.com/$(DOMAIN)/g' TMP/main.js
	@sed -i'.bak' -e 's/{version}/$(VERSION_INT)/g' TMP/manifest.webapp
	@sed -i'.bak' -e 's/"Marketplace"/"$(NAME)"/g' TMP/manifest.webapp
	@rm -f TMP/*.bak
	@cd TMP && zip -q -r ../yulelog_$(NAME)_$(VERSION_INT).zip * && cd ../
	@rm -rf TMP
	@echo "Created file: yulelog_$(NAME)_$(VERSION_INT).zip"

clean:
	@rm -rf TMP \
		$(CSS_FILES) \
		$(COMPILED_TEMPLATES) \
		src/locales/* \
		src/media/css/include.css \
		src/media/js/include.*

pre_includes: clean compile langpacks
	@# This generates a BUILD_ID for zamboni so that we can cachebust
	@# the assets on the CDN.
	@rm -f src/media/build_$(REPO).py && \
		echo "#!/usr/bin/env python\n\nBUILD_ID = '"$(VERSION_INT)"'" > src/media/build_$(REPO).py
	@echo "Created file: src/media/build_$(REPO).py"


lint:
	# You need closure-linter installed for this.
	gjslint --nojsdoc -r src/media/js/ -e lib

deploy:
	git fetch && git reset --hard origin/master && npm install && make includes
