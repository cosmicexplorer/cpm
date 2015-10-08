.PHONY: all clean distclean

NODE_DIR := node_modules
NPM_BIN := $(NODE_DIR)/.bin
COFFEE_CC := $(NPM_BIN)/coffee

DEPS := $(COFFEE_CC)

SRC_DIR := src

in := $(wildcard $(SRC_DIR)/*.coffee)
out := $(patsubst %.coffee,%.js,$(in))

bin-base := $(SRC_DIR)/command.js
bin := cmd.js

all: $(bin) $(out)

%.js: %.coffee $(DEPS)
	$(COFFEE_CC) -bc --no-header $<

$(bin): $(bin-base) $(DEPS)
	echo '#!/usr/bin/env node' > $@
	cat $< >> $@
	chmod +x $@

clean:
	rm -f $(out)

distclean: clean
	rm -rf $(NODE_DIR)

$(DEPS):
	npm install
