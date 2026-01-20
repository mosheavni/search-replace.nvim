.PHONY: all lint test prepare clean docs

all: test

docs:
	@mkdir -p doc
	@command -v pandoc >/dev/null || { echo "Install pandoc: brew install pandoc"; exit 1; }
	@command -v lemmy-help >/dev/null || { echo "Install lemmy-help: cargo install lemmy-help"; exit 1; }
	@test -d .panvimdoc || git clone --depth 1 https://github.com/kdheepak/panvimdoc .panvimdoc
	pandoc --metadata="project:search-replace" --metadata="demojify:true" --metadata="treesitter:true" \
		--metadata="incrementheadinglevelby:0" \
		--lua-filter .panvimdoc/scripts/skip-blocks.lua \
		--lua-filter .panvimdoc/scripts/include-files.lua \
		-t .panvimdoc/scripts/panvimdoc.lua \
		README.md -o doc/search-replace.txt
	lemmy-help --prefix-func --prefix-class --prefix-alias --prefix-type \
		lua/search-replace/init.lua \
		lua/search-replace/core.lua \
		lua/search-replace/utils.lua \
		lua/search-replace/float.lua \
		lua/search-replace/dashboard.lua \
		lua/search-replace/config.lua > doc/search-replace-api.txt
	@echo "" >> doc/search-replace.txt
	@echo "==============================================================================" >> doc/search-replace.txt
	@cat doc/search-replace-api.txt >> doc/search-replace.txt
	@rm doc/search-replace-api.txt
	nvim --headless -c "helptags doc" -c "qa"
	@echo "Generated doc/search-replace.txt"

lint:
	stylua --check lua/
	luacheck lua/ --globals vim

test: prepare
	nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests { minimal_init = './tests/minimal_init.vim' }"

prepare:
	@test -d ../plenary.nvim || git clone --depth 1 https://github.com/nvim-lua/plenary.nvim ../plenary.nvim
	@command -v stylua >/dev/null || { \
		curl -L -o stylua.zip https://github.com/JohnnyMorganz/StyLua/releases/latest/download/stylua-linux-x86_64.zip && \
		unzip stylua.zip && \
		rm -f stylua.zip && \
		chmod +x stylua && \
		sudo mv stylua /usr/local/bin/; \
	}

clean:
	rm -rf ../plenary.nvim
